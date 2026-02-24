extends ContextMenu

var channel: Channel

func _on_purge_button_pressed() -> void:
	channel.purge_messages()
	fade_free()

func _on_delete_button_pressed() -> void:
	channel.delete_channel()
	fade_free()

func _on_rename_button_pressed() -> void:
	NotificationDaemon.show_toast("Not implemented yet")
