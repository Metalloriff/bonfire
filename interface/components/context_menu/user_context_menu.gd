extends ContextMenu

var user: User
var server: Server

func _ready() -> void:
	await Lib.frame

	if not is_instance_valid(user):
		queue_free()
		return
	if not is_instance_valid(server):
		queue_free()
		return
	
	%UsernameLabel.text = user.name.substr(0, 20)

	if user.id == server.user_id:
		%PrivateMessageButton.hide()
	
	if not user.is_online_in_server(server):
		%PrivateMessageButton.disabled = true
		%PrivateMessageButton.tooltip_text = "Private message is not available for offline users. Wait for them to go online."

func _on_private_message_button_pressed() -> void:
	var existing_channel: Channel = user.get_direct_message_channel(server)

	if not existing_channel:
		server.send_api_message("create_private_channel_with_user", {
			user_id = user.id
		})
		
		while not is_instance_valid(existing_channel):
			existing_channel = user.get_direct_message_channel(server)
			await Lib.seconds(0.5)
	
	ChatFrame.instance.selected_channel = existing_channel

	await Lib.frame

	PrivateChannelList.instance.show()
	PrivateChannelList.instance.queue_redraw()

func _on_copy_user_id_button_pressed() -> void:
	DisplayServer.clipboard_set(user.id)
	NotificationDaemon.show_toast("User ID copied to clipboard")
	queue_free()
