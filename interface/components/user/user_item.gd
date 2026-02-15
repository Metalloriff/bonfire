extends PanelContainer

var user: User:
	set(new):
		if user != new:
			user = new
			
			queue_redraw()
var server: Server

func _draw() -> void:
	%Username.text = user.name
	%StatusIndicator.visible = is_instance_valid(server) and user.id in server.online_users.values()
	%Avatar.texture = user.avatar if is_instance_valid(user.avatar) else %Avatar.texture

	tooltip_text = user.id
