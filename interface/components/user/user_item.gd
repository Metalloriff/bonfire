extends PanelContainer

var user: User:
	set(new):
		if user != new:
			user = new
			
			queue_redraw()
var server: Server

func _ready() -> void:
	ContextMenu.attach_listener(self , preload("res://interface/components/context_menu/user_context_menu.tscn"), func(menu: ContextMenu) -> void:
		menu.user = user
		menu.server = server
	)

func _draw() -> void:
	%Username.text = user.name
	%StatusIndicator.visible = is_instance_valid(server) and user.id in server.online_users.values()
	%Avatar.texture = user.avatar

	if not user.avatar:
		%PlaceholderAvatar.show()
		%PlaceholderAvatar.get_child(0).text = user.name[0].to_upper() + user.name[-1].to_upper()

	tooltip_text = user.id
