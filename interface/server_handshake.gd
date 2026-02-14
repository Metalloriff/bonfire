class_name ServerHandshake extends Node

static var instance: ServerHandshake

func _ready() -> void:
	instance = self

	if HeadlessServer.is_headless_server:
		while not is_instance_valid(HeadlessServer.instance):
			await Lib.seconds(0.1)
		get_tree().set_multiplayer(HeadlessServer.instance.multiplayer, "/root/ServerCom/ServerHandshake")
	else:
		get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(), "/root/ServerCom/ServerHandshake")

func handshake(ip_address: String, port: int) -> String:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip_address, port)

	if err != OK:
		print("Failed to connect to %s:%d!" % [ip_address, port])
		return ""
	
	multiplayer.multiplayer_peer = peer
	
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		await Lib.frame
	
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		print("Failed to connect to %s:%d!" % [ip_address, port])
		return ""

	multiplayer.send_bytes(var_to_bytes({endpoint = "handshake"}), 1)
	var handshake_response: Array = await multiplayer.peer_packet
	var server_id: String = bytes_to_var(handshake_response[1])

	peer.close()

	var server_cache_item: Server = Server.new()
	server_cache_item.id = server_id
	server_cache_item.address = ip_address
	server_cache_item.port = port
	FS.mkdir("user://servers")
	ResourceSaver.save(server_cache_item, "user://servers/%s.res" % server_id)

	return server_id
