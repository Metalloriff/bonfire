class_name ServerList extends VBoxContainer

static var instance: ServerList

func _ready() -> void:
	instance = self

func _draw():
	for child in get_children():
		if child.name == "Divider":
			break
		
		child.free()
	
	for server_resource_path: String in FS.get_files("user://servers"):
		var server: Server = load("user://servers/%s" % server_resource_path)
		var control: Button = load("res://interface/components/servers/server_item.tscn").instantiate()

		control.tooltip_text = server.name
		control.server = Server.get_server(server.id)

		control.pressed.connect(func() -> void:
			App.selected_server = Server.get_server(server.id)
		)

		add_child(control)
		move_child(control, 0)
