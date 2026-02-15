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

# func _enter_tree() -> void:
# 	get_tree().root.child_entered_tree.connect(_on_new_node)

# func _on_new_node(node: Node) -> void:
# 	if not node is CanvasLayer and not node is Control: return
# 	if node.child_entered_tree.is_connected(_on_new_node): return
	
# 	node.child_entered_tree.connect(_on_new_node)
# 	await Lib.frame
	
# 	if not is_instance_valid(node): return
	
# 	if node is Button:
# 		if not node.has_meta("avoid_hover_sound"):
# 			node.mouse_entered.connect(func() -> void: play_sound("ui_hover"))
# 			node.focus_entered.connect(func() -> void: play_sound("ui_hover"))
# 		if not node.has_meta("avoid_press_sound"):
# 			node.pressed.connect(func() -> void: play_sound("ui_press"))
# 	if node is Slider:
# 		node.value_changed.connect(func(_v: float) -> void: play_sound("ui_hover"))
# 		node.focus_entered.connect(func() -> void: play_sound("ui_hover"))
# 	if node is LineEdit:
# 		node.focus_entered.connect(func() -> void: play_sound("ui_hover"))
# 		node.text_changed.connect(func(_t: String) -> void: play_sound("ui_hover"))
# 		node.text_submitted.connect(func(_t: String) -> void: play_sound("ui_press"))
# 	if node is TabBar:
# 		node.tab_hovered.connect(func(_t: int) -> void: play_sound("ui_hover"))
# 		node.tab_selected.connect(func(_t: int) -> void: play_sound("ui_press"))
