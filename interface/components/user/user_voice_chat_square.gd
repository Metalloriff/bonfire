extends PanelContainer

var peer_id: int
var user: User:
	set(new):
		if user != new:
			user = new

			if is_instance_valid(user):
				$Avatar.texture = user.avatar
var channel: Channel

@onready var volume_indicator: ProgressBar = %VolumeIndicator
@onready var speaking_indicator: Control = $SpeakingIndicator

func _process(_delta: float) -> void:
	volume_indicator.visible = is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel.id == channel.id
	if not volume_indicator.visible:
		return
	
	var activity_level: float = 0.0
	var speaking_activity_level: float = 0.0

	if peer_id == channel.server.com_node.multiplayer.get_unique_id():
		activity_level = VoiceChat.local_activity_level
		speaking_activity_level = VoiceChat.local_speaking_activity_level
	else:
		if not peer_id in VoiceChat.users or not VoiceChat.users[peer_id].has_meta("activity_level"):
			return
		activity_level = VoiceChat.users[peer_id].get_meta("activity_level")
		speaking_activity_level = VoiceChat.users[peer_id].get_meta("speaking_activity_level")
	volume_indicator.value = activity_level * 3.0
	speaking_indicator.modulate.a = clampf(speaking_activity_level, 0.0, 1.0)
