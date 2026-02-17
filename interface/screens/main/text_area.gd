class_name MainTextArea extends HBoxContainer

static var instance: MainTextArea

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

	ChatFrame.instance.selected_channel.send_message(field.text)
	field.set_deferred("text", "")

	ChatFrame.instance.queue_redraw()
