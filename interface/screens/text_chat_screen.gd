class_name TextChatScreen extends ScrollContainer

var channel: Channel
var message_group_scene: PackedScene = preload("res://interface/components/chat/message_group.tscn")
var unread_message_divider: PackedScene = preload("res://interface/components/chat/unread_message_divider.tscn")

@onready var list: VBoxContainer = %List
@onready var no_messages_label: Label = %List/NoMessagesLabel

var _mark_as_read_debounced: Callable = Lib.create_debouncer(0.5, _mark_as_read)
func _mark_as_read() -> void:
	channel.last_read_message_timestamp = channel.messages[-1].timestamp
	channel.unread_count = 0

var _processed_messages: Array[Message] = []

func _ready() -> void:
	get_v_scroll_bar().value_changed.connect(_on_scroll)

	render()

func _on_scroll(value: float) -> void:
	if not is_instance_valid(channel):
		return
	
	if not channel.messages_loaded or channel.messages_loading or not len(channel.messages):
		return
	
	if value <= 0.0 and len(channel.messages) % 50 == 0:
		for child in list.get_children():
			if not child.owner:
				child.queue_free()
		_processed_messages.clear()

		_scroll_target = 2.0

		channel.messages_loaded = false
		channel.load_messages(channel.messages[0].timestamp)

func render() -> void:
	if not is_instance_valid(channel):
		print("Invalid channel for text chat screen")
		return
	
	%EncryptionNotice.visible = channel.is_private
	
	if not channel.messages_loaded:
		channel.load_messages()
	
	var existing_unread_div: HBoxContainer = list.get_node_or_null("UnreadDivider")
	if existing_unread_div and Time.get_ticks_msec() - existing_unread_div.get_meta("spawned_at") > 1000:
		existing_unread_div.free()
	
	var message_group: MessageGroupNode = list.get_child(-1) if list.get_child_count() > 2 else null
	var last_message: Message = message_group.messages[-1] if message_group else null
	var new_message_count: int = 0
	var unread_count: int = channel.unread_count

	no_messages_label.visible = not channel.messages.size()

	if is_instance_valid(message_group):
		message_group.queue_redraw.call_deferred()
	
	if len(channel.messages):
		_mark_as_read_debounced.call()

	var reverse_index: int = len(channel.messages)
	for message in channel.messages:
		if unread_count > 0 and reverse_index == unread_count:
			var unread_div = unread_message_divider.instantiate()
			unread_div.get_node("Label").text = "%d new messages" % unread_count
			list.add_child(unread_div)
			unread_div.name = "UnreadDivider"
			unread_div.set_meta("spawned_at", Time.get_ticks_msec())
			message_group = null
		
		reverse_index -= 1

		if message in _processed_messages:
			continue
		
		_processed_messages.append(message)
		new_message_count += 1
		
		if not last_message or message.author_id != last_message.author_id or not is_instance_valid(message_group):
			message_group = message_group_scene.instantiate()
			message_group.author = channel.server.get_user(message.author_id)
			message_group.channel = channel
			list.add_child(message_group)
		message_group.messages.append(message)

		last_message = message
	
	if new_message_count > 0:
		_update_scrollbar.call_deferred()

var _scroll_target: float
func _update_scrollbar() -> void:
	# create_tween().tween_property(get_v_scroll_bar(), "value", _scroll_target if _scroll_target > 0.0 else get_v_scroll_bar().max_value, 0.2)
	await Lib.frame
	get_v_scroll_bar().set_deferred("value", _scroll_target if _scroll_target > 0.0 else get_v_scroll_bar().max_value * 20.0)
	_scroll_target = 0.0
