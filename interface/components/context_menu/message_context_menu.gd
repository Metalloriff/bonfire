extends ContextMenu

var message: Message
var message_item: Control

var _selected_text: String

func _ready() -> void:
	await Lib.frame

	for child in message_item.get_node("TextContents").get_children():
		if child is RichTextLabel and child.get_selected_text():
			_selected_text = child.get_selected_text()
			break
	
	%QuoteReplyButton.visible = len(_selected_text.strip_edges()) > 0

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
