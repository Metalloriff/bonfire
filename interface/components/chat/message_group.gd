class_name MessageGroupNode extends MarginContainer

@export var author: User
@export var messages: Array[Message]

@onready var _avatar_node: TextureRect = $Container/Avatar
@onready var _username_node: Label = $Container/Contents/Username
@onready var _messages_container_node: VBoxContainer = $Container/Contents/Messages

var _added_messages: Array[Message] = []

func _draw() -> void:
	_avatar_node.texture = author.avatar
	_username_node.text = author.name

	for message in messages:
		if message in _added_messages:
			continue
		_added_messages.append(message)
		
		var message_label: Label = Label.new()
		message_label.text = message.content
		_messages_container_node.add_child(message_label)
