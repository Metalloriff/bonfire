class_name MessageGroupNode extends HBoxContainer

@export var author: User
@export var messages: Array[Message]

@onready var _avatar_node: TextureRect = $Avatar
@onready var _username_node: Label = $Contents/Username
@onready var _messages_container_node: VBoxContainer = $Contents/Messages

func _ready() -> void:
	_avatar_node.texture = author.avatar
	_username_node.text = author.name

	for message in messages:
		print(message.content)