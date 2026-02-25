class_name MessageGroupNode extends MarginContainer

@export var author: User
@export var messages: Array[Message]
@export var channel: Channel

@onready var _avatar_node: TextureRect = $Container/AvatarContainer/Avatar
@onready var _avatar_placeholder_node: ColorRect = $Container/AvatarContainer/PlaceholderAvatar
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

func _ready() -> void:
	if not author:
		author = User.new()
		author.name = "Unknown User"
		return

	for node in [_avatar_node, _avatar_placeholder_node, _username_node]:
		ContextMenu.attach_listener(node, preload("res://interface/components/context_menu/user_context_menu.tscn"), func(menu: ContextMenu) -> void:
			menu.user = author
			menu.server = channel.server
		)

func _draw() -> void:
	_avatar_node.texture = author.avatar
	_username_node.text = author.name

	if not author.avatar:
		_avatar_placeholder_node.show()
		_avatar_placeholder_node.get_child(0).text = author.name[0].to_upper() + author.name[-1].to_upper()

	for message in messages:
		if message in _added_messages:
			continue
		_added_messages.append(message)

		var message_item: VBoxContainer = preload("res://interface/components/chat/message_item.tscn").instantiate()
		message_item.author = author
		message_item.message = message
		message_item.channel = channel
		_messages_container_node.add_child(message_item)

func delete() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self , "modulate:a", 0.0, 0.5)
	await tween.finished

	queue_free()
