extends Control

@onready var _username: String = FS.get_pref("auth.username", "")
@onready var _password_hash: String = FS.get_pref("auth.pw_hash", "")

func _ready() -> void:
	if "--server" in OS.get_cmdline_args():
		get_tree().change_scene_to_file("res://interface/headless_server.tscn")
		return

	if _username and _password_hash:
		$Contents/Username.hide()
		$Contents/PasswordConfirm.hide()

		%SubmitButton.text = "Login"
		$Label.text = "Hello, %s." % _username
		$Label.visible_characters = 0

		create_tween().tween_property($Label, "visible_characters", len($Label.text), 1.5)
		$Contents/Password/LineEdit.grab_focus()
	else:
		$Contents/Username/LineEdit.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_submit_button_pressed()

func _on_submit_button_pressed() -> void:
	var password: String = $Contents/Password/LineEdit.text
	var password_hash: String = password.sha256_text()

	if not _password_hash:
		var username: String = $Contents/Username/LineEdit.text
		var password_confirm: String = $Contents/PasswordConfirm/LineEdit.text
		
		if not username or len(username) > 32:
			$Contents/Username/Error.show()
			$Contents/Username/Error.text = "Username must be between 1 and 32 characters long."
			return
		
		if len(password) < 4:
			$Contents/Password/Error.show()
			$Contents/Password/Error.text = "Password must be at least 4 characters long."
			return
		
		if password != password_confirm:
			$Contents/PasswordConfirm/Error.show()
			$Contents/PasswordConfirm/Error.text = "Passwords do not match."
			return
		
		FS.set_pref("auth.username", username)
		FS.set_pref("auth.pw_hash", password_hash)

		_username = username
		_password_hash = password_hash
	else:
		if password_hash != _password_hash:
			$Contents/Password/Error.show()
			$Contents/Password/Error.text = "Incorrect password."
			return
	
	_continue()

func _continue() -> void:
	if not _username or not _password_hash:
		return
	
	await ModalStack._fade_out_modal(self )
	get_tree().change_scene_to_file("res://interface/screens/main.tscn")
