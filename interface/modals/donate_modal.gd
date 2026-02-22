extends Control

func _ready() -> void:
	for field: LineEdit in Lib.find_child_nodes(self , func(node: Node) -> bool: return node is LineEdit):
		var start_text: String = field.text
		field.text_changed.connect(func(_new_text: String) -> void: field.text = start_text)

		if field.get_parent().has_node("CopyButton"):
			field.get_parent().get_node("CopyButton").pressed.connect(func() -> void:
				DisplayServer.clipboard_set(field.text)
				NotificationDaemon.show_toast("Copied to clipboard.")
			)
	
	var crypto_qr_codes: Array = Lib.find_child_nodes(self , func(node: Node) -> bool: return node.name == "CryptoQR")

	for i in len(crypto_qr_codes):
		var crypto_qr: TextureRect = crypto_qr_codes[i]
		var other_qr: TextureRect = crypto_qr_codes[(i + 1) % len(crypto_qr_codes)]

		crypto_qr.mouse_entered.connect(func() -> void:
			create_tween().tween_property(other_qr, "modulate:a", 0.0, 0.25)
		)

		crypto_qr.mouse_exited.connect(func() -> void:
			create_tween().tween_property(other_qr, "modulate:a", 1.0, 0.25)
		)

func _on_open_kofi_button_pressed() -> void:
	OS.shell_open("https://ko-fi.com/metalloriff")
