class_name HeadlessServer extends Node

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

@onready var config_path: String = OS.get_executable_path().get_base_dir().path_join("config.yml")

func _ready() -> void:
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
	
	if get_config_entry("DO_NOT_CHANGE__AUTO_GENERATED.server_id") == defaults["DO_NOT_CHANGE__AUTO_GENERATED"].server_id or not get_config_entry("DO_NOT_CHANGE__AUTO_GENERATED.server_id"):
		if not "DO_NOT_CHANGE__AUTO_GENERATED" in config:
			config.DO_NOT_CHANGE__AUTO_GENERATED = {}
		config.DO_NOT_CHANGE__AUTO_GENERATED.server_id = Lib.create_uid(32)
		save_config()
	
	server = Server.new()
	server.id = config.DO_NOT_CHANGE__AUTO_GENERATED.server_id
	server.name = get_config_entry("profile.name")

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(get_config_entry("network.port"))

	peer.peer_connected.connect(func(id):
		print("Peer connected with ID ", id)

		await get_tree().process_frame

		ServerCom.get_child(0)._receive_server_info.rpc_id(id, inst_to_dict(server))
	)

	peer.peer_disconnected.connect(func(id):
		print("Peer disconnected with ID ", id)
	)
	
	if err != OK:
		print("Failed to create server! Error %d" % err)
		return
	
	multiplayer.multiplayer_peer = peer

	# create valid address coms
	for address: String in get_config_entry("network.valid_addresses"):
		var server_node: ServerComNode = ServerComNode.new(address, get_config_entry("network.port"), true)

		server_node.local_multiplayer.multiplayer_peer = peer

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
	
	prints(default_object, object)
	
	return default_object if return_default else object
