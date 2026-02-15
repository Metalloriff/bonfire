class_name ServerComNode extends Node

static var instances: Dictionary[String, ServerComNode] = {}

var error: bool = false
var id: String
var local_multiplayer: MultiplayerAPI
var server: Server
var connected_time: float

var address: String
var port: int
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
				prints("api request send from non-authority peer", peer_id)
				return

			if not "endpoint" in message:
				return
			
			server._handle_api_message_client(message.endpoint, message, peer_id)
		)

func _start() -> void:
	Settings.make_setting_link_method("profile", "avatar_picture", func(new_value: String) -> void:
		_send_avatar_to_server(new_value)
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

	for property in new_server_data.get_property_list():
		# TODO only sync exported properties
		if property.name in server and not property.name in ["online_users", "voice_chat_participants"]:
			server.set(property.name, new_server_data.get(property.name))
	
	server.address = address
	server.port = port

	server.cache()

	for channel in server.channels:
		channel.server = server

	instances[server.id] = self

	ServerList.instance.queue_redraw()

	prints(name, "Received server info!", local_multiplayer.get_unique_id())

	if not _has_authenticated:
		server.send_api_message("authenticate", {
			"username": FS.get_pref("auth.username"),
			"password_hash": FS.get_pref("auth.pw_hash")
		})

		_has_authenticated = true

		var avatar_path: String = Settings.get_value("profile", "avatar_picture")
		if avatar_path.strip_edges() and FileAccess.file_exists(avatar_path):
			await Lib.seconds(1.0)

			_send_avatar_to_server(avatar_path)

func _send_avatar_to_server(avatar_path: String) -> void:
	assert(avatar_path.strip_edges() and FileAccess.file_exists(avatar_path), "Avatar path is invalid!")

	var avatar_image: Image = Image.load_from_file(avatar_path)
	
	if avatar_image.get_size().x > 512 or avatar_image.get_size().y > 512:
		avatar_image.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	
	assert(avatar_image.get_data_size() <= 1024 * 1024, "Avatar image is too large!")
	
	for user: User in server.users:
		if user.id == server.user_id:
			if not user.avatar or not user.avatar is ImageTexture or user.avatar.get_image().get_data_size() != avatar_image.get_data_size():
				server.send_api_message("receive_user_profile_update", {
					user_id = user.id,
					avatar_data = avatar_image.save_png_to_buffer(),
					avatar_extension = avatar_path.get_extension()
				})
