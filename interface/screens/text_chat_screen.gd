class_name TextChatScreen extends ScrollContainer

var channel: Channel
var message_group_scene: PackedScene = preload("res://interface/components/chat/message_group.tscn")

@onready var list: VBoxContainer = $List
@onready var no_messages_label: Label = $List/NoMessagesLabel

var _processed_messages: Array[Message] = []

func _draw() -> void:
	if not is_instance_valid(channel):
		print("Invalid channel for text chat screen")
		return
	
	if not channel.messages_loaded:
		channel.load_messages()
	
	var message_group: MessageGroupNode = list.get_child(-1) if list.get_child_count() > 1 else null
	var last_message: Message = message_group.messages[-1] if message_group else null
	var new_message_count: int = 0

	no_messages_label.visible = not channel.messages.size()

	if is_instance_valid(message_group):
		message_group.queue_redraw.call_deferred()

	for message in channel.messages:
		if message in _processed_messages:
			continue
		
		_processed_messages.append(message)
		new_message_count += 1
		
		if not last_message or message.author_id != last_message.author_id:
			message_group = message_group_scene.instantiate()
			message_group.author = channel.server.get_user(message.author_id)
			list.add_child(message_group)
		message_group.messages.append(message)

		last_message = message
	
	if new_message_count > 0:
		await Lib.frame
		scroll_vertical = -999999999999999
