class_name Server extends Resource

static var instances: Dictionary[String, Server] = {}

static func get_server(server_id: String) -> Server:
	return instances[server_id] if server_id in instances else load("user://servers/%s.res" % server_id)

@export var id: String = Lib.create_uid(32)
@export var name: String = "Invalid Server"
@export var channels: Array[Channel] = []
@export var users: Array[User] = []

@export var address: String
@export var port: int

var online_users: Dictionary[int, String] = {}

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

func save_to_disk() -> void:
	if not HeadlessServer.is_headless_server:
		return
	
	FS.mkdir(HeadlessServer.instance.server_data_path)
	ResourceSaver.save(self , "%s/server.res" % HeadlessServer.instance.server_data_path)
	
	if is_instance_valid(com_node):
		com_node._receive_server_info.rpc(var_to_bytes_with_objects(self ))

func get_channel(id: String) -> Channel:
	for channel in channels:
		if channel.id == id:
			return channel
	return null

func get_user(id: String) -> User:
	for user in users:
		if user.id == id:
			return user
	return null

func get_user_by_peer_id(peer_id: int) -> User:
	if not peer_id in online_users:
		return null
	return get_user(online_users[peer_id])

func send_api_message(endpoint: String, data: Dictionary) -> void:
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
				if existing_user.name != data.username:
					existing_user.name = data.username
					user_updated = true

				if user_updated:
					save_to_disk()
			else:
				var user: User = User.new()
				user.id = user_id
				user.name = data.username
				users.append(user)
				save_to_disk()
			
			HeadlessServer.instance._sync_online_users()

func _handle_api_message_client(endpoint: String, data: Dictionary, peer_id: int) -> void:
	if HeadlessServer.is_headless_server:
		return
	
	prints("client request received", endpoint, data, id, name, peer_id)

	match endpoint:
		"update_online_users":
			prints("received new online users", data.online_users, "for server", id, name)
			online_users = data.online_users
			
			MemberList.instance.queue_redraw()
