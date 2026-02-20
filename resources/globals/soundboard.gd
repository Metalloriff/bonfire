class_name Soundboard extends Node

var bus: int = AudioServer.get_bus_index("Soundboard")
var capture: AudioEffectOpusChunked
var users: Dictionary = {}
var local_activity_level: float

func _ready() -> void:
	if HeadlessServer.is_headless_server:
		queue_free()
		return
	
	capture = AudioServer.get_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	get_window().files_dropped.connect(func(files: PackedStringArray) -> void:
		if not VoiceChat.active_channel:
			return
		
		if ChatFrame.instance.selected_channel != VoiceChat.active_channel:
			return
		
		if len(files) > 1:
			return
		
		var file: String = files[0]
		if not file.get_extension() in ["mp3", "ogg", "wav"]:
			return
		
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		var stream: AudioStream

		match file.get_extension():
			"mp3":
				stream = AudioStreamMP3.new()
			"ogg":
				stream = AudioStreamOggVorbis.new()
			"wav":
				stream = AudioStreamWAV.new()
		
		player.stream = stream.load_from_file(file)
		player.autoplay = true
		player.bus = "Soundboard"
		player.finished.connect(func() -> void: player.queue_free())
		player.volume_linear = 0.5

		add_child(player)
	)

func _create_peer(id: int) -> void:
	users[id] = VoiceChat._create_user(id)
	add_child(users[id])

	await Lib.seconds(1.5)
	users[id].playing = false
	await Lib.seconds(0.1)
	users[id].playing = true

func _remove_peer(id: int) -> void:
	if not id in users:
		return
	
	users[id].queue_free()
	users.erase(id)

func _process(_delta: float) -> void:
	if HeadlessServer.is_headless_server:
		return

	if not is_instance_valid(VoiceChat.active_channel):
		return
	
	while capture.chunk_available():
		var packet := capture.read_opus_packet(PackedByteArray())
		var activity_level := capture.chunk_max(true, true)
		capture.drop_chunk()

		local_activity_level = clampf(activity_level * 100.0, 0.0, 1.0)
		
		if activity_level > 0.00001:
			VoiceChat._upstream_packets.rpc_id(1, VoiceChat.active_channel.id, packet, activity_level * 100.0, 0.0, true)
