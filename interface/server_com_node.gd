class_name ServerComNode extends Node

static var instances: Dictionary[String, ServerComNode] = {}

var error: bool = false
var id: String
var local_multiplayer: MultiplayerAPI
var server: Server
var connected_time: float

var address: String
var port: int
var file_server: FileServer:
	get:
		if not is_instance_valid(file_server):
			file_server = FileServer.new()
			file_server.server = server
			file_server.ip_address = address
			file_server.port = port
			add_child(file_server)

		return file_server

var _has_authenticated: bool
var _connection_timeout: float
var _connection_tries: int
var _connection_try_delay: float = 5.0
var _peer: ENetMultiplayerPeer

func _init(server_id: String) -> void:
	id = server_id
	name = id
	
	_peer = ENetMultiplayerPeer.new()

	if not HeadlessServer.is_headless_server:
		var cached_server: Server = Server.get_server(server_id)
		address = cached_server.address
		port = cached_server.port

		assert(!!address, "Server address cannot be empty!")
		assert(port != 0, "Server port cannot be 0!")

		var err := _peer.create_client(address, port)
		
		if err != OK:
			push_error("Failed to connect to %s:%d!" % [address, port])
			error = true
			return
		
		_peer.peer_disconnected.connect(func(id):
			server.online_users.erase(id)
		)
	
	ServerCom.add_child(self )
	name = id

	local_multiplayer = MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(local_multiplayer, "/root/ServerCom/%s" % id)
	
	if HeadlessServer.is_headless_server:
		local_multiplayer.multiplayer_peer = get_tree().root.multiplayer.multiplayer_peer
	else:
		local_multiplayer.multiplayer_peer = _peer

		local_multiplayer.peer_packet.connect(func(peer_id: int, packet: PackedByteArray) -> void:
			var message: Dictionary = bytes_to_var(packet)

			if peer_id != 1:
				prints("api request send from non-authority peer", peer_id, local_multiplayer.get_unique_id())
				return

			if not "endpoint" in message:
				return
			
			if message.endpoint == "request_password":
				if not "hash" in message:
					return
				
				var cache_path: String = "user://servers/%s.res" % server_id
				if ResourceLoader.exists(cache_path):
					var cached_server: Server = load(cache_path)
					var password: String = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(cached_server.password), AuthPortal.private_key)

					if password and password.sha256_text() == message.hash:
						local_multiplayer.send_bytes(var_to_bytes({
							endpoint = "attempt_password",
							password = password
						}))
						
						return
				
				var modal = ModalStack.open_modal("res://interface/modals/server_password_modal.tscn")
				modal.hash = message.hash
				modal.server_name = message.server_name
				
				modal.callback = func(password: String) -> void:
					local_multiplayer.send_bytes(var_to_bytes({
						endpoint = "attempt_password",
						password = password
					}))

					while not is_instance_valid(server):
						await Lib.seconds(2.0)
					
					server.password = Marshalls.raw_to_base64(EncryptionTools.encrypt_string(password, AuthPortal.private_key))
					server.cache()

				return
			
			if not is_instance_valid(server):
				prints("server is not valid, but got message from server", message)
				return
			
			server._handle_api_message_client(message.endpoint, message, peer_id)
		)

func _process(delta: float) -> void:
	connected_time += delta

	if local_multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_connection_timeout += delta

		if _connection_timeout > _connection_try_delay:
			_peer.create_client(address, port)
			_connection_timeout = 0.0
			_connection_tries += 1

			if _connection_tries > 24:
				_connection_try_delay = 30.0
	else:
		_connection_timeout = 0.0
		_connection_tries = 0
		_connection_try_delay = 5.0

@rpc("authority", "call_remote")
func _receive_server_info(server_info: PackedByteArray) -> void:
	var new_server_data: Server = bytes_to_var_with_objects(server_info)

	if not is_instance_valid(server):
		server = new_server_data
		Server.instances[server.id] = server
	
	if server.left:
		return

	for property in new_server_data.get_property_list():
		# TODO only sync exported properties
		if property.name in server and not property.name in ["online_users", "voice_chat_participants"]:
			server.set(property.name, new_server_data.get(property.name))
	
	server.address = address
	server.port = port

	var cached_server: Server = load("user://servers/%s.res" % server.id) if ResourceLoader.exists("user://servers/%s.res" % server.id) else null
	if is_instance_valid(cached_server):
		server.password = cached_server.password
		server.accepted_rules_hash = cached_server.accepted_rules_hash

	server.cache()

	for channel in server.channels + server.private_channels:
		channel.server = server

	instances[server.id] = self

	ServerList.instance.queue_redraw()
	ChannelList.instance.queue_redraw()
	PrivateChannelList.instance.queue_redraw()
	ChatFrame.instance.queue_redraw()
	MemberList.instance.queue_redraw()

	prints(name, "Received server info!", local_multiplayer.get_unique_id())

	if not local_multiplayer.get_unique_id() in server.online_users:
		server.send_api_message("authenticate", AuthPortal.get_auth(server.id))

	if not _has_authenticated:
		if server.rules and server.accepted_rules_hash != JSON.stringify(server.rules).sha256_text():
			if not server.id in ServerRulesModal.prompted_servers:
				var modal = ModalStack.open_modal("res://interface/modals/server_rules_modal.tscn")
				modal.server = server
				ServerRulesModal.prompted_servers.append(server.id)

		_has_authenticated = true
		
		await Lib.seconds(1.0)

		var local_user: User = server.local_stored_user
		if is_instance_valid(server.local_user) and is_instance_valid(local_user) and server.local_user.id == local_user.id:
			for property in ["avatar", "display_name", "tagline", "bio"]:
				if server.local_user[property] != local_user[property]:
					_send_user_profile_update(local_user)
					break

func _send_user_profile_update(new_user: User) -> void:
	var avatar_data: PackedByteArray = []

	if new_user.avatar is ImageTexture:
		avatar_data = new_user.avatar.get_image().save_png_to_buffer()
	
	server.send_api_message("receive_user_profile_update", {
		avatar_data = avatar_data,
		display_name = new_user.display_name,
		tagline = new_user.tagline,
		bio = new_user.bio
	})
