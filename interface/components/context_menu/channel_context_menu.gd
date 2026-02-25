extends ContextMenu

var channel: Channel

func _ready() -> void:
	await Lib.frame

	var server: Server = channel.server
	if not is_instance_valid(server):
		return

	%EditButton.visible = server.local_user.has_permission(server, Permissions.CHANNEL_MANAGE)
	%PurgeButton.visible = server.local_user.has_permission(server, Permissions.MESSAGE_PURGE)
