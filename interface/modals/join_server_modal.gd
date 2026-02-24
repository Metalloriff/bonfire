extends Control

var local_auth: Dictionary = {}
var local_auth_pw_hash: String

func _on_private_profile_toggle_toggled(toggled_on: bool) -> void:
	%PrivateProfileSettings.visible = toggled_on

func _validate_private_profile() -> bool:
	var username: String = %PrivateUsername.text
	var password: String = %PrivatePassword.text
	var local_password: String = %LocalPassword.text
	var local_pin: String = %LocalPin.text

	if len(username) < 4 or len(username) > 32:
		%UsernameError.show()
		%UsernameError.text = "Username must be between 4 and 32 characters long."
		return false
	
	if len(password) < 4 or len(password) > 128:
		%PasswordError.show()
		%PasswordError.text = "Password must be between 4 and 128 characters long."
		return false
	
	var local_pw_enc: String = FS.get_pref("auth.pw_encrypted", "")
	var local_pw_dec: String = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(local_pw_enc), local_pin)

	if not local_pw_dec or "�" in local_pw_dec:
		%LocalPinError.show()
		%LocalPinError.text = "Incorrect PIN."
		return false
	
	if local_pw_dec != local_password:
		%LocalPasswordError.show()
		%LocalPasswordError.text = "Your password is incorrect."
		return false
	
	local_auth = {
		username = username,
		encrypted_password = Marshalls.raw_to_base64(EncryptionTools.encrypt_string(password, local_password))
	}

	local_auth_pw_hash = password.sha256_text()
	
	return true

func _on_join_button_pressed() -> void:
	if %PrivateProfileSettings.visible:
		if not _validate_private_profile():
			return

	var split: PackedStringArray = %Address/LineEdit.text.split(":")
	var address: String = split[0]
	var port: int = int(split[1]) if len(split) > 1 else 0

	if len(split) > 2:
		# TODO add a way to handle port and ipv6 addresses
		address = %Address/LineEdit.text
		port = 26969
	
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
	
	if %PrivateProfileSettings.visible and local_auth:
		var private_profiles: Dictionary = FS.get_pref("auth.private_profiles", {})
		private_profiles[server_id] = local_auth
		FS.set_pref("auth.private_profiles", private_profiles)

		AuthPortal.private_profiles[server_id] = {
			username = local_auth.username,
			password_hash = local_auth_pw_hash
		}

	var server_node: ServerComNode = ServerComNode.new(server_id)
	if server_node.error:
		%Address/Error.show()
		%Address/Error.text = "Failed to connect to %s:%d!" % [address, port]
		return
	
	%Address/Success.show()
	
	while server_node._peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await get_tree().process_frame

		if server_node.connected_time > 5.0:
			%Address/Error.show()
			%Address/Error.text = "Failed to connect to %s:%d! Server data request timed out." % [address, port]

			server_node.local_multiplayer.multiplayer_peer.close()
			server_node.queue_free()
			return

	ServerList.instance.queue_redraw.call_deferred()
	ModalStack.fade_free_modal(self )

func _on_line_edit_text_submitted(new_text: String) -> void:
	_on_join_button_pressed()
