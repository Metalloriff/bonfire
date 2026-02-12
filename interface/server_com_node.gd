class_name ServerComNode extends Node

var error: bool = false
var id: String
var local_multiplayer: MultiplayerAPI
var server: Server
var connected_time: float

var _address: String
var _port: int

func _init(address: String, port: int, is_server: bool = false) -> void:
	self._address = address
	self._port = port

	if not address:
		push_error("Server address cannot be empty!")
		error = true
		return
	
	id = address.sha256_text()
	name = id

	if not port:
		push_error("Server port cannot be 0!")
		error = true
		return
	
	var peer = ENetMultiplayerPeer.new()

	if not is_server:
		var err = peer.create_client(address, port)
		
		if err != OK:
			push_error("Failed to connect to %s:%d!" % [address, port])
			error = true
			return
	
	ServerCom.add_child(self )
	name = id

	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(), "/root/ServerCom/%s" % id)
	local_multiplayer = get_tree().get_multiplayer("/root/ServerCom/%s" % id)
	
	if is_server:
		local_multiplayer.multiplayer_peer = get_tree().root.multiplayer.multiplayer_peer
	else:
		local_multiplayer.multiplayer_peer = peer

func _process(delta: float) -> void:
	connected_time += delta

	if local_multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		print("Connection status: ", local_multiplayer.multiplayer_peer.get_connection_status())
		return

@rpc("authority", "call_remote")
func _receive_server_info(server_info: Dictionary) -> void:
	server = dict_to_inst(server_info)
	server.address = _address
	server.port = _port
	server.cache()

	ServerList.instance.queue_redraw()

	prints(name, "Received server info!", local_multiplayer.get_unique_id())

# @rpc("any_peer", "call_remote")
# func _request_server_info() -> void:
# 	print("Received request for server info!")
# 	local_multiplayer.rpc(local_multiplayer.get_remote_sender_id(), self , "_receive_server_info")
# 	# _receive_server_info.rpc_id(multiplayer.get_remote_sender_id())
