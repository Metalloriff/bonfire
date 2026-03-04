class_name ChatFrame extends PanelContainer

static var instance: ChatFrame

signal channel_selected(channel: Channel)

var selected_channel: Channel:
	set(new):
		if selected_channel != new:
			selected_channel = new
			channel_selected.emit(selected_channel)

			instance.queue_redraw()
			MemberList.instance.queue_redraw()
			
			if is_instance_valid(MobileControlsContainer.instance):
				await Lib.frame
				MobileControlsContainer.instance.fade_to_chat()
var last_channel: Channel
var force_text: bool

func add_scroll(amount: float, instant: bool = false) -> void:
	var text_chat_screen: TextChatScreen = get_node_or_null("TextChat")
	if not is_instance_valid(text_chat_screen):
		return
	
	if instant:
		text_chat_screen.get_v_scroll_bar().value += amount
	else:
		create_tween().tween_property(text_chat_screen.get_v_scroll_bar(), "value", amount, 0.2).as_relative()

func _ready() -> void:
	instance = self

func _draw() -> void:
	if selected_channel == last_channel:
		for child in get_children():
			if child is TextChatScreen:
				child.render()
			else:
				child.queue_redraw()
		return
	
	last_channel = selected_channel

	for child in get_children():
		child.free()
	
	if not is_instance_valid(selected_channel):
		return
	
	if force_text:
		var control = load("res://interface/screens/text_chat_screen.tscn").instantiate()
		control.channel = selected_channel
		add_child(control)

		force_text = false

		return

	match selected_channel.type:
		Channel.Type.TEXT:
			var control = load("res://interface/screens/text_chat_screen.tscn").instantiate()
			control.channel = selected_channel
			add_child(control)
		Channel.Type.VOICE:
			var control = load("res://interface/screens/voice_chat_screen.tscn").instantiate()
			control.channel = selected_channel
			add_child(control)
		Channel.Type.MEDIA:
			pass
