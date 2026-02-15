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

func _process(_delta: float) -> void:
	volume_indicator.visible = is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel.id == channel.id
	if not volume_indicator.visible or not peer_id in VoiceChat.users or not VoiceChat.users[peer_id].has_meta("activity_level"):
		return
	
	var activity_level: float = VoiceChat.users[peer_id].get_meta("activity_level")
	volume_indicator.value = activity_level
