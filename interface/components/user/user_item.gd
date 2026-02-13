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
