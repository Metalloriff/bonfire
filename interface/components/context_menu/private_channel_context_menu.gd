extends ContextMenu

var channel: Channel

func _on_purge_button_pressed() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_on_confirm_purge_button_pressed()
		return
	
	%PurgeConfirmation.show()

func _on_delete_button_pressed() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_on_confirm_delete_button_pressed()
		return
	
	%DeleteConfirmation.show()

func _on_rename_button_pressed() -> void:
	NotificationDaemon.show_toast("Not implemented yet")

func _on_confirm_delete_button_pressed() -> void:
	channel.delete_channel()
	fade_free()

func _on_cancel_delete_button_pressed() -> void:
	%DeleteConfirmation.hide()

func _on_confirm_purge_button_pressed() -> void:
	channel.purge_messages()
	fade_free()

func _on_cancle_purge_button_pressed() -> void:
	%PurgeConfirmation.hide()
