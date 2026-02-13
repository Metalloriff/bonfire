extends VBoxContainer

var channel: Channel = Channel.new()

@onready var _button: Button = $Button

func _draw() -> void:
	match channel.type:
		Channel.Type.TEXT:
			_button.icon = preload("res://icons/chat.png")
		Channel.Type.VOICE:
			_button.icon = preload("res://icons/call.png")

			$VoiceMembers.show()
			$VoiceMembers.title = "Participants (%d)" % (len(channel.server.com_node.voice_chat_participants[channel.id]) if channel.id in channel.server.com_node.voice_chat_participants else 0)

			var list: VBoxContainer = $VoiceMembers/List
			for child in list.get_children():
				child.free()
				
			if channel.id in channel.server.com_node.voice_chat_participants:
				for user_id in channel.server.com_node.voice_chat_participants[channel.id]:
					var user: User = channel.server.get_user_by_peer_id(user_id)
					if not is_instance_valid(user):
						print("user %s not found" % user_id)
						continue
					
					var label: Label = Label.new()
					label.text = user.name
					list.add_child(label)
		Channel.Type.MEDIA:
			_button.icon = preload("res://icons/photoSizeSelectActual.png")
	
	_button.text = channel.name

func _on_pressed() -> void:
	prints("pressed", channel.name, channel.id)
	ChatFrame.instance.selected_channel = channel
