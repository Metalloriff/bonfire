class_name ServerComNode extends Node

static var instances: Dictionary[String, ServerComNode] = {}

var error: bool = false
var id: String
var local_multiplayer: MultiplayerAPI
var server: Server
var connected_time: float

var _address: String
var _port: int
var _has_authenticated: bool

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
		
		peer.peer_disconnected.connect(func(id):
			server.online_users.erase(id)
		)
	
	ServerCom.add_child(self )
	name = id

	local_multiplayer = MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(local_multiplayer, "/root/ServerCom/%s" % id)
	
	if is_server:
		local_multiplayer.multiplayer_peer = get_tree().root.multiplayer.multiplayer_peer
	else:
		local_multiplayer.multiplayer_peer = peer

func _process(delta: float) -> void:
	connected_time += delta

	if local_multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		if connected_time > 30.0:
			prints(name, "Connection to server timed out!")
			error = true
			connected_time = 0.0
			return
		return

@rpc("authority", "call_remote")
func _receive_server_info(server_info: PackedByteArray) -> void:
	var new_server_data: Server = bytes_to_var_with_objects(server_info)

	if not is_instance_valid(server):
		server = new_server_data
		Server.instances[server.id] = server
	
	server.address = _address
	server.port = _port

	for property in new_server_data.get_property_list():
		if property.name in server:
			server.set(property.name, new_server_data.get(property.name))

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

var voice_chat_participants: Dictionary = {}
func _sync_voice_chat_participants() -> void:
	prints("syncing voice chat participants")

	for peer_id in HeadlessServer.instance.multiplayer.get_peers():
		HeadlessServer.instance.multiplayer.rpc(peer_id, self , "_receive_voice_chat_participants", [voice_chat_participants])

@rpc("authority", "call_remote")
func _receive_voice_chat_participants(participants: Dictionary) -> void:
	prints("received new voice chat participants", participants)

	for channel_id in participants:
		for peer_id in participants[channel_id]:
			if not channel_id in voice_chat_participants or not peer_id in voice_chat_participants[channel_id]:
				VoiceChat.user_joined.emit(channel_id, peer_id)
	
	for channel_id in voice_chat_participants:
		for peer_id in voice_chat_participants[channel_id]:
			if not channel_id in participants or not peer_id in participants[channel_id]:
				VoiceChat.user_left.emit(channel_id, peer_id)

	voice_chat_participants = participants
	ChannelList.instance.queue_redraw()

@rpc("authority", "call_remote")
func _update_online_users(users: Dictionary) -> void:
	while not is_instance_valid(server):
		await Lib.seconds(0.1)
		prints("server is null")
	prints("received new online users", users)
	server.online_users.clear()

	for peer_id in users:
		server.online_users[peer_id] = users[peer_id]