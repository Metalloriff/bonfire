extends ContextMenu

@onready var rect: QRCodeRect = %QRCodeRect

func _on_line_edit_text_changed(new_text: String) -> void:
	rect.data = new_text.to_utf8_buffer()
	rect._update_qr()

func _on_attach_button_pressed() -> void:
	ModalStack.fade_free_modal(self )

	if not rect.data.is_empty():
		rect.texture.get_image().save_png("user://cache/qr_code.png")
		MainTextArea.instance._on_file_dialog_files_selected(["user://cache/qr_code.png"])
