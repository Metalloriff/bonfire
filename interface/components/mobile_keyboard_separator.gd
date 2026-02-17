extends Control

func _ready() -> void:
	if OS.has_feature("android"):
		show()
	else:
		queue_free()

func _process(_delta: float) -> void:
	var new_size_y: float = DisplayServer.virtual_keyboard_get_height() / Engine.get_main_loop().root.content_scale_factor
	var difference: float = new_size_y - custom_minimum_size.y

	if not is_equal_approx(difference, 0.0): # TODO fix this to not force you to scroll to the bottom if you aren't already
		for text_chat_screen: TextChatScreen in Engine.get_main_loop().get_nodes_in_group("text_chat_screen"):
			if text_chat_screen.scroll_vertical - text_chat_screen.get_v_scroll_bar().max_value < difference * 1.01:
				text_chat_screen._update_scrollbar.call_deferred()

	custom_minimum_size.y = new_size_y