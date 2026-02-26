extends ContextMenu

var server: Server

func _ready() -> void:
	await Lib.frame
	
	%ServerName.text = server.name
	%ViewRulesButton.visible = !!server.rules
	%EditButton.visible = server.local_user.has_permission(server, Permissions.SERVER_PROFILE_MANAGE)

func _on_confirm_leave_server_pressed() -> void:
	server.leave_server(%PurgeAllMessages.button_pressed)
	fade_free()

func _on_cancel_leave_server_pressed() -> void:
	%LeaveServerPanel.hide()

func _on_leave_server_button_pressed() -> void:
	%LeaveServerPanel.visible = not %LeaveServerPanel.visible

func _on_view_rules_button_pressed() -> void:
	var modal = ModalStack.open_modal("res://interface/modals/server_rules_modal.tscn")
	modal.server = server
	modal.viewing = true
	fade_free()

func _on_edit_button_pressed() -> void:
	var modal = ModalStack.open_modal("res://interface/modals/server_settings_modal.tscn")
	modal.server = server
	fade_free()
