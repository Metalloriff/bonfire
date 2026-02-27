extends ContextMenu

var channel: Channel

func _ready() -> void:
	await Lib.frame

	var server: Server = channel.server
	if not is_instance_valid(server):
		return

	%EditButton.visible = server.local_user.has_permission(server, Permissions.CHANNEL_MANAGE)
	%DeleteButton.visible = server.local_user.has_permission(server, Permissions.CHANNEL_MANAGE)
	%PurgeButton.visible = server.local_user.has_permission(server, Permissions.MESSAGE_PURGE)

func _on_purge_button_pressed() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_on_confirm_purge_button_pressed()
		return
	
	%PurgeConfirmation.show()

func _on_edit_button_pressed() -> void:
	var modal = ModalStack.open_modal("res://interface/modals/create_channel_modal.tscn")
	modal.existing_channel = channel
	fade_free()

func _on_confirm_purge_button_pressed() -> void:
	channel.purge_messages()
	fade_free()

func _on_cancle_purge_button_pressed() -> void:
	%PurgeConfirmation.hide()

func _on_delete_button_pressed() -> void:
	%DeleteConfirmation.show()

func _on_confirm_delete_button_pressed() -> void:
	channel.delete_channel()
	fade_free()

func _on_cancel_delete_button_pressed() -> void:
	%DeleteConfirmation.hide()
