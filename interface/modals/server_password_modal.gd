extends Control

var server_name: String
var hash: String
var callback: Callable

func _ready() -> void:
	await Lib.frame
	
	%Label.text = "Password for %s" % server_name

func _on_authenticate_button_pressed() -> void:
	if not hash:
		%ErrorLabel.show()
		return
	
	if %PasswordField.text.sha256_text() != hash:
		%ErrorLabel.show()
		return
	
	callback.call(%PasswordField.text)

	ModalStack.fade_free_modal(self )

func _on_cancel_button_pressed() -> void:
	ModalStack.fade_free_modal(self )

func _on_password_field_text_submitted(new_text: String) -> void:
	_on_authenticate_button_pressed()

func _on_password_field_text_changed(new_text: String) -> void:
	%ErrorLabel.hide()
