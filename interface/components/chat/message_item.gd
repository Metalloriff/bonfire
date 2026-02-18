extends VBoxContainer

var author: User
var message: Message
var is_reply: bool

var text_content: String:
	set(new):
		if new == text_content:
			return
		text_content = new

		for child in $TextContents.get_children():
			child.free()
		
		var reply_pattern: String = '\\[reply\\s+message_id="([^"]+)"\\](.*?)\\[/reply\\]'
		var reply_regex: RegEx = RegEx.new()
		reply_regex.compile(reply_pattern)

		var result: Array = []
		var last_end: int = 0

		for match: RegExMatch in reply_regex.search_all(new):
			if match.get_start() > last_end:
				var before: String = new.substr(last_end, match.get_start() - last_end)
				result.append(before)
			
			var reply: Dictionary = {
				node_type = "reply",
				message_id = match.get_string(1),
				reply_content = match.get_string(2)
			}
			result.append(reply)
			last_end = match.get_end()
		
		if last_end < len(new):
			result.append(new.substr(last_end))
		
		if not len(result):
			result = [new]
		
		for sub in result:
			if sub is String:
				_create_rich_label(sub)
			elif sub is Dictionary:
				match sub.node_type:
					"reply":
						if is_reply:
							_create_rich_label("<message reply>")
						else:
							var reply: PanelContainer = preload("res://interface/components/chat/reply_item.tscn").instantiate()
							var reply_message: Message = ChatFrame.instance.selected_channel.find_message(int(sub.message_id))
							var reply_user: User = ChatFrame.instance.selected_channel.server.get_user(reply_message.author_id) if is_instance_valid(reply_message) else null

							if is_instance_valid(reply_user) and is_instance_valid(reply_user.avatar):
								reply.get_node("%Avatar").texture = reply_user.avatar

							if sub.reply_content:
								reply.get_node("%Content").text = sub.reply_content
							elif is_instance_valid(reply_message):
								var message_item: VBoxContainer = preload("res://interface/components/chat/message_item.tscn").instantiate()
								message_item.author = ChatFrame.instance.selected_channel.server.get_user(message.author_id)
								message_item.message = reply_message
								message_item.is_reply = true
								reply.get_node("%Content/..").add_child(message_item)
								reply.get_node("%Content").queue_free()
								# reply.get_node("%Content").text = _process_message_content(message.content)
							else:
								reply.get_node("%Content").text = "Message not found"

							reply.gui_input.connect(gui_input.get_connections()[0].callable)
							$TextContents.add_child(reply)

func _create_rich_label(text: String) -> void:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.selection_enabled = true
	label.text = text
	label.gui_input.connect(gui_input.get_connections()[0].callable)
	$TextContents.add_child(label)

func _ready() -> void:
	ContextMenu.attach_listener(self , preload("res://interface/components/context_menu/message_context_menu.tscn"), func(menu: ContextMenu) -> void:
		menu.message = message
		menu.message_item = self
	)

	if message.encrypted:
		$TextContents.hide()
		$Encryption.show()

		var decrypt_button: Button = $Encryption/Encrypted/Button
		var password_field: LineEdit = $Encryption/Encrypted/Password

		password_field.text_submitted.connect(func(_t: String) -> void:
			decrypt_button.pressed.emit()
		)

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

				$TextContents.show()
				text_content = "🔓 " + _process_message_content(decrypted_content)
				$TextContents.modulate.a = 0.75
		)

		$Encryption/Decrypted/Button.pressed.connect(func() -> void:
			$Encryption/Decrypted.hide()
			$Encryption/Encrypted.show()

			$TextContents.hide()
		)
	else:
		text_content = _process_message_content(message.content)

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

func delete() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self , "modulate:a", 0.0, 0.5)
	await tween.finished

	queue_free()
