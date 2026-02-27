class_name Server extends Resource

static var instances: Dictionary[String, Server] = {}

static func get_server(server_id: String) -> Server:
	return instances[server_id] if server_id in instances else load("user://servers/%s.res" % server_id)

func _init() -> void:
	if HeadlessServer.is_headless_server:
		return

@export var id: String = Lib.create_uid(32)
@export var name: String = "Invalid Server"
@export var channels: Array[Channel] = []
@export var private_channels: Array[Channel] = []:
	get:
		if HeadlessServer.is_headless_server:
			return private_channels
		
		return private_channels.filter(func(channel: Channel) -> bool:
			for participant in channel.pm_participants:
				if participant.user_id == user_id:
					return true
			
			return false
		)
@export var users: Array[User] = []
@export var roles: Array[Role] = []
@export var icon: ImageTexture
@export var max_file_upload_size: int = Lib.readable_to_bytes("1GB")
@export var rules: Array = []

@export_storage var address: String
@export_storage var port: int
@export_storage var password: String
@export_storage var accepted_rules_hash: String

var left: bool
var online_users: Dictionary[int, String] = {}
var voice_chat_participants: Dictionary = {}

var user_id: String:
	get:
		var auth: Dictionary = AuthPortal.get_auth(id)
		return ("%s:%s" % [auth.username, auth.password_hash]).sha256_text()
var local_user: User:
	get:
		return get_user(user_id)
var local_stored_user_path: String:
	get:
		FS.mkdir("user://local_user_profiles")
		return "user://local_user_profiles/%s.res" % local_user.profile_id
var local_stored_user: User:
	get:
		if not is_instance_valid(local_stored_user) and ResourceLoader.exists(local_stored_user_path):
			local_stored_user = load(local_stored_user_path)
		return local_stored_user

var com_node: ServerComNode:
	get:
		if not is_instance_valid(com_node):
			com_node = ServerComNode.instances.get(id, null)
		return com_node

func cache() -> void:
	print("Caching server %s" % id)

	FS.mkdir("user://servers")
	ResourceSaver.save(self , "user://servers/%s.res" % id)

func save_to_disk(sync_to_clients: bool = true) -> void:
	if not HeadlessServer.is_headless_server:
		return
	
	FS.mkdir(HeadlessServer.instance.server_data_path)
	var server_resource_path: String = "%s/server.res" % HeadlessServer.instance.server_data_path
	if ResourceLoader.exists(server_resource_path):
		DirAccess.rename_absolute(server_resource_path, server_resource_path.replace(".res", ".res.bak"))

	ResourceSaver.save(self , server_resource_path)
	
	if is_instance_valid(com_node) and sync_to_clients:
		com_node._receive_server_info.rpc(var_to_bytes_with_objects(self ))

func get_channel(cid: String) -> Channel:
	for channel in channels:
		if channel.id == cid:
			return channel
	for channel in private_channels:
		if channel.id == cid:
			return channel
	return null

func get_user(uid: String) -> User:
	for user in users:
		if user.id == uid:
			return user
	return null

func get_user_by_peer_id(peer_id: int) -> User:
	if not peer_id in online_users:
		return null
	return get_user(online_users[peer_id])

func get_peer_id_by_user_id(user_id: String) -> int:
	for peer_id in online_users:
		if online_users[peer_id] == user_id:
			return peer_id
	return -1

func get_role(role_id: String) -> Role:
	for role in roles:
		if role.id == role_id:
			return role
	return null

func send_api_message(endpoint: String, data: Dictionary) -> void:
	if not is_instance_valid(com_node):
		print("Attempted to send API message to server %s but it is not connected!" % id)
		return

	data.endpoint = endpoint
	com_node.local_multiplayer.send_bytes(var_to_bytes(data), 1)

func _handle_api_message_server(endpoint: String, data: Dictionary, peer_id: int) -> void:
	if not HeadlessServer.is_headless_server:
		return
	
	if not peer_id in online_users and not endpoint in ["authenticate", "handshake", "attempt_password"]:
		return
	
	match endpoint:
		"handshake":
			HeadlessServer.instance.multiplayer.send_bytes(var_to_bytes(id), peer_id)
		"authenticate":
			if not "username" in data or not "password_hash" in data:
				return
			if not data.username or not data.password_hash:
				return
			if HeadlessServer.instance.get_config_entry("network.password").strip_edges():
				if not peer_id in HeadlessServer.instance._password_attempts or HeadlessServer.instance._password_attempts[peer_id].sha256_text() != HeadlessServer.instance.get_config_entry("network.password").sha256_text():
					return
			
			var user_id: String = (data.username + ":" + data.password_hash).sha256_text()
			
			prints("user", peer_id, "authenticated as", user_id)
			online_users[peer_id] = user_id

			# TODO check for changes before saving to disk
			var existing_user: User = get_user(user_id)
			if is_instance_valid(existing_user):
				var user_updated: bool

				if user_updated:
					save_to_disk()
			else:
				var user: User = User.new()
				user.id = user_id
				user.name = data.username
				users.append(user)
				save_to_disk()

				existing_user = user
			
			HeadlessServer.instance._sync_online_users()

			if user_id == HeadlessServer.instance.get_config_entry("profile.owner"):
				if not "owner" in existing_user.roles:
					existing_user.roles.append("owner")

					HeadlessServer.send_api_message("update_user_roles", {
						user_id = user_id,
						roles = existing_user.roles
					})

					await Lib.seconds(1.0)
					save_to_disk(false)
			elif "owner" in existing_user.roles:
				existing_user.roles.erase("owner")

				HeadlessServer.send_api_message("update_user_roles", {
					user_id = user_id,
					roles = existing_user.roles
				})

				await Lib.seconds(1.0)
				save_to_disk(false)
		"send_message":
			if not "channel_id" in data or not "content" in data:
				return
			if len(data.content) > 4000:
				return
			
			if not len(data.content) and not len(data.attachments):
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			if not channel.server:
				channel.server = self
			
			var user: User = get_user_by_peer_id(peer_id)
			if not is_instance_valid(user):
				prints("user", peer_id, "tried to send message to channel", data.channel_id, "but is not online")
				return
			
			if "attachments" in data and len(data.attachments):
				for attachment_id in data.attachments:
					if not attachment_id or not attachment_id is String:
						prints("invalid attachment id", attachment_id)
						return
			
			if channel.is_private:
				var user_id: String = online_users[peer_id]
				var user_allowed: bool = false
				
				for participant in channel.pm_participants:
					if participant.user_id == user_id:
						user_allowed = true
						break
				
				if not user_allowed:
					prints("User", peer_id, "tried to send message to private channel", data.channel_id, "but is not allowed to.")
					return

			var message: Message = Message.new(user.id, data.content, data.attachments if "attachments" in data else [])
			channel.last_message_timestamp = message.timestamp

			if "encrypted" in data and data.encrypted:
				message.encrypted = true
			
			channel._commit_message(message)
		"fetch_messages":
			if not "channel_id" in data or not "limit" in data or not "offset" in data:
				return
			
			if data.limit > 100:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			if channel.is_private:
				var user_id: String = online_users[peer_id]
				var user_allowed: bool = false
				
				for participant in channel.pm_participants:
					if participant.user_id == user_id:
						user_allowed = true
						break
				
				if not user_allowed:
					HeadlessServer.send_api_message("fetch_messages_response", {
						channel_id = data.channel_id,
						messages = []
					}, peer_id)

					prints("User", peer_id, "tried to fetch messages from private channel", data.channel_id, "but is not allowed to.")
					return

			var messages: Array[Dictionary] = channel._load_messages_from_db(data.limit, data.offset)

			HeadlessServer.send_api_message("fetch_messages_response", {
				channel_id = data.channel_id,
				messages = messages
			}, peer_id)
		"receive_user_profile_update":
			assert(peer_id in online_users, "User profile update received from an offline user")

			var user_id: String = online_users[peer_id]
			var user: User = get_user(user_id)

			if not is_instance_valid(user):
				user = User.new()

			if "avatar_data" in data and data.avatar_data:
				if len(data.avatar_data) > Lib.readable_to_bytes("1MB"):
					prints("user", peer_id, "tried to send avatar data that is too large")
					return
				else:
					var image: Image = Image.new()
					image.load_png_from_buffer(data.avatar_data)
					user.avatar = ImageTexture.create_from_image(image)
			if "display_name" in data:
				user.display_name = data.display_name.substr(0, 32)
			if "tagline" in data:
				user.tagline = data.tagline.substr(0, 100)
			if "bio" in data:
				user.bio = data.bio.substr(0, 2000)
			
			var existing_user_index: int = users.find_custom(func(u: User) -> bool: return u.id == user.id)
			if existing_user_index != -1:
				users[existing_user_index] = user
			else:
				users.append(user)

			HeadlessServer.send_api_message("receive_user_profile", {
				user_id = user_id,
				display_name = user.display_name,
				tagline = user.tagline,
				bio = user.bio,
				avatar_data = data.avatar_data if "avatar_data" in data else "",
			})

			save_to_disk(false)
		"delete_message":
			if not "channel_id" in data or not "message_id" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			channel._db.query("SELECT * FROM messages WHERE timestamp = '%d'" % data.message_id)
			if not channel._db.query_result:
				return
			
			var message_data: Dictionary = channel._db.query_result[0]
			
			if not peer_id in online_users or message_data.author != online_users[peer_id] and not get_user(online_users[peer_id]).has_permission(self , Permissions.MESSAGE_DELETE):
				print("Message delete (ID %d) was attempted by a user (%s) who is not the author (%s) or does not have permission" % [data.message_id, online_users[peer_id] if peer_id in online_users else str(peer_id), message_data.author])
				return
			
			if "attachments" in message_data and message_data.attachments:
				var attachments: Array = JSON.parse_string(message_data.attachments)
				for attachment_id in attachments:
					if FileAccess.file_exists(channel._get_media_path(attachment_id)):
						DirAccess.remove_absolute(channel._get_media_path(attachment_id))
					channel._db.delete_rows("media", "media_id = '%s'" % attachment_id)
			
			channel._db.delete_rows("messages", "timestamp = '%d'" % data.message_id)

			await Lib.seconds(0.1)

			HeadlessServer.send_api_message("message_deleted", {
				channel_id = data.channel_id,
				message_id = data.message_id
			})
		"edit_message":
			if not "channel_id" in data or not "message_id" in data or not "content" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			channel._db.query("SELECT * FROM messages WHERE timestamp = '%d'" % data.message_id)
			if not channel._db.query_result:
				return
			
			if not peer_id in online_users or channel._db.query_result[0].author != online_users[peer_id]:
				print("Message edit (ID %d) was attempted by a user (%s) who is not the author (%s)" % [data.message_id, online_users[peer_id] if peer_id in online_users else str(peer_id), channel._db.query_result[0].author])
				return
			
			channel._db.update_rows("messages", "timestamp = '%d'" % data.message_id, {
				content = data.content
			})

			HeadlessServer.send_api_message("message_updated", {
				channel_id = data.channel_id,
				message_id = data.message_id,
				new_content = data.content
			})
		"create_private_channel_with_user":
			if not "user_id" in data:
				return
			
			var user_a: User = get_user_by_peer_id(peer_id)
			var user_b: User = get_user(data.user_id)

			if not is_instance_valid(user_a) or not is_instance_valid(user_b):
				return
			
			if not user_a.is_online_in_server(self ) or not user_b.is_online_in_server(self ):
				return
			
			var ids: Array[String] = [user_a.id, user_b.id]
			ids.sort()
			var pm_id: String = "".join(ids).sha256_text()
			if is_instance_valid(get_channel(pm_id)):
				return
			
			var channel: Channel = Channel.new()
			var names: Array[String] = [user_a.name, user_b.name]
			names.sort()
			channel.id = pm_id
			channel.name = "%s, %s" % names
			channel.type = Channel.Type.TEXT
			channel.is_private = true
			
			channel.pm_participants = [
				{
					user_id = user_a.id,
					private_key_encrypted = ""
				},
				{
					user_id = user_b.id,
					private_key_encrypted = ""
				}
			]

			private_channels.append(channel)
			channel._initialize_messages_database()

			var private_key: String = EncryptionTools.generate_token()
			for pid in [peer_id, get_peer_id_by_user_id(user_b.id)]:
				HeadlessServer.send_api_message("encrypt_private_channel_key", {
					channel_id = pm_id,
					private_key = private_key
				}, pid)
		"encrypt_private_channel_key_response":
			if not "channel_id" in data or not "private_key" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			var puser_id: String = online_users[peer_id]
			for participant in channel.pm_participants:
				if participant.user_id == puser_id:
					participant.private_key_encrypted = data.private_key
					break
			
			save_to_disk(false)
			com_node._receive_server_info.rpc_id(peer_id, var_to_bytes_with_objects(self ))
		"fetch_media_meta":
			prints("SERVER: received media meta request", data)
			if not "media_id" in data or not "channel_id" in data:
				print("Invalid media meta request")
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				print("Invalid channel for media meta request")
				return
			
			var meta: Dictionary = channel._load_media_meta_from_db(data.media_id)
			if not meta:
				print("fetch_media_meta: Media item not found")
				return
			
			HeadlessServer.send_api_message("fetch_media_meta_response", {
				channel_id = data.channel_id,
				media_id = data.media_id,
				meta = meta
			}, peer_id)
		"attempt_password":
			if not "password" in data:
				return
			if not data.password:
				return
			
			var password: String = data.password
			HeadlessServer.instance._password_attempts[peer_id] = password
		"leave_server":
			if "purge_all_messages" in data and data.purge_all_messages:
				HeadlessServer.instance.purge_messages_from_user(online_users[peer_id])
			
			com_node._peer.disconnect_peer(peer_id, true)
			users.erase(get_user_by_peer_id(peer_id))
			save_to_disk()
		"purge_channel_messages":
			if not "channel_id" in data:
				return
			
			var user_id: String = online_users[peer_id]
			var user: User = get_user(user_id)
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel) or not is_instance_valid(user):
				return
			
			var user_allowed: bool = false

			if channel.is_private:
				for participant in channel.pm_participants:
					if participant.user_id == user_id:
						user_allowed = true
						break
			else:
				user_allowed = user.has_permission(self , Permissions.MESSAGE_PURGE)
			
			if not user_allowed:
				prints("User", peer_id, "tried to purge private channel", data.channel_id, "but is not allowed to.")
				return
			
			channel.purge_messages()
		"delete_channel":
			if not "channel_id" in data:
				return
			
			var user_id: String = online_users[peer_id]
			var user: User = get_user(user_id)
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel) or not is_instance_valid(user):
				return

			var user_allowed: bool = false
			if channel.is_private:
				for participant in channel.pm_participants:
					if participant.user_id == user_id:
						user_allowed = true
						break
			else:
				user_allowed = user.has_permission(self , Permissions.CHANNEL_MANAGE)
			
			if not user_allowed:
				prints("User", peer_id, "tried to delete private channel", data.channel_id, "but is not allowed to.")
				return
			
			channel.delete_channel()
		"edit_channel":
			if not "channel_id" in data or not "name" in data:
				return
			
			if len(data.name) > 32:
				return
			
			var user_id: String = online_users[peer_id]
			var user: User = get_user(user_id)
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel) or not is_instance_valid(user):
				return
			
			if not user.has_permission(self , Permissions.CHANNEL_MANAGE):
				prints("User", peer_id, "tried to edit channel", data.channel_id, "but is not allowed to.")
				return
			
			channel.name = data.name

			if "icon" in data and ResourceLoader.exists("res://icons/%s" % data.icon):
				channel.icon_name = data.icon

			save_to_disk()
		"fetch_message_count_since":
			if not "channel_ids" in data or not "timestamp" in data or not len(data.channel_ids):
				return
			
			var response: Dictionary = {}

			for channel_id in data.channel_ids:
				var channel: Channel = get_channel(channel_id)
				if not is_instance_valid(channel):
					continue
				
				response[channel_id] = await channel.get_message_count_since(data.timestamp)
			
			if not response:
				return
			
			HeadlessServer.send_api_message("fetch_message_count_since_response", {
				channel_ids = data.channel_ids,
				counts = response
			}, peer_id)
		"create_channel":
			if not "name" in data or not "channel_type" in data:
				return
			
			if not data.channel_type in Channel.CHANNEL_TYPE_TITLES:
				return
			
			if len(data.name) > 32:
				return
			
			var user_id: String = online_users[peer_id]
			var user: User = get_user(user_id)
			if not is_instance_valid(user):
				return
			
			if not user.has_permission(self , Permissions.CHANNEL_MANAGE):
				prints("User", peer_id, "tried to create channel but is not allowed to.")
				return
			
			var channel: Channel = Channel.new()
			channel.name = data.name
			channel.type = data.channel_type
			channel.server = self
			channel._initialize_messages_database()
			channels.append(channel)

			if "icon" in data and ResourceLoader.exists("res://icons/%s" % data.icon):
				channel.icon_name = data.icon

			save_to_disk()
		"reorder_channel":
			if not "index_a" in data or not "channel_a" in data or not "index_b" in data or not "channel_b" in data:
				return
			
			var user_id: String = online_users[peer_id]
			var user: User = get_user(user_id)
			if not is_instance_valid(user):
				return
			
			if not user.has_permission(self , Permissions.CHANNEL_MANAGE):
				prints("User", peer_id, "tried to reorder channel", data.channel_a, "but is not allowed to.")
				return
			
			var channel_a: Channel = get_channel(data.channel_a)
			var channel_b: Channel = get_channel(data.channel_b)
			if not is_instance_valid(channel_a) or not is_instance_valid(channel_b):
				return
			
			channels[data.index_a] = channel_a
			channels[data.index_b] = channel_b
			save_to_disk()
		"kick_user":
			if not "user_id" in data:
				return
			
			var requesting_user_id: String = online_users[peer_id]
			var requesting_user: User = get_user(requesting_user_id)
			if not is_instance_valid(requesting_user):
				return
			
			if not requesting_user.has_permission(self , Permissions.MEMBER_KICK):
				prints("User", peer_id, "tried to kick user", data.user_id, "but is not allowed to.")
				return
			
			var user: User = get_user(data.user_id)
			if not is_instance_valid(user):
				return
			
			if user.id == requesting_user_id:
				prints("User", peer_id, "tried to kick themselves. That's rude.")
				return
			
			var pid: int = get_peer_id_by_user_id(data.user_id)
			if pid > 0:
				com_node.local_multiplayer.multiplayer_peer.disconnect_peer(pid, true)
			
			if "purge_all_messages" in data and data.purge_all_messages:
				if requesting_user.has_permission(self , Permissions.MESSAGE_PURGE):
					HeadlessServer.instance.purge_messages_from_user(data.user_id)
				else:
					prints("User", peer_id, "tried to purge messages from user", data.user_id, "but is not allowed to.")
			
			await Lib.seconds(0.1)

			users.erase(user)
			save_to_disk()
		"edit_server":
			var user_id: String = online_users[peer_id]
			var user: User = get_user(user_id)
			if not is_instance_valid(user):
				return
			
			if not user.has_permission(self , Permissions.SERVER_PROFILE_MANAGE):
				prints("User", peer_id, "tried to edit server but is not allowed to.")
				return
			
			if "name" in data:
				name = data.name.substr(0, 32)
				HeadlessServer.instance.config.profile.name = name
			
			if "icon" in data and len(data.icon) < Lib.readable_to_bytes("1MB"):
				var image: Image = Image.new()
				image.load_png_from_buffer(data.icon)
				icon = ImageTexture.create_from_image(image)

				image.save_png("%s/icon.png" % HeadlessServer.instance.server_data_path)
			
			HeadlessServer.instance.save_config()
			save_to_disk()

func _handle_api_message_client(endpoint: String, data: Dictionary, peer_id: int) -> void:
	if HeadlessServer.is_headless_server:
		return
	
	prints("client request received", endpoint, data, id, name, peer_id)

	match endpoint:
		"update_online_users":
			prints("received new online users", data.online_users, "for server", id, name)
			online_users = data.online_users
			
			MemberList.instance.queue_redraw()
		"update_voice_chat_participants":
			VoiceChat._pending_updates = false
			for channel_id in data.participants:
				for pid in data.participants[channel_id]:
					if not channel_id in voice_chat_participants or not pid in voice_chat_participants[channel_id]:
						VoiceChat.user_joined.emit(channel_id, pid)
			
			for channel_id in voice_chat_participants:
				for pid in voice_chat_participants[channel_id]:
					if not channel_id in data.participants or not pid in data.participants[channel_id]:
						VoiceChat.user_left.emit(channel_id, pid)

			voice_chat_participants = data.participants
			ChannelList.instance.queue_redraw()
		"fetch_messages_response":
			if not "channel_id" in data or not "messages" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not channel.messages_loading:
				return
			
			if channel.is_private and not channel.private_key:
				for participant in channel.pm_participants:
					if participant.user_id == user_id:
						channel.private_key = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(participant.private_key_encrypted), AuthPortal.private_key)
			
			channel.messages_loading = false
			channel.messages_loaded = true
			channel.messages.clear()
			
			for message in data.messages:
				if channel.is_private and channel.private_key and not message.encrypted:
					message.content = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(message.content), channel.private_key)
				channel.messages.append(Message.new().deserialize(message))
			
			ChatFrame.instance.queue_redraw()
		"new_message":
			if not "channel_id" in data or not "message" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			var message: Message = Message.new().deserialize(data.message)
			
			if channel.is_private:
				PrivateChannelList.instance.queue_redraw()
				
				if channel.private_key and not message.encrypted:
					message.content = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(message.content), channel.private_key)
				if not channel.private_key:
					channel.last_message_timestamp = message.timestamp
					return

			channel.messages.append(message)
			channel.message_received.emit(message)
			channel.last_message_timestamp = message.timestamp

			if ChatFrame.instance.selected_channel and ChatFrame.instance.selected_channel.id == data.channel_id or is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel.id == data.channel_id or channel.is_private:
				ChatFrame.instance.queue_redraw()

				if channel.is_private:
					Notifications.play_sound("ping_important")
				else:
					Notifications.play_sound("ping")
		"receive_user_profile":
			var user: User = get_user(data.user_id)
			if not is_instance_valid(user):
				print("User profile update received from an invalid user")
				return
			
			user.display_name = data.display_name.substr(0, 32)
			user.tagline = data.tagline.substr(0, 100)
			user.bio = data.bio.substr(0, 2000)

			if data.avatar_data:
				var image: Image = Image.new()
				image.load_png_from_buffer(data.avatar_data)
				user.avatar = ImageTexture.create_from_image(image)
			
			if App.selected_server == self:
				ChatFrame.instance.queue_redraw()
				MemberList.instance.queue_redraw()
			
			if data.user_id == user_id:
				if is_instance_valid(UserProfileModal.instance):
					ModalStack.fade_free_modal(UserProfileModal.instance)
				LocalUserContainer.instance.queue_redraw()
		"message_deleted": # I know one of you mfers are going to mod this.
			if not "channel_id" in data or not "message_id" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			var message: Message = channel.find_message(data.message_id)
			if not is_instance_valid(message):
				return
			
			channel.messages.erase(message)
			
			for message_item in ChatFrame.instance.get_tree().get_nodes_in_group("message_item"):
				if message_item.message == message:
					var message_group: MessageGroupNode = message_item.get_parent().owner
					message_group.messages.erase(message)

					if len(message_group.messages) == 0:
						message_group.delete()
					else:
						message_item.delete()
		"message_updated":
			if not "channel_id" in data or not "message_id" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			var message: Message = channel.find_message(data.message_id)
			if not is_instance_valid(message):
				return
			
			message.content = data.new_content
			
			for message_item in ChatFrame.instance.get_tree().get_nodes_in_group("message_item"):
				if not is_instance_valid(message_item):
					continue
				
				if message_item.message == message:
					message_item.text_content = message.content
					message_item.queue_redraw()
		"encrypt_private_channel_key":
			assert(len(AuthPortal.private_key) > 0, "No private key set for encryption")

			if not "private_key" in data or not "channel_id" in data:
				return
			
			var encrypted_key: String = Marshalls.raw_to_base64(EncryptionTools.encrypt_string(data.private_key, AuthPortal.private_key))
			send_api_message("encrypt_private_channel_key_response", {
				channel_id = data.channel_id,
				private_key = encrypted_key
			})
		"fetch_media_meta_response":
			if not "media_id" in data or not "channel_id" in data or not "meta" in data:
				print("Invalid media meta response")
				return
			
			var media: Media = Media.new()
			media.deserialize(data.meta)
			media.id = data.media_id
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			channel._media_meta_cache[data.media_id] = media
		"purge_channel_messages":
			if not "channel_id" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			if not is_instance_valid(channel):
				return
			
			channel.messages.clear()

			if ChatFrame.instance.selected_channel == channel:
				ChatFrame.instance.last_channel = null
				ChatFrame.instance.queue_redraw()
		"fetch_message_count_since_response":
			if not "channel_ids" in data or not "counts" in data:
				return
			
			for channel_id in data.channel_ids:
				var channel: Channel = get_channel(channel_id)
				if not is_instance_valid(channel):
					continue
				
				channel._message_count_since_response = data.counts[channel_id]
		"update_user_roles":
			if not "user_id" in data or not "roles" in data:
				return
			
			var user: User = get_user(data.user_id)
			if not is_instance_valid(user):
				return
			
			user.roles = data.roles

			MemberList.instance.queue_redraw()
			ChatFrame.instance.queue_redraw()

func leave_server(purge_all_messages: bool = false) -> void:
	if purge_all_messages:
		assert(is_instance_valid(com_node), "Not connected to a server!")
	assert(not HeadlessServer.is_headless_server, "Cannot leave server from headless server!")

	left = true

	if is_instance_valid(com_node):
		send_api_message("leave_server", {
			purge_all_messages = purge_all_messages
		})

	await Lib.seconds(0.5)

	if is_instance_valid(com_node):
		if com_node.local_multiplayer.multiplayer_peer and com_node.local_multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			com_node.local_multiplayer.multiplayer_peer.close()
			com_node.local_multiplayer.multiplayer_peer = null
		
		com_node.queue_free()
		ServerComNode.instances.erase(id)

	var private_profiles: Dictionary = FS.get_pref("auth.private_profiles", {})
	if id in private_profiles:
		private_profiles.erase(id)
		FS.set_pref("auth.private_profiles", private_profiles)
	if id in AuthPortal.private_profiles:
		AuthPortal.private_profiles.erase(id)

	var cache_path: String = "user://servers/%s.res" % id
	if ResourceLoader.exists(cache_path):
		DirAccess.remove_absolute(cache_path)
	
	App.selected_server = null
	
	await Lib.frame

	ServerList.instance.queue_redraw()
	ChatFrame.instance.queue_redraw()
