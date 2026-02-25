extends PanelContainer

var user: User:
	set(new):
		if user != new:
			user = new
			
			queue_redraw()
var server: Server

func _ready() -> void:
	ContextMenu.attach_listener(self , load("res://interface/components/context_menu/user_context_menu.tscn"), func(menu: ContextMenu) -> void:
		menu.user = user
		menu.server = server
	)

func _draw() -> void:
	%Username.text = user.username
	%StatusIndicator.visible = is_instance_valid(server) and user.id in server.online_users.values()
	%Avatar.texture = user.avatar

	%Tagline.visible = len(user.tagline.strip_edges()) > 0
	%Tagline.text = user.tagline
	%Tagline.tooltip_text = user.tagline

	if not user.avatar:
		%PlaceholderAvatar.show()
		%PlaceholderAvatar.get_child(0).text = user.username[0].to_upper() + user.username[-1].to_upper()

	tooltip_text = user.id
