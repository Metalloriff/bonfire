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
@onready var file_attachments: HBoxContainer = get_parent().get_node("FileAttachmentsContainer/FileAttachments")

var attachments: Array[String] = []

func _ready() -> void:
	instance = self

func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ENTER and not event.is_echo() and len(field.text.strip_edges()):
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
				field.text = field.text.strip_edges()
				_on_send_button_pressed()

func _on_send_button_pressed() -> void:
	assert(is_instance_valid(ChatFrame.instance.selected_channel), "No channel selected")

	if len(attachments) < file_attachments.get_child_count():
		NotificationDaemon.show_toast("You must wait for all file uploads to finish before sending a message.")
		return
	
	if not len(attachments) and not field.text.strip_edges():
		if is_instance_valid(editing_message):
			editing_message = null
		return

	if is_instance_valid(editing_message):
		ChatFrame.instance.selected_channel.edit_message(editing_message, field.text)
		editing_message = null
	else:
		ChatFrame.instance.selected_channel.send_message(
			field.text,
			MessageEncryptionContextMenu.encryption_key if MessageEncryptionContextMenu.encrypt_message_enabled else "",
			attachments
		)
	field.set_deferred("text", "")

	attachments.clear()

	for attachment in file_attachments.get_children():
		attachment.queue_free()

	ChatFrame.instance.queue_redraw()

func _on_encrypt_button_pressed() -> void:
	var menu: ContextMenu = ContextMenu.create_menu(load("res://interface/components/context_menu/message_encrypt_context_menu.tscn"))

	menu.global_position = $EncryptButton.global_position - Vector2((menu.get_node("PanelContainer").size.x / 2.0) - ($EncryptButton.size.x / 2.0), menu.get_node("PanelContainer").size.y + 10)

func _on_cancel_edit_button_pressed() -> void:
	editing_message = null

func _on_attach_file_button_pressed() -> void:
	$FileDialog.popup_centered()

func _on_file_dialog_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		var file_size: int = FileAccess.get_size(path)
		if file_size > ChatFrame.instance.selected_channel.server.max_file_upload_size:
			NotificationDaemon.show_toast("File size too large! Max file size for this server is %s." % Lib.bytes_to_readable(ChatFrame.instance.selected_channel.server.max_file_upload_size), NotificationDaemon.NotificationType.Error)
			return

		var file_upload_node: PackedScene = preload("res://interface/components/servers/file_upload_node.tscn")
		var file_upload_node_instance: Control = file_upload_node.instantiate()
		file_upload_node_instance.server = ChatFrame.instance.selected_channel.server
		file_upload_node_instance.channel = ChatFrame.instance.selected_channel
		file_upload_node_instance.file_path = path
		file_attachments.add_child(file_upload_node_instance)
