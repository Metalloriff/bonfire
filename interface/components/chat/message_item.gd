extends VBoxContainer

var author: User
var message: Message

func _ready() -> void:
	if message.encrypted:
		%Content.hide()
		$Encryption.show()

		var decrypt_button: Button = $Encryption/Encrypted/Button
		var password_field: LineEdit = $Encryption/Encrypted/Password

		password_field.text_changed.connect(func(_t: String) -> void:
			$Encryption/ErrorText.hide()
		)

		decrypt_button.pressed.connect(func() -> void:
			var decrypted_content: String = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(message.content), password_field.text)

			if "�" in decrypted_content:
				$Encryption/ErrorText.show()
			else:
				$Encryption/ErrorText.hide()
				$Encryption/Encrypted.hide()
				$Encryption/Decrypted.show()

				%Content.show()
				%Content.text = "🔓 " + _process_message_content(decrypted_content)
				%Content.modulate.a = 0.75
		)

		$Encryption/Decrypted/Button.pressed.connect(func() -> void:
			$Encryption/Decrypted.hide()
			$Encryption/Encrypted.show()

			%Content.hide()
		)
	else:
		%Content.text = _process_message_content(message.content)

	if OS.has_feature("android") or OS.has_feature("ios"):
		mouse_filter = MOUSE_FILTER_IGNORE

func _on_content_meta_clicked(meta: Variant) -> void:
	if "https://" in meta or "http://" in meta:
		OS.shell_open(meta)
	prints("MessageGroupNode", "_on_meta_clicked", meta)

func _on_content_meta_hover_ended(meta: Variant) -> void:
	prints("MessageGroupNode", "_on_meta_hover_ended", meta)

func _on_content_meta_hover_started(meta: Variant) -> void:
	prints("MessageGroupNode", "_on_meta_hover_started", meta)

func _process_message_content(content: String) -> String:
	# replace URLs with clickable links in the form of [url=https://examples.com]examples.com[/url]
	# find and replace URLs with clickable links
	var regex = RegEx.new()
	regex.compile("https?:\\/\\/(?:www\\.)?((?:[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b(?:[-a-zA-Z0-9()@:%_\\+.~#?&\\/=]*)))")
	content = regex.sub(content, "[url=$0]$1[/url]", true)

	return content
