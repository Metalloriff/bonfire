extends VBoxContainer

var channel: Channel = Channel.new()

@onready var _button: Button = $Button

func _ready() -> void:
	ChatFrame.instance.channel_selected.connect(func(selected: Channel) -> void:
		_button.theme_type_variation = "Button_Translucent_Important" if selected == channel else "Button_Translucent"
	)

	ContextMenu.attach_listener(_button, preload("res://interface/components/context_menu/channel_context_menu.tscn"), func(menu: ContextMenu) -> void:
		menu.channel = channel
	)

	channel.unread_count_updated.connect(func() -> void:
		var unread_count: int = channel.unread_count
		%UnreadContainer.visible = unread_count > 0
		%UnreadCount.text = str(unread_count) if unread_count < 100 else "99+"
	)

	var unread_count: int = await channel.get_unread_count()
	%UnreadContainer.visible = unread_count > 0
	%UnreadCount.text = str(unread_count) if unread_count < 100 else "99+"

func _draw() -> void:
	_button.theme_type_variation = "Button_Translucent_Important" if ChatFrame.instance.selected_channel == channel else "Button_Translucent"
	
	match channel.type:
		Channel.Type.TEXT:
			_button.icon = preload("res://icons/chat.png")
		Channel.Type.VOICE:
			var user_item: PackedScene = preload("res://interface/components/user/user_item.tscn")
			_button.icon = preload("res://icons/call.png")

			if not is_instance_valid(channel.server.com_node):
				prints("server com node not valid")
				return

			%OpenTextChatButton.show()

			$VoiceMembers.show()
			$VoiceMembers.title = "Participants (%d)" % (len(channel.server.voice_chat_participants[channel.id]) if channel.id in channel.server.voice_chat_participants else 0)
			if VoiceChat.active_channel == channel:
				$VoiceMembers.folded = false

			var list: VBoxContainer = $VoiceMembers/List
			for child in list.get_children():
				child.free()
				
			if channel.id in channel.server.voice_chat_participants:
				for user_id in channel.server.voice_chat_participants[channel.id]:
					var user: User = channel.server.get_user_by_peer_id(user_id)
					if not is_instance_valid(user):
						print("user %s not found" % user_id)
						continue
					
					var control: Control = user_item.instantiate()
					control.server = channel.server
					control.user = user
					list.add_child(control)
		Channel.Type.MEDIA:
			_button.icon = preload("res://icons/photoSizeSelectActual.png")
	
	_button.text = channel.name

func _on_pressed() -> void:
	if channel.type == Channel.Type.VOICE and ChatFrame.instance.selected_channel == channel:
		ChatFrame.instance.selected_channel = null
		await Lib.frame
		await Lib.frame
	ChatFrame.instance.selected_channel = channel

func _on_open_text_chat_button_pressed() -> void:
	ChatFrame.instance.force_text = true
	_on_pressed()
