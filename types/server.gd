class_name Server extends Resource

static var instances: Dictionary[String, Server] = {}

static func get_server(server_id: String) -> Server:
	return instances[server_id] if server_id in instances else load("user://servers/%s.res" % server_id)

@export var id: String = Lib.create_uid(32)
@export var name: String = "Invalid Server"
@export var channels: Array[Channel] = []
@export var users: Array[User] = []
@export var icon: ImageTexture
@export var max_file_upload_size: int = Lib.readable_to_bytes("1GB")

@export var address: String
@export var port: int

var online_users: Dictionary[int, String] = {}
var voice_chat_participants: Dictionary = {}

var user_id: String:
	get:
		return (FS.get_pref("auth.username") + ":" + FS.get_pref("auth.pw_hash")).sha256_text()

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
	ResourceSaver.save(self , "%s/server.res" % HeadlessServer.instance.server_data_path)
	
	if is_instance_valid(com_node) and sync_to_clients:
		com_node._receive_server_info.rpc(var_to_bytes_with_objects(self ))

func get_channel(cid: String) -> Channel:
	for channel in channels:
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

func send_api_message(endpoint: String, data: Dictionary) -> void:
	if not is_instance_valid(com_node):
		print("Attempted to send API message to server %s but it is not connected!" % id)
		return

	data.endpoint = endpoint
	com_node.local_multiplayer.send_bytes(var_to_bytes(data))

func _handle_api_message_server(endpoint: String, data: Dictionary, peer_id: int) -> void:
	if not HeadlessServer.is_headless_server:
		return
	
	match endpoint:
		"handshake":
			HeadlessServer.instance.multiplayer.send_bytes(var_to_bytes(id), peer_id)
		"authenticate":
			if not "username" in data or not "password_hash" in data:
				return
			if not data.username or not data.password_hash:
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
			
			HeadlessServer.instance._sync_online_users()
		"send_message":
			if not "channel_id" in data or not "content" in data:
				return
			if len(data.content) > 4000:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			var user: User = get_user_by_peer_id(peer_id)
			if not is_instance_valid(user):
				prints("user", peer_id, "tried to send message to channel", data.channel_id, "but is not online")
				return
			var message: Message = Message.new(user.id, data.content)

			if "encrypted" in data and data.encrypted:
				message.encrypted = true
			
			channel._commit_message(message)
		"fetch_messages":
			if not "channel_id" in data or not "limit" in data or not "offset" in data:
				return
			
			if data.limit > 100:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			var messages: Array[Dictionary] = channel._load_messages_from_db(data.limit, data.offset)

			HeadlessServer.send_api_message("fetch_messages_response", {
				channel_id = data.channel_id,
				messages = messages
			})
		"receive_user_profile_update":
			assert("user_id" in data, "No user_id provided for user profile update")

			var user: User = get_user(data.user_id)

			if "avatar_data" in data and "avatar_extension" in data:
				var image: Image = Image.new()
				image.load_png_from_buffer(data.avatar_data)
				user.avatar = ImageTexture.create_from_image(image)

			if "profile" in data:
				for key in data.profile:
					if key in user:
						user[key] = data.profile[key]
			
			var existing_user_index: int = users.find_custom(func(u: User) -> bool: return u.id == user.id)
			if existing_user_index != -1:
				users[existing_user_index] = user
			else:
				users.append(user)

			HeadlessServer.send_api_message("receive_user_profile", {
				user_id = data.user_id,
				bytes = var_to_bytes_with_objects(user)
			})

			save_to_disk(false)
			

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
			
			channel.messages_loading = false
			channel.messages_loaded = true
			
			for message in data.messages:
				channel.messages.append(Message.new().deserialize(message))
			
			ChatFrame.instance.queue_redraw()
		"new_message":
			if not "channel_id" in data or not "message" in data:
				return
			
			var channel: Channel = get_channel(data.channel_id)
			var message: Message = Message.new().deserialize(data.message)

			channel.messages.append(message)
			channel.message_received.emit(message)

			if ChatFrame.instance.selected_channel.id == data.channel_id or is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel.id == data.channel_id:
				ChatFrame.instance.queue_redraw()

				Notifications.play_sound("ping")
		"receive_user_profile":
			prints("received user profile update with size", data.bytes.size())

			var user: User = bytes_to_var_with_objects(data.bytes)
			var existing_user: User = get_user(data.user_id)

			if is_instance_valid(existing_user):
				for property in user.get_property_list():
					if property.name in existing_user:
						prints("new prop", property.name, user.get(property.name))
						existing_user.set(property.name, user.get(property.name))
				return
			
			users.append(user)
