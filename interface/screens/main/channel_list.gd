class_name ChannelList extends VBoxContainer

static var instance: ChannelList

var last_channel_selected: Channel
var re_order_mode: bool

func _ready() -> void:
	instance = self

	ContextMenu.attach_listener(self , preload("res://interface/components/context_menu/channel_list_context_menu.tscn"), func(menu: ContextMenu) -> void:
		if not App.instance.selected_server.local_user.has_permission(App.instance.selected_server, Permissions.CHANNEL_MANAGE):
			menu.queue_free()
			return
		
		menu.server = App.selected_server
	)

	await get_tree().process_frame

	App.instance.server_selected.connect(func(_server: Server) -> void:
		last_channel_selected = null
		queue_redraw()
	)

	visibility_changed.connect(func() -> void:
		await Lib.frame

		if not is_visible_in_tree():
			return
		
		ChatFrame.instance.selected_channel = last_channel_selected
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

		if not last_channel_selected:
			last_channel_selected = channel
			ChatFrame.instance.selected_channel = channel
		
		var control: VBoxContainer = load("res://interface/components/servers/channel_button.tscn").instantiate()

		control.channel = channel

		if re_order_mode:
			control.get_node("Button").mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			control.get_node("Button").pressed.connect(func() -> void:
				last_channel_selected = channel
			)

		add_child(control)
