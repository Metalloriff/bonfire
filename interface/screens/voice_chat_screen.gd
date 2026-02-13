extends Control

var channel: Channel

func _ready() -> void:
	if is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel == channel:
		_fade_in_focus(0.0)
	else:
		_fade_out_focus(0.0)

func _draw() -> void:
	if is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel == channel:
		_fade_in_focus()
	else:
		_fade_out_focus()

	%OutOfCallControls.visible = not is_instance_valid(VoiceChat.active_channel) or VoiceChat.active_channel != channel
	%InCallControls.visible = is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel == channel

func _fade_out_focus(tween_time: float = 0.5) -> void:
	var tiles: HFlowContainer = $UserTiles
	var notice: Label = $Notice

	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)

	tween.tween_property(tiles, "modulate:a", 0.25, tween_time)
	tween.tween_property(tiles, "scale", Vector2.ONE * 0.85, tween_time)
	tween.tween_property(notice, "modulate:a", 1.0, tween_time)
	tween.tween_property(notice, "scale", Vector2.ONE * 1.0, tween_time)

func _fade_in_focus(tween_time: float = 0.5) -> void:
	var tiles: HFlowContainer = $UserTiles
	var notice: Label = $Notice

	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)

	tween.tween_property(tiles, "modulate:a", 1.0, tween_time)
	tween.tween_property(tiles, "scale", Vector2.ONE, tween_time)
	tween.tween_property(notice, "modulate:a", 0.0, tween_time)
	tween.tween_property(notice, "scale", Vector2.ONE * 0.5, tween_time)

func _on_join_call_button_pressed() -> void:
	VoiceChat.connect_to_channel(channel)
	queue_redraw()

func _on_end_call_button_pressed() -> void:
	VoiceChat.disconnect_from_channel()
