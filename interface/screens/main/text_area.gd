class_name MainTextArea extends HBoxContainer

static var instance: MainTextArea
static var editing_message: Message:
	set(new):
		if editing_message == new:
			return
		
		editing_message = new

		if editing_message:
			instance.field.text = editing_message.content
			instance.field.grab_focus.call_deferred()
			instance.field.set_caret_line.call_deferred(instance.field.get_line_count() - 1)

			instance.get_node("SendButton").icon = load("res://icons/edit.png")
			instance.get_node("EncryptButton").hide()
			instance.get_node("CancelEditButton").show()
		else:
			instance.field.text = ""
			instance.get_node("SendButton").icon = load("res://icons/send.png")
			instance.get_node("EncryptButton").show()
			instance.get_node("CancelEditButton").hide()

			if is_instance_valid(editing_message_item):
				editing_message_item.set_process(false)
				editing_message_item.get_node("EditingContainer").hide()
				editing_message_item.get_node("TextContents").show()
				# editing_message_item.get_node("MediaContents").show()
				editing_message_item = null
static var editing_message_item: Control

@onready var field: TextEdit = $TextEdit

func _ready() -> void:
	instance = self

func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ENTER and not event.is_echo() and len(field.text.strip_edges().strip_escapes()):
			if Input.is_key_pressed(KEY_SHIFT):
				# insert new line where cursor is and return cursor position
				var caret_line: int = field.get_caret_line()
				var lines: PackedStringArray = field.text.split("\n")
				var flat_caret_index: int = 0
				var search_line: int = 0

				# TODO This is whack

				while search_line <= caret_line:
					flat_caret_index += len(lines[search_line]) if search_line < caret_line else field.get_caret_column()
					search_line += 1

				field.text = field.text.insert(flat_caret_index, "\n")
				field.set_caret_line.call_deferred(caret_line + 1)
			else:
				field.text = field.text.strip_edges().strip_escapes()
				_on_send_button_pressed()

func _on_send_button_pressed() -> void:
	assert(is_instance_valid(ChatFrame.instance.selected_channel), "No channel selected")

	if is_instance_valid(editing_message):
		ChatFrame.instance.selected_channel.edit_message(editing_message, field.text)
		editing_message = null
	else:
		ChatFrame.instance.selected_channel.send_message(
			field.text,
			MessageEncryptionContextMenu.encryption_key if MessageEncryptionContextMenu.encrypt_message_enabled else ""
		)
	field.set_deferred("text", "")

	ChatFrame.instance.queue_redraw()

func _on_encrypt_button_pressed() -> void:
	var menu: ContextMenu = ContextMenu.create_menu(load("res://interface/components/context_menu/message_encrypt_context_menu.tscn"))

func _on_cancel_edit_button_pressed() -> void:
	editing_message = null
