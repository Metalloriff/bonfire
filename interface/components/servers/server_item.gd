extends Button

var server: Server:
	set(new):
		if server != new:
			server = new
			
			queue_redraw()

func _ready() -> void:
	ContextMenu.attach_listener(self , preload("res://interface/components/context_menu/server_context_menu.tscn"), func(menu: ContextMenu) -> void:
		menu.server = server
	)

func _draw() -> void:
	if not is_instance_valid(server):
		$PlaceholderIcon.show()
		return

	$PlaceholderIcon.visible = not server.icon
	$PlaceholderIcon/Label.text = server.name[0].to_upper() + server.name[-1].to_upper()

	$Icon.texture = server.icon

func _process(_delta: float) -> void:
	if not is_instance_valid(server):
		return

	if not is_instance_valid(server.com_node) or server.com_node.local_multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		$ConnectionIssueIcon.show()
		$Icon.modulate.a = 0.5

		if App.instance.selected_server == server:
			App.instance.selected_server_connection_issue = true
	else:
		$ConnectionIssueIcon.hide()
		$Icon.modulate.a = 1.0

		if App.instance.selected_server == server:
			App.instance.selected_server_connection_issue = false
