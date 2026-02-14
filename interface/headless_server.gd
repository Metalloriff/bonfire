class_name HeadlessServer extends Node

static var instance: HeadlessServer
static var is_headless_server: bool:
	get:
		return "--server" in OS.get_cmdline_args()

var defaults: Dictionary = {
	DO_NOT_CHANGE__AUTO_GENERATED = {
		server_id = Lib.create_uid(32)
	},
	network = {
		valid_addresses = ["127.0.0.1", "localhost"],
		port = 26969
	},
	profile = {
		name = "My Server"
	}
}
var config: Dictionary
var server: Server

@onready var server_data_path: String = OS.get_executable_path().get_base_dir().path_join("server_data")
@onready var config_path: String = OS.get_executable_path().get_base_dir().path_join("config.yml")

func _ready() -> void:
	instance = self

	var possible_config_paths: Array[String] = [
		OS.get_executable_path().get_base_dir().path_join("server.yml"),
		OS.get_executable_path().get_base_dir().path_join("server.yaml"),
		"user://server.yml",
		"user://server.yaml"
	]
	
	for path in possible_config_paths:
		if not FileAccess.file_exists(path):
			continue
		
		config = YAML.load_file(path)
		config_path = path
		break
	
	if not config:
		print("No config file found! Creating a new one...")
		save_config()
	
	server = Server.new()
	if FS.exists(server_data_path.path_join("server.res")):
		server = load(server_data_path.path_join("server.res"))
	
	server.name = get_config_entry("profile.name")

	for channel in server.channels:
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

		server.save_to_disk()

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(get_config_entry("network.port"))

	peer.peer_connected.connect(func(id):
		print("Peer connected with ID ", id)

		await get_tree().process_frame

		server.com_node._receive_server_info.rpc_id(id, var_to_bytes_with_objects(server))
		server.com_node._receive_voice_chat_participants.rpc_id(id, server.com_node.voice_chat_participants)
	)

	peer.peer_disconnected.connect(func(id):
		server.online_users.erase(id)
		server.com_node._update_online_users.rpc(server.online_users)
	)
	
	if err != OK:
		print("Failed to create server! Error %d" % err)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_packet.connect(_packet_received)

	server.com_node = ServerComNode.new(server.id)

func _packet_received(peer_id: int, packet: PackedByteArray) -> void:
	var message: Dictionary = bytes_to_var(packet)

	prints("whe4oathoweituioawseoitujawset", message)

	if not "endpoint" in message:
		return

	server._handle_api_message_server(message.endpoint, message, peer_id)

func _process(_delta: float) -> void:
	if not multiplayer.multiplayer_peer:
		return

func save_config() -> void:
	YAML.save_file(config, OS.get_executable_path().get_base_dir().path_join("server.yml"))

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

static func send_api_message(endpoint: String, data: Dictionary, peer_id: int = 0) -> void:
	if not is_instance_valid(instance):
		return
	if not is_headless_server:
		return
	
	data.endpoint = endpoint

	instance.multiplayer.send_bytes(var_to_bytes(data), peer_id)
