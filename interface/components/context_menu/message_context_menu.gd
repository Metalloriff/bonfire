extends ContextMenu

var message: Message
var message_item: Control

var _selected_text: String

func _ready() -> void:
	hide()

	await Lib.frame

	if not is_instance_valid(message):
		queue_free()
		return

	# var msg_prev: VBoxContainer = load("res://interface/components/chat/message_item.tscn").instantiate()
	# msg_prev.author = ChatFrame.instance.selected_channel.server.get_user(message.author_id)
	# msg_prev.message = message
	# msg_prev.is_reply = false
	# %MessagePreviewContainer/MarginContainer.add_child(msg_prev)

	# await Lib.frame

	# %MessagePreviewContainer.global_position = global_position
	# %MessagePreviewContainer.global_position.x += $PanelContainer.size.x
	# $MessagePreviewContainer.size.y = 0

	for child in message_item.get_node("TextContents").get_children():
		if child is RichTextLabel and child.get_selected_text():
			_selected_text = child.get_selected_text()
			break
	
	%QuoteReplyButton.visible = len(_selected_text.strip_edges()) > 0
	%OwnMessageContainer.visible = message.author_id == ChatFrame.instance.selected_channel.server.user_id

	show()

func _on_reply_button_pressed() -> void:
	MainTextArea.instance.field.text += "[reply message_id=\"%s\"][/reply]\n\n" % message.timestamp
	MainTextArea.instance.field.grab_focus.call_deferred()
	MainTextArea.instance.field.set_caret_line(MainTextArea.instance.field.get_line_count() - 1)
	queue_free()

func _on_quote_reply_button_pressed() -> void:
	MainTextArea.instance.field.text += "[reply message_id=\"%s\"]%s[/reply]\n\n" % [message.timestamp, _selected_text]
	MainTextArea.instance.field.grab_focus.call_deferred()
	MainTextArea.instance.field.set_caret_line(MainTextArea.instance.field.get_line_count() - 1)
	queue_free()

func _on_delete_button_pressed() -> void:
	# TODO ask for confirmation
	ChatFrame.instance.selected_channel.delete_message(message)
	queue_free()

func _on_edit_button_pressed() -> void:
	pass # Replace with function body.
