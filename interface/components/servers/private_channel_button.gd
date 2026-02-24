extends Button

var channel: Channel

var other_user: User

func _ready() -> void:
	ContextMenu.attach_listener(self , preload("res://interface/components/context_menu/private_channel_context_menu.tscn"), func(menu: ContextMenu) -> void:
		menu.channel = channel
	)

	for participant in channel.pm_participants:
		if participant.user_id != channel.server.user_id:
			other_user = channel.server.get_user(participant.user_id)
			break

func _draw() -> void:
	%Username.text = channel.name

	if is_instance_valid(other_user) and other_user.avatar is ImageTexture:
		%Avatar.texture = other_user.avatar

func _on_pressed() -> void:
	ChatFrame.instance.selected_channel = channel
