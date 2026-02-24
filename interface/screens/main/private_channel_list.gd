class_name PrivateChannelList extends VBoxContainer

static var instance: PrivateChannelList

var last_channel_selected: Channel
var skip_one_for_some_reason: bool = true

func _ready() -> void:
	instance = self

	await Lib.frame

	App.instance.server_selected.connect(func(server: Server):
		queue_redraw()
	)

	visibility_changed.connect(func() -> void:
		await Lib.frame
		
		if not is_visible_in_tree():
			return
		
		ChatFrame.instance.selected_channel = last_channel_selected
	)

func _draw() -> void:
	for child in get_children():
		if child.name == "ServerInfoContainer":
			continue
		
		if child.name == "Divider":
			break
		
		child.free()
	
	if not is_instance_valid(App.selected_server):
		return
	
	var sorted := App.selected_server.private_channels.duplicate()
	sorted.sort_custom(func(a, b): return a.last_message_timestamp > b.last_message_timestamp)
	for channel in sorted:
		channel.server = App.selected_server

		if not last_channel_selected:
			last_channel_selected = channel

		var control: Button = preload("res://interface/components/servers/private_channel_button.tscn").instantiate()
		control.channel = channel
		control.pressed.connect(func() -> void:
			last_channel_selected = channel
		)
		add_child(control)
