extends Node

func _ready() -> void:
	VoiceChat.user_joined.connect(func(channel_id: String, _pid: int) -> void:
		if is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel.id == channel_id:
			play_sound("vc_member_join")
	)
	
	VoiceChat.user_left.connect(func(channel_id: String, _pid: int) -> void:
		if is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel.id == channel_id:
			play_sound("vc_member_leave")
	)

func play_sound(sound_type: String) -> void:
	var stream_player: AudioStreamPlayer = get_node_or_null("Sounds/%s" % sound_type)
	assert(is_instance_valid(stream_player), "Sound %s does not exist" % sound_type)
	stream_player.play()
