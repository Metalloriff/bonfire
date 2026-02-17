class_name MessageEncryptionContextMenu extends ContextMenu

static var encrypt_message_enabled: bool
static var encryption_key: String

func _ready() -> void:
	%EncryptMessage.button_pressed = encrypt_message_enabled
	%EncryptionKey.text = encryption_key

func _on_encryption_key_text_changed(new_text: String) -> void:
	encryption_key = new_text

func _on_encrypt_message_toggled(toggled_on: bool) -> void:
	encrypt_message_enabled = toggled_on
	MainTextArea.instance.get_node("EncryptButton").theme_type_variation = &"Button_Important" if toggled_on else &""
