class_name MessageGroupNode extends MarginContainer

@export var author: User
@export var messages: Array[Message]

@onready var _avatar_node: TextureRect = $Container/Avatar
@onready var _username_node: Label = $Container/Contents/Username
@onready var _messages_container_node: VBoxContainer = $Container/Contents/Messages

var _added_messages: Array[Message] = []

# func _ready() -> void:
# 	modulate.a = 0.0

# 	await Lib.frame

# 	position.x = 200

# 	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
# 	tween.tween_property(self , "position:x", 0.0, 0.5)
# 	tween.tween_property(self , "modulate:a", 1.0, 0.5)

func _draw() -> void:
	_avatar_node.texture = author.avatar
	_username_node.text = author.name

	for message in messages:
		if message in _added_messages:
			continue
		_added_messages.append(message)

		var message_label: RichTextLabel = RichTextLabel.new()
		message_label.text = _process_message_content(message.content)
		message_label.fit_content = true
		message_label.selection_enabled = true
		message_label.bbcode_enabled = true
		message_label.context_menu_enabled = true
		message_label.meta_hover_started.connect(_on_meta_hover_started)
		message_label.meta_hover_ended.connect(_on_meta_hover_ended)
		message_label.meta_clicked.connect(_on_meta_clicked)
		_messages_container_node.add_child(message_label)

func _on_meta_hover_started(meta: Variant) -> void:
	prints("MessageGroupNode", "_on_meta_hover_started", meta)

func _on_meta_hover_ended(meta: Variant) -> void:
	prints("MessageGroupNode", "_on_meta_hover_ended", meta)

func _on_meta_clicked(meta: Variant) -> void:
	if "https://" in meta or "http://" in meta:
		OS.shell_open(meta)
	prints("MessageGroupNode", "_on_meta_clicked", meta)

func _process_message_content(content: String) -> String:
	# replace URLs with clickable links in the form of [url=https://examples.com]examples.com[/url]
	# find and replace URLs with clickable links
	var regex = RegEx.new()
	regex.compile("https?:\\/\\/(?:www\\.)?((?:[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b(?:[-a-zA-Z0-9()@:%_\\+.~#?&\\/=]*)))")
	content = regex.sub(content, "[url=$0]$1[/url]", true)

	return content
