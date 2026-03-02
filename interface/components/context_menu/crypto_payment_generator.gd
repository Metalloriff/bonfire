extends ContextMenu

@onready var rect: QRCodeRect = %QRCodeRect

var message: String
var amount: float
var currency: String
var address: String

var file_name: String

func _on_attach_button_pressed() -> void:
	ModalStack.fade_free_modal(self )

	if not rect.data.is_empty() and file_name:
		file_name = "user://cache/%s.png" % file_name
		rect.texture.get_image().save_png(file_name)
		MainTextArea.instance._on_file_dialog_files_selected([file_name])

		await Lib.seconds(10.0)

		DirAccess.remove_absolute(file_name)

func _on_message_text_changed(new_text: String) -> void:
	message = new_text
	_regenerate_qr_code()

func _on_amount_text_changed(new_text: String) -> void:
	amount = new_text.to_float()
	_regenerate_qr_code()

func _on_currency_text_changed(new_text: String) -> void:
	currency = new_text.to_lower()
	_regenerate_qr_code()

func _on_address_text_changed(new_text: String) -> void:
	address = new_text
	_regenerate_qr_code()

func _regenerate_qr_code() -> void:
	var string: String = address

	if currency.strip_edges():
		string = "%s:%s" % [currency, string]
	
	if message.strip_edges():
		message = message.uri_encode()
	
	var has_inserted_question_mark: bool = false
	for type in ["amount", "message"]:
		if self [type] and str(self [type]).strip_edges():
			if not has_inserted_question_mark:
				string += "?"
				has_inserted_question_mark = true
			else:
				string += "&"
			
			string += "%s=%s" % [type, self [type]]
	
	rect.data = string.to_utf8_buffer()
	rect._update_qr()
	
	var fn: String = "Crypto Payment Request - %s %s" % [
		str(amount) if amount else "any",
		currency if currency.strip_edges() else ""
	]

	fn = fn.strip_edges().strip_escapes().validate_filename()
	file_name = fn
