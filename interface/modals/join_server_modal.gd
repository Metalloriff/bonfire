extends Control

func _on_private_profile_toggle_toggled(toggled_on: bool) -> void:
	$Modal/MarginContainer/VBoxContainer/UniqueProfileSettings.visible = toggled_on

func _on_join_button_pressed() -> void:
	var split: PackedStringArray = %Address/LineEdit.text.split(":")
	var address: String = split[0]
	var port: int = int(split[1]) if len(split) > 1 else 0
	
	if not port:
		port = 26969
	
	if not address:
		%Address/Error.show()
		%Address/Error.text = "You must provide a server address."
		return
	
	prints("sending handshake request to", address, port)
	var server_id: String = await ServerHandshake.instance.handshake(address, port)

	if not server_id:
		%Address/Error.show()
		%Address/Error.text = "Failed to connect to %s:%d!" % [address, port]
		return

	var server_node: ServerComNode = ServerComNode.new(server_id)
	if server_node.error:
		%Address/Error.show()
		%Address/Error.text = "Failed to connect to %s:%d!" % [address, port]
		return
	
	%Address/Success.show()
	
	while server_node._peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await get_tree().process_frame

		if server_node.connected_time > 5.0:
			%Address/Error.show()
			%Address/Error.text = "Failed to connect to %s:%d! Server data request timed out." % [address, port]

			server_node.local_multiplayer.multiplayer_peer.close()
			server_node.queue_free()
			return

	ServerList.instance.queue_redraw.call_deferred()
	ModalStack.fade_free_modal(self )

func _on_line_edit_text_submitted(new_text: String) -> void:
	_on_join_button_pressed()
