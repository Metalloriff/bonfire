class_name HeadlessServer extends Node

static var instance: HeadlessServer
static var is_headless_server: bool:
	get:
		return "--server" in OS.get_cmdline_args()

var defaults: Dictionary = {
	system = {
		auto_update = true,
		update_channel = "stable"
	},
	network = {
		upnp_enabled = true,
		port = 26969,
		password = ""
	},
	profile = {
		name = "My Server",
		owner = "",
		rules = []
	},
	restrictions = {
		max_file_upload_size = "1GB"
	}
}
var config: Dictionary
var server: Server
var file_server: FileServer

var server_data_path: String = "user://server_data"
var config_path: String = "%s/config.yml" % server_data_path

var _password_attempts: Dictionary = {}

func _ready() -> void:
	instance = self
	
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--server-data-path="):
			server_data_path = "user://" + arg.split("=", false)[1]
			config_path = "%s/config.yml" % server_data_path
			break
	
	FS.mkdir(server_data_path)

	if not FileAccess.file_exists(config_path):
		print("No config file found! Creating a new one...")
		config = defaults
		save_config()
	
	config = YAML.load_file(config_path)
	
	server = Server.new()
	if FS.exists(server_data_path.path_join("server.res")):
		server = load(server_data_path.path_join("server.res"))
	
	server.name = get_config_entry("profile.name")
	server.max_file_upload_size = Lib.readable_to_bytes(get_config_entry("restrictions.max_file_upload_size"))
	server.rules = get_config_entry("profile.rules")
	
	if FS.exists(server_data_path.path_join("icon.png")) and FileAccess.get_size(server_data_path.path_join("icon.png")) < 1024 * 1024:
		var image: Image = Image.load_from_file(server_data_path.path_join("icon.png"))
		server.icon = ImageTexture.create_from_image(image)

	for channel in server.channels + server.private_channels:
		if not is_instance_valid(channel):
			server.channels.erase(channel)

	if not len(server.channels):
		var general_text_channel: Channel = Channel.new()
		general_text_channel.name = "General"
		general_text_channel.type = Channel.Type.TEXT
		general_text_channel.server = server
		server.channels.append(general_text_channel)

		var general_voice_channel: Channel = Channel.new()
		general_voice_channel.name = "Voice Chat"
		general_voice_channel.type = Channel.Type.VOICE
		general_voice_channel.server = server
		server.channels.append(general_voice_channel)

		server.save_to_disk(false)
	
	for channel in server.channels + server.private_channels:
		channel.server = server
		channel._initialize_messages_database()
		
		for message in channel._load_messages_from_db(1, 0):
			channel.last_message_timestamp = message.timestamp
	
	if not server.get_role("owner"):
		var owner_role: Role = Role.new()
		owner_role.id = "owner"
		owner_role.name = "Server Owner"
		owner_role.permissions.add_permission("*")
		server.roles.append(owner_role)

		server.save_to_disk(false)

	if get_config_entry("network.upnp_enabled"):
		print("Attempting to open uPnP port mapping...")

		var upnp_thread := Thread.new()
		upnp_thread.start(_do_upnp_mapping)
		var timeout: float = 0.0

		while upnp_thread.is_alive():
			timeout += await Lib.frame_with_delta()

			if timeout > 5.0:
				print("uPnP port mapping timed out! Shutting down server...")
				get_tree().quit()
				return
		
		var output: String = upnp_thread.wait_to_finish()
		if "Error" in output:
			print("uPnP port mapping failed! Shutting down server...")
			print("Consider disabling uPnP in server.yml and manually forwarding ports.")
			get_tree().quit()
			return
		else:
			print("uPnP port mapping successful. Server will now listen on %s" % output)

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(get_config_entry("network.port"))

	if err != OK:
		print("Failed to create server! Error %d" % error_string(err))
		return
	
	file_server = FileServer.new()
	file_server.server = server
	add_child(file_server)
	file_server.host(get_config_entry("network.port"))

	peer.peer_connected.connect(func(id):
		prints("Peer connected with ID", id)

		await Lib.frame

		if get_config_entry("network.password").strip_edges():
			var password: String = get_config_entry("network.password")
			send_api_message("request_password", {
				server_name = server.name,
				hash = password.sha256_text()
			}, id)

			var timeout: float = 0.0
			while not id in _password_attempts or _password_attempts[id] != password:
				timeout += await Lib.frame_with_delta()

				if timeout > 120.0:
					print("Password request timed out!")
					peer.disconnect_peer(id, true)
					return

		server.com_node._receive_server_info.rpc_id(id, var_to_bytes_with_objects(server))
		send_api_message("update_voice_chat_participants", {
			participants = server.voice_chat_participants
		}, id)
	)

	peer.peer_disconnected.connect(func(id):
		prints("Peer disconnected with ID", id)

		server.online_users.erase(id)
		_sync_online_users()

		for channel_id in server.voice_chat_participants:
			if id in server.voice_chat_participants[channel_id]:
				server.voice_chat_participants[channel_id].erase(id)
			if len(server.voice_chat_participants[channel_id]) == 0:
				server.voice_chat_participants.erase(channel_id)
		
		send_api_message("update_voice_chat_participants", {
			participants = server.voice_chat_participants
		})
	)
	
	if err != OK:
		print("Failed to create server! Error %d" % err)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_packet.connect(_packet_received)

	server.com_node = ServerComNode.new(server.id)

func _do_upnp_mapping() -> Variant:
	var err := func(msg: String) -> String:
		print(
			"There was an error opening uPnP ports. Users may not be able to connect to your server unless you manually port forward.\n",
			"This can happen if you have an outdated router, or you are under a multi-router setup.\n",
			"Error: ", msg
		)
		
		return msg
	
	var upnp := UPNP.new()
	if upnp.discover() != OK: return err.call("UPNP.discover() called failed!")
	var port: int = get_config_entry("network.port")
	
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		if upnp.add_port_mapping(port, port, ProjectSettings.get("application/config/name"), "UDP") != OK: return err.call("Could not map UDP port!")
		if upnp.add_port_mapping(port, port, ProjectSettings.get("application/config/name") + " Info server", "TCP") != OK: return err.call("Could not map TCP port!")
		
		return upnp.query_external_address()
	else:
		return err.call("No gateway or invalid gateway!")

var _invalid_packets_received: Dictionary = {}
func _packet_received(peer_id: int, packet: PackedByteArray) -> void:
	if not peer_id in server.online_users:
		if peer_id in _invalid_packets_received and _invalid_packets_received[peer_id] > 5:
			print("Peer %d sent a packet but is not a valid user" % peer_id)
			return
		_invalid_packets_received[peer_id] = 1 if not peer_id in _invalid_packets_received else _invalid_packets_received[peer_id] + 1

	var message: Dictionary = bytes_to_var(packet)

	if not "endpoint" in message:
		return

	server._handle_api_message_server(message.endpoint, message, peer_id)

func _process(_delta: float) -> void:
	if not multiplayer.multiplayer_peer:
		print("MDUD: Multiplayer peer is null")
		return
	
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		prints("MDUD: Multiplayer peer is not connected. Status:", multiplayer.multiplayer_peer.get_connection_status())

func save_config() -> void:
	YAML.save_file(config, config_path)

func get_config_entry(key: String) -> Variant:
	var split := key.split(".", false)

	if len(split) == 1:
		return config.get(key, defaults[key])
	
	var object = config
	var default_object = defaults
	var return_default: bool = false

	for part in split:
		if object.has(part):
			object = object[part]
		else:
			return_default = true

		if not default_object.has(part):
			return null
		
		default_object = default_object[part]
	
	return default_object if return_default else object

func _sync_online_users() -> void:
	send_api_message("update_online_users", {
		online_users = server.online_users
	})

func purge_messages_from_user(user_id: String) -> void:
	assert(HeadlessServer.is_headless_server, "Cannot purge messages from user as a client")

	for channel in server.channels + server.private_channels:
		if not is_instance_valid(channel):
			continue
		
		channel._db.delete_rows("messages", "author = '%s'" % user_id)
		channel._db.query("SELECT * FROM media WHERE uploader_id = '%s'" % user_id)
		for media_result in channel._db.query_result:
			var media_path: String = channel._get_media_path(media_result.media_id)
			if FileAccess.file_exists(media_path):
				DirAccess.remove_absolute(media_path)
		channel._db.delete_rows("media", "uploader_id = '%s'" % user_id)

static func send_api_message(endpoint: String, data: Dictionary, peer_id: int = 0) -> void:
	if not is_instance_valid(instance):
		return
	if not is_headless_server:
		return
	
	data.endpoint = endpoint

	instance.multiplayer.send_bytes(var_to_bytes(data), peer_id)
