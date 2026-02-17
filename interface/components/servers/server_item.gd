extends Button

var server: Server:
	set(new):
		if server != new:
			server = new
			
			queue_redraw()

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
	else:
		$ConnectionIssueIcon.hide()
		$Icon.modulate.a = 1.0
