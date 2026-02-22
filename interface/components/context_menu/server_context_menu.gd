extends ContextMenu

var server: Server

func _ready() -> void:
	await Lib.frame
	
	%ServerName.text = server.name

func _on_confirm_leave_server_pressed() -> void:
	server.leave_server(%PurgeAllMessages.button_pressed)
	fade_free()

func _on_cancel_leave_server_pressed() -> void:
	%LeaveServerPanel.hide()

func _on_leave_server_button_pressed() -> void:
	%LeaveServerPanel.visible = not %LeaveServerPanel.visible
