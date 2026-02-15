extends Node

var active_channel: Channel
var muted: bool:
	set(new):
		if muted != new:
			muted = new

			Notifications.play_sound("mute" if muted else "unmute")
var local_activity_level: float

signal user_joined(channel_id: String, user_id: int)
signal user_left(channel_id: String, user_id: int)

var mic_bus: int = AudioServer.get_bus_index("Microphone")
var mic_capture: AudioEffectOpusChunked
var users: Dictionary = {}
var user_bus_indices: Dictionary = {}

@onready var mic_mix_rate: int = AudioServer.get_input_mix_rate()

func _ready() -> void:
	if HeadlessServer.is_headless_server:
		while not is_instance_valid(HeadlessServer.instance):
			await Lib.seconds(0.1)
		
		get_tree().set_multiplayer(HeadlessServer.instance.multiplayer, "/root/VoiceChat")
		return

	Settings.make_setting_link_method("voice", "stereo_microphone_enabled", func(new_value: bool) -> void:
		AudioServer.set_bus_effect_enabled(mic_bus, 0, not new_value)
	)

	mic_capture = AudioServer.get_bus_effect(mic_bus, AudioServer.get_bus_effect_count(mic_bus) - 1)

	user_joined.connect(func(channel_id: String, user_id: int) -> void:
		prints("user joined", channel_id, user_id, "is server", HeadlessServer.is_headless_server)

		if active_channel and active_channel.id == channel_id:
			ChatFrame.instance.queue_redraw()

		if user_id == multiplayer.get_unique_id():
			return

		if active_channel and active_channel.id == channel_id:
			_create_peer(user_id)
		
		await Lib.frame

		ChannelList.instance.queue_redraw()
		ChatFrame.instance.queue_redraw()
	)

	user_left.connect(func(channel_id: String, user_id: int) -> void:
		if user_id == multiplayer.get_unique_id():
			set_deferred("active_channel", null)
			users.clear()
			user_bus_indices.clear()
			get_tree().set_multiplayer(null, "/root/VoiceChat")
		else:
			if active_channel and active_channel.id == channel_id:
				_remove_peer(user_id)
		
		await Lib.frame

		ChannelList.instance.queue_redraw()
		ChatFrame.instance.queue_redraw()
	)

func connect_to_channel(channel: Channel) -> void:
	if channel.type != Channel.Type.VOICE:
		return
	
	if active_channel == channel or channel.id in channel.server.voice_chat_participants and multiplayer.get_unique_id() in channel.server.voice_chat_participants[channel.id]:
		return
	
	if is_instance_valid(active_channel):
		disconnect_from_channel()
		await Lib.frame
	
	active_channel = channel

	get_tree().set_multiplayer(channel.server.com_node.local_multiplayer, "/root/VoiceChat")
	_user_join_request.rpc_id(1, channel.id)

	while not channel.id in channel.server.voice_chat_participants or not multiplayer.get_unique_id() in channel.server.voice_chat_participants[channel.id]:
		await Lib.frame
	
	for user_id in channel.server.voice_chat_participants[channel.id]:
		if user_id == multiplayer.get_unique_id():
			continue
		
		_create_peer(user_id)

func disconnect_from_channel() -> void:
	_user_leave_request.rpc_id(1, active_channel.id)

@rpc("any_peer")
func _user_leave_request(channel_id: String) -> void:
	if not HeadlessServer.is_headless_server or not multiplayer.is_server():
		return

	var server: Server = HeadlessServer.instance.server
	var peer_id: int = multiplayer.get_remote_sender_id()
	var channel: Channel = server.get_channel(channel_id)

	if not is_instance_valid(channel):
		push_error("User (%s) attempted to leave invalid channel with ID '%s'" % [peer_id, channel_id])
		return
	
	if not channel.id in server.voice_chat_participants:
		server.voice_chat_participants[channel.id] = []
	if peer_id in server.voice_chat_participants[channel.id]:
		server.voice_chat_participants[channel.id].erase(peer_id)
	HeadlessServer.send_api_message("update_voice_chat_participants", {
		participants = server.voice_chat_participants
	})

@rpc("any_peer")
func _user_join_request(channel_id: String) -> void:
	if not HeadlessServer.is_headless_server or not multiplayer.is_server():
		return
	
	prints("user is attempting to join channel", channel_id, multiplayer.get_remote_sender_id())

	var server: Server = HeadlessServer.instance.server
	var peer_id: int = multiplayer.get_remote_sender_id()
	var channel: Channel = server.get_channel(channel_id)

	if not is_instance_valid(channel):
		push_error("User (%s) attempted to join invalid channel with ID '%s'" % [peer_id, channel_id])
		return
	
	if not channel.id in server.voice_chat_participants:
		server.voice_chat_participants[channel.id] = []
	if peer_id in server.voice_chat_participants[channel.id]:
		return

	server.voice_chat_participants[channel.id].append(peer_id)
	HeadlessServer.send_api_message("update_voice_chat_participants", {
		participants = server.voice_chat_participants
	})

func _create_user(id: int) -> Node:
	var user = AudioStreamPlayer.new()
	user.stream = AudioStreamOpusChunked.new()
	user.autoplay = true
	user.name = "User " + str(id)
	return user

func _create_peer(id: int) -> void:
	prints("peer created", id)

	users[id] = _create_user(id)
	$Outputs.add_child(users[id])

	var new_bus_index: int = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(new_bus_index, str(id))
	users[id].bus = str(id)
	user_bus_indices[id] = new_bus_index

	# This is a hack, but it fixes the delay. The delay has nothing to do with the network latency, but something to do with the audio.
	await Lib.seconds(1.0)
	users[id].playing = false
	await Lib.seconds(0.1)
	users[id].playing = true

func _remove_peer(id: int) -> void:
	if not id in users:
		return
	
	users[id].queue_free()
	users.erase(id)

	AudioServer.remove_bus(user_bus_indices[id])
	user_bus_indices.erase(id)

@rpc("any_peer", "call_remote", "unreliable") # TODO remove pitch
func _upstream_packets(channel_id: String, packet, pitch: float, activity_level: float = 0.0, speaking_activity_level: float = 0.0) -> void:
	if not channel_id in HeadlessServer.instance.server.voice_chat_participants:
		return
	
	var sender_id := multiplayer.get_remote_sender_id()
	if not sender_id in HeadlessServer.instance.server.voice_chat_participants[channel_id]:
		return
	
	for participant_id in HeadlessServer.instance.server.voice_chat_participants[channel_id]:
		if participant_id == sender_id:
			continue
		
		_downstream_packets.rpc_id(participant_id, channel_id, sender_id, packet, pitch, activity_level, speaking_activity_level)

@rpc("authority", "call_remote", "unreliable")
func _downstream_packets(channel_id: String, user_id: int, packet, pitch: float, activity_level: float = 0.0, speaking_activity_level: float = 0.0) -> void:
	if not user_id in users:
		print("invalid user found: %s" % user_id)
		return
	if not is_instance_valid(active_channel) or not active_channel.id == channel_id:
		return
	
	users[user_id].pitch_scale = pitch
	users[user_id].stream.push_opus_packet(packet, 0, 0)
	users[user_id].set_meta("speaking_activity_level", speaking_activity_level)
	users[user_id].set_meta("activity_level", activity_level)
	users[user_id].volume_linear = speaking_activity_level

func _process(_delta: float) -> void:
	if HeadlessServer.is_headless_server:
		return
	
	if not is_instance_valid(active_channel):
		return
	
	while mic_capture.chunk_available():
		var packet := mic_capture.read_opus_packet(PackedByteArray())
		var speaking_activity_level: float = mic_capture.denoise_resampled_chunk()
		var activity_level := mic_capture.chunk_max(true, true)
		mic_capture.drop_chunk()

		local_activity_level = activity_level

		# if volume > 0.05 or true:
		
		if not muted:
			_upstream_packets.rpc_id(1, active_channel.id, packet, mic_mix_rate / 44100.0, activity_level, speaking_activity_level)
