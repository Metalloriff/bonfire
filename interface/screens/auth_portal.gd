class_name AuthPortal extends Control

static var username: String
static var private_key: String
static var password_hash: String
static var private_profiles: Dictionary = {}

static func get_auth(server_id: String) -> Dictionary:
	if server_id in private_profiles:
		return private_profiles[server_id]
	
	return {
		username = username,
		password_hash = password_hash
	}

var sign_in: bool

func _init() -> void:
	if OS.has_feature("android"):
		Engine.get_main_loop().root.content_scale_factor = 3.0
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _ready() -> void:
	if "--server" in OS.get_cmdline_args():
		get_tree().change_scene_to_file("res://interface/headless_server.tscn")
		return
	
	username = FS.get_pref("auth.username", "")
	
	%AutoUpdate.button_pressed = Settings.get_value("system", "automatically_check_for_updates")
	%PreRelease.button_pressed = Settings.get_value("system", "include_prereleases")

	if username and FS.get_pref("auth.pw_encrypted", ""):
		$Contents/Username.hide()
		$Contents/Password.hide()
		$Contents/PinConfirm.hide()
		%PinRegLabel.hide()

		%SubmitButton.text = "Login"
		$Label.text = "Hello, %s." % username
		$Label.visible_characters = 0

		create_tween().tween_property($Label, "visible_characters", len($Label.text), 1.5)
		$Contents/PinCode/LineEdit.grab_focus()
		sign_in = true
	else:
		$Contents/Username/LineEdit.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_submit_button_pressed()

func _on_submit_button_pressed() -> void:
	if sign_in:
		var pin_code: String = $Contents/PinCode/LineEdit.text
		
		if not pin_code.strip_edges():
			$Contents/PinCode/Error.show()
			$Contents/PinCode/Error.text = "PIN Code cannot be empty."
			return
		
		var password_encrypted: String = FS.get_pref("auth.pw_encrypted", "")
		var password_decrypted: String = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(password_encrypted), pin_code)

		if not password_decrypted or "�" in password_decrypted:
			$Contents/PinCode/Error.show()
			$Contents/PinCode/Error.text = "Incorrect PIN Code."
			return
		
		password_hash = password_decrypted.sha256_text()
		private_key = (password_decrypted + password_hash).sha256_text()

		_init_private_profiles(password_decrypted)
	else:
		var _username: String = $Contents/Username/LineEdit.text
		var password: String = $Contents/Password/LineEdit.text
		var pin_code: String = $Contents/PinCode/LineEdit.text
		var pin_confirm: String = $Contents/PinConfirm/LineEdit.text
		
		if len(_username) < 4 or len(_username) > 128:
			$Contents/Username/Error.show()
			$Contents/Username/Error.text = "Username must be between 4 and 128 characters long."
			return
		
		if len(password) < 10:
			$Contents/Password/Error.show()
			$Contents/Password/Error.text = "Password must be at least 10 characters long."
			return
		
		if len(pin_code) < 4 or len(pin_code) > 16:
			$Contents/PinCode/Error.show()
			$Contents/PinCode/Error.text = "PIN must be 4-16 digits."
			return
		
		if pin_confirm != pin_code:
			$Contents/PinConfirm/Error.show()
			$Contents/PinConfirm/Error.text = "PINs do not match."
			return
		
		var encrypted_password: String = Marshalls.raw_to_base64(EncryptionTools.encrypt_string(password, pin_code))
		
		FS.set_pref("auth.username", _username)
		FS.set_pref("auth.pw_encrypted", encrypted_password)

		username = _username
		password_hash = password.sha256_text()
		private_key = (password + password_hash).sha256_text()

		_init_private_profiles(password)

	_continue()

func _init_private_profiles(password: String) -> void:
	var profiles: Dictionary = FS.get_pref("auth.private_profiles", {})
	private_profiles = {}

	for server_id in profiles:
		var password_decrypted: String = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(profiles[server_id].encrypted_password), password)
		if not password_decrypted or "�" in password_decrypted:
			continue
		
		private_profiles[server_id] = {
			username = profiles[server_id].username,
			password_hash = password_decrypted.sha256_text()
		}

func _continue() -> void:
	if not username or not password_hash or not private_key:
		return
	
	await ModalStack._fade_out_modal(self )
	if OS.has_feature("android") or OS.has_feature("ios"):
		get_tree().change_scene_to_file("res://interface/screens/main_mobile.tscn")
	else:
		get_tree().change_scene_to_file("res://interface/screens/main.tscn")

func _on_pre_release_toggled(toggled_on: bool) -> void:
	Settings.set_value("system", "include_prereleases", toggled_on)

func _on_auto_update_toggled(toggled_on: bool) -> void:
	Settings.set_value("system", "automatically_check_for_updates", toggled_on)
