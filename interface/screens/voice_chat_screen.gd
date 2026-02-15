extends VSplitContainer

var channel: Channel:
	set(new):
		if channel != new:
			if is_instance_valid(channel) and channel.message_received.is_connected(_message_received):
				channel.message_received.disconnect(_message_received)
			
			channel = new
			$TextChatContainer/TextChat.channel = new

			if is_instance_valid(channel):
				channel.message_received.connect(_message_received)

var unread_message_count: int = 0

@onready var user_tiles: HFlowContainer = $VC/UserTiles

func _ready() -> void:
	if is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel == channel:
		_fade_in_focus(0.0)
	else:
		_fade_out_focus(0.0)

func _message_received(message: Message) -> void:
	unread_message_count += 1
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel == channel:
		_fade_in_focus()
	else:
		_fade_out_focus()

	%OutOfCallControls.visible = not is_instance_valid(VoiceChat.active_channel) or VoiceChat.active_channel != channel
	%InCallControls.visible = is_instance_valid(VoiceChat.active_channel) and VoiceChat.active_channel == channel

	$TextChatContainer/TextChat.queue_redraw()
	
	if $TextChatContainer.size.y > 50:
		unread_message_count = 0
		%NewMessagesButton.text = "Close Chat"
		%NewMessagesButton.visible = true
	else:
		%NewMessagesButton.text = "%d new messages" % unread_message_count
		%NewMessagesButton.visible = unread_message_count > 0
	
	%MuteButton.theme_type_variation = &"Button_Red" if VoiceChat.muted else &""
	%MuteButton.icon = preload("res://icons/micOff.png") if VoiceChat.muted else preload("res://icons/mic.png")
	%MuteButton.text = "Unmute" if VoiceChat.muted else "Mute"

	var vc_participants: Array = channel.server.voice_chat_participants[channel.id] if channel.id in channel.server.voice_chat_participants else []

	for peer_id: int in vc_participants:
		if user_tiles.has_node(str(peer_id)):
			continue
		
		var user_tile: Control = load("res://interface/components/user/user_voice_chat_square.tscn").instantiate()
		user_tile.peer_id = peer_id
		user_tile.user = channel.server.get_user_by_peer_id(peer_id)
		user_tile.channel = channel
		user_tiles.add_child(user_tile)
		user_tile.name = str(peer_id)
	
	for user_tile in user_tiles.get_children():
		if not int(user_tile.name) in vc_participants:
			user_tile.queue_free()

func _fade_out_focus(tween_time: float = 0.5) -> void:
	var tiles: HFlowContainer = $VC/UserTiles
	var notice: Label = $VC/Notice

	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)

	tween.tween_property(tiles, "modulate:a", 0.25, tween_time)
	tween.tween_property(tiles, "scale", Vector2.ONE * 0.85, tween_time)
	tween.tween_property(notice, "modulate:a", 1.0, tween_time)
	tween.tween_property(notice, "scale", Vector2.ONE * 1.0, tween_time)

func _fade_in_focus(tween_time: float = 0.5) -> void:
	var tiles: HFlowContainer = $VC/UserTiles
	var notice: Label = $VC/Notice

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

func _on_new_messages_button_pressed() -> void:
	split_offsets[0] = 0 if split_offsets[0] < 0 else -500

func _on_dragged(offset: int) -> void:
	$TextChatContainer/TextChat.set_deferred(&"scroll_vertical", -9999999999)

func _on_mute_button_pressed() -> void:
	VoiceChat.muted = not VoiceChat.muted
	queue_redraw()
