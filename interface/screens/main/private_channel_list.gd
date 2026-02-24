class_name PrivateChannelList extends VBoxContainer

static var instance: PrivateChannelList

func _ready() -> void:
	instance = self

	await Lib.frame

	App.instance.server_selected.connect(func(server: Server):
		queue_redraw()
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

		var control: VBoxContainer = load("res://interface/components/servers/channel_button.tscn").instantiate()
		control.channel = channel
		add_child(control)
