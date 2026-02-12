extends Control

const SERVER_URL: String = "127.0.0.1"
const SERVER_PORT: int = 26969

var mic_capture: AudioEffectOpusChunked

var users: Dictionary = {}
var user_bus_indices: Dictionary = {}

@onready var mic_mix_rate: int = AudioServer.get_input_mix_rate()
var local_multiplayer: MultiplayerAPI

func _ready():
	var test := Node.new()
	get_tree().root.add_child(test)
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(), "/root/Main")
	local_multiplayer = get_tree().get_multiplayer("/root/Main")

	local_multiplayer.peer_connected.connect(_peer_connected)
	local_multiplayer.peer_disconnected.connect(_peer_disconnected)
	local_multiplayer.connected_to_server.connect(_connected_to_server)
	local_multiplayer.connection_failed.connect(_connection_failed)
	local_multiplayer.server_disconnected.connect(_server_disconnected)

	if "--server" in OS.get_cmdline_args():
		_on_host_button_pressed()
		return
	
	assert($AudioStreamPlayer.bus == "Microphone")
	var mic_bus = AudioServer.get_bus_index("Microphone")
	mic_capture = AudioServer.get_bus_effect(mic_bus, 0)
	
	# var peer = ENetMultiplayerPeer.new()
	# var err = peer.create_server(SERVER_PORT)
	# if err == ERR_ALREADY_IN_USE or err == ERR_CANT_CREATE:
	# 	peer.close()
	# 	err = peer.create_client(SERVER_URL, SERVER_PORT)
	# 	print("Created client ", ("Error %d" % err if err else ""))
	# 	%StatusText.text = "Connected to %s:%d" % [SERVER_URL, SERVER_PORT]
	# else:
		# print("Created server ", ("Error %d" % err if err else ""))
		# %StatusText.text = "Listening on %s:%d" % [SERVER_URL, SERVER_PORT]
		# set_process(false)
		# AudioServer.set_bus_effect_enabled(mic_bus, 0, false)
	# local_multiplayer.multiplayer_peer = peer

func _create_user(id: int) -> Node:
	var user = AudioStreamPlayer.new()
	user.stream = AudioStreamOpusChunked.new()
	user.autoplay = true
	user.name = "User " + str(id)
	return user

func _peer_connected(id):
	if id == 1:
		return
	
	print("Peer connected with ID ", id)
	users[id] = _create_user(id)
	add_child(users[id])

	var new_bus_index: int = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(new_bus_index, str(id))
	users[id].bus = str(id)
	user_bus_indices[id] = new_bus_index

	var user_label := Label.new()
	user_label.text = str(id)
	user_label.name = str(id)
	$UserList.add_child(user_label)
	
func _peer_disconnected(id):
	print("Peer disconnected with ID ", id)
	users[id].queue_free()
	users.erase(id)

	AudioServer.remove_bus(user_bus_indices[id])
	user_bus_indices.erase(id)
	
func _connected_to_server():
	print("Connected to server ", SERVER_URL, ":", SERVER_PORT)
	
func _connection_failed():
	print("Failed to connect to server ", SERVER_URL, ":", SERVER_PORT)
	
func _server_disconnected():
	print("Server disconnected.")
	
@rpc("any_peer", "call_remote", "unreliable")
func _upstream_packets(packet, pitch: float) -> void:
	if not local_multiplayer.is_server():
		return
	
	var sender_id := local_multiplayer.get_remote_sender_id()
	for user_id in users:
		if user_id == sender_id:
			continue
		local_multiplayer.rpc(user_id, self , "_downstream_packets", [sender_id, packet, pitch])

@rpc("authority", "call_remote", "unreliable")
func _downstream_packets(user_id: int, packet, pitch: float) -> void:
	users[user_id].pitch_scale = pitch
	users[user_id].stream.push_opus_packet(packet, 0, 0)

func _process(_delta):
	if "--server" in OS.get_cmdline_args():
		local_multiplayer.poll()

		return

	for node in $UserList.get_children():
		if int(node.name) in users:
			var left: float = AudioServer.get_bus_peak_volume_left_db(user_bus_indices[int(node.name)], 0)
			var right: float = AudioServer.get_bus_peak_volume_right_db(user_bus_indices[int(node.name)], 0)
			var volume: float = db_to_linear(max(left, right))
			node.text = "%s (%s)" % [node.name, volume]
		else:
			node.queue_free()


	while mic_capture.chunk_available():
		var packet = mic_capture.read_opus_packet(PackedByteArray())
		mic_capture.drop_chunk()
		if local_multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			local_multiplayer.rpc(0, self , "_upstream_packets", [packet, (mic_mix_rate / 44100.0) * %PitchSlider.value])

func _on_host_button_pressed() -> void:
	var mic_bus = AudioServer.get_bus_index("Microphone")
	mic_capture = AudioServer.get_bus_effect(mic_bus, 0)

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(SERVER_PORT)
	print("Created server ", ("Error %d" % err if err else ""))
	%StatusText.text = "Listening on %s:%d" % [SERVER_URL, SERVER_PORT]
	# set_process(false)
	AudioServer.set_bus_effect_enabled(mic_bus, 0, false)
	local_multiplayer.multiplayer_peer = peer

func _on_connect_button_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(%AddressField.text, SERVER_PORT)
	print("Created client ", ("Error %d" % err if err else ""))
	if err != OK:
		%StatusText.text = "Failed to connect to %s:%d, reason: %s" % [%AddressField.text, SERVER_PORT, err]
	%StatusText.text = "Connected to %s:%d" % [%AddressField.text, SERVER_PORT]
	local_multiplayer.multiplayer_peer = peer
