extends Control

func _ready() -> void:
	$Background.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			queue_free()
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			queue_free()
	)

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
	
	while not is_instance_valid(server_node.server):
		await get_tree().process_frame

		if server_node.connected_time > 5.0:
			%Address/Error.show()
			%Address/Error.text = "Failed to connect to %s:%d! Server data request timed out." % [address, port]

			server_node.local_multiplayer.multiplayer_peer.close()
			server_node.queue_free()
			return

	ServerList.instance.queue_redraw.call_deferred()
	queue_free()
