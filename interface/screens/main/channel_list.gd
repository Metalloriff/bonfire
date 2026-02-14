class_name ChannelList extends VBoxContainer

static var instance: ChannelList

func _ready() -> void:
	instance = self

	await get_tree().process_frame

	App.instance.server_selected.connect(func(_server: Server) -> void:
		queue_redraw()
	)

func _draw():
	for child in get_children():
		if child.name == "ServerInfoContainer":
			continue
		
		if child.name == "Divider":
			break
		
		child.free()
	
	$ServerInfoContainer/ServerInfo.visible = is_instance_valid(App.selected_server)
	
	if not is_instance_valid(App.selected_server):
		return
	
	$ServerInfoContainer/ServerInfo/Name.text = App.selected_server.name
	
	for channel in App.selected_server.channels:
		channel.server = App.selected_server
		
		var control: VBoxContainer = load("res://interface/components/servers/channel_button.tscn").instantiate()
		control.channel = channel
		add_child(control)
