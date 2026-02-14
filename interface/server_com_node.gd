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

func _init(server_id: String) -> void:
	id = server_id
	name = id
	
	var peer := ENetMultiplayerPeer.new()

	if not HeadlessServer.is_headless_server:
		var cached_server: Server = Server.get_server(server_id)
		address = cached_server.address
		port = cached_server.port

		assert(!!address, "Server address cannot be empty!")
		assert(port != 0, "Server port cannot be 0!")

		var err := peer.create_client(address, port)
		
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
	
	if HeadlessServer.is_headless_server:
		local_multiplayer.multiplayer_peer = get_tree().root.multiplayer.multiplayer_peer
	else:
		local_multiplayer.multiplayer_peer = peer

		local_multiplayer.peer_packet.connect(func(peer_id: int, packet: PackedByteArray) -> void:
			var message: Dictionary = bytes_to_var(packet)

			if peer_id != 1:
				prints("api request send from non-authority peer", peer_id)
				return

			if not "endpoint" in message:
				return
			
			server._handle_api_message_client(message.endpoint, message, peer_id)
		)

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
	
	server.address = address
	server.port = port

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
	prints("received new voice chat participants", server.name, participants)

	for channel_id in participants:
		for peer_id in participants[channel_id]:
			if not channel_id in voice_chat_participants or not peer_id in voice_chat_participants[channel_id]:
				VoiceChat.user_joined.emit(channel_id, peer_id)
	
	for channel_id in voice_chat_participants:
		for peer_id in voice_chat_participants[channel_id]:
			if not channel_id in participants or not peer_id in participants[channel_id]:
				VoiceChat.user_left.emit(channel_id, peer_id)

	voice_chat_participants.clear()
	ChannelList.instance.queue_redraw()

@rpc("authority", "call_remote")
func _update_online_users(users: Dictionary) -> void:
	while not is_instance_valid(server):
		await Lib.seconds(0.1)
	
	prints("received new online users", users, "for server", server.id, server.name)
	server.online_users.clear()

	for peer_id in users:
		server.online_users[peer_id] = users[peer_id]