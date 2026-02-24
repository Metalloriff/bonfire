class_name ChatFrame extends PanelContainer

static var instance: ChatFrame

signal channel_selected(channel: Channel)

var selected_channel: Channel:
	set(new):
		if selected_channel != new:
			selected_channel = new
			channel_selected.emit(selected_channel)

			instance.queue_redraw()
			
			if is_instance_valid(MobileControlsContainer.instance):
				await Lib.frame
				MobileControlsContainer.instance.fade_to_chat()
var last_channel: Channel
var force_text: bool

func _ready() -> void:
	instance = self

func _draw() -> void:
	if selected_channel == last_channel:
		for child in get_children():
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
