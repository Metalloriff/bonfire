extends PanelContainer

var peer_id: int
var user: User:
	set(new):
		if user != new:
			user = new

			if is_instance_valid(user) and is_instance_valid(user.avatar):
				%Avatar.texture = user.avatar
var channel: Channel
var participant: Dictionary:
	get:
		if not is_instance_valid(channel):
			return {}
		if not channel.id in channel.server.voice_chat_participants:
			return {}
		if not peer_id in channel.server.voice_chat_participants[channel.id]:
			return {}
		return channel.server.voice_chat_participants[channel.id][peer_id]

@onready var volume_indicator: ProgressBar = %VolumeIndicator
@onready var speaking_indicator: Control = $SpeakingIndicator
@onready var soundboard_indicator: Control = $SoundboardIndicator
@onready var mute_indicator: TextureRect = %MuteIndicator
@onready var deafen_indicator: TextureRect = %DeafenIndicator
@onready var avatar: TextureRect = %Avatar

func _ready() -> void:
	var context_menu_scene: PackedScene = preload("res://interface/components/context_menu/voice_member_context_menu.tscn")

	ContextMenu.attach_listener(self , context_menu_scene, func(menu: ContextMenu) -> void:
		menu.user = user
	)

func _process(delta: float) -> void:
	volume_indicator.visible = is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel.id == channel.id
	if not volume_indicator.visible:
		return
	
	var activity_level: float = 0.0
	var speaking_activity_level: float = 0.0
	var soundboard_activity_level: float = 0.0

	if peer_id == channel.server.com_node.multiplayer.get_unique_id():
		activity_level = VoiceChat.local_activity_level
		speaking_activity_level = VoiceChat.local_speaking_activity_level
		soundboard_activity_level = VoiceChat.soundboard.local_activity_level
	else:
		if not peer_id in VoiceChat.users or not VoiceChat.users[peer_id].has_meta("activity_level"):
			return
		activity_level = VoiceChat.users[peer_id].get_meta("activity_level")
		speaking_activity_level = VoiceChat.users[peer_id].get_meta("speaking_activity_level")

		if peer_id in VoiceChat.soundboard.users and VoiceChat.soundboard.users[peer_id].has_meta("activity_level"):
			soundboard_activity_level = VoiceChat.soundboard.users[peer_id].get_meta("activity_level")

	if participant.muted:
		activity_level = 0.0
		speaking_activity_level = 0.0
	
	var target_opacity = 1.0
	if participant.muted:
		target_opacity -= 0.5
	if participant.deafened:
		target_opacity -= 0.3
	
	volume_indicator.value = activity_level * 3.0
	speaking_indicator.modulate.a = clampf(lerpf(speaking_indicator.modulate.a, speaking_activity_level, clampf(delta * 15.0, 0.0, 1.0)), 0.0, 1.0)
	soundboard_indicator.modulate.a = clampf(lerpf(soundboard_indicator.modulate.a, soundboard_activity_level, clampf(delta * 15.0, 0.0, 1.0)), 0.0, 1.0)
	mute_indicator.visible = participant.muted
	deafen_indicator.visible = participant.deafened

	volume_indicator.visible = not participant.muted
	avatar.modulate.a = lerpf(avatar.modulate.a, target_opacity, clampf(delta * 15.0, 0.0, 1.0))
