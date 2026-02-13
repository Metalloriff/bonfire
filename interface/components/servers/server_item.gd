extends Button

var server: Server

func _process(_delta: float) -> void:
	if not is_instance_valid(server):
		return

	if not is_instance_valid(server.com_node) or server.com_node.local_multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		$ConnectionIssueIcon.show()
		$Icon.modulate.a = 0.5
	else:
		$ConnectionIssueIcon.hide()
		$Icon.modulate.a = 1.0