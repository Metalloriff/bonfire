class_name MemberList extends VBoxContainer

static var instance: MemberList

var server: Server:
	set(new):
		if server != new:
			server = new
			
			queue_redraw()
var user_item: PackedScene = preload("res://interface/components/user/user_item.tscn")

var _pm_participants: Array:
	get:
		if ChatFrame.instance.selected_channel and ChatFrame.instance.selected_channel.is_private:
			return ChatFrame.instance.selected_channel.pm_participants.map(func(p: Dictionary) -> String: return p.user_id)
		return []

func _ready() -> void:
	instance = self

func _draw() -> void:
	for child in get_children():
		child.free()
	
	if not is_instance_valid(server):
		return
	
	var online_users: Array[User] = []
	var offline_users: Array[User] = server.users.duplicate()
	var online_users_list_flat: Array[String] = server.online_users.values()
	var pm_participants: Array = _pm_participants

	for user in offline_users:
		if user.id in online_users_list_flat:
			online_users.append(user)
	
	for user in online_users:
		offline_users.erase(user)
	
	if len(online_users):
		_create_divider("Online")
		for user in online_users:
			if not pm_participants or user.id in pm_participants:
				_create_user_item(user)
	
	if len(offline_users):
		_create_divider("Offline")
		for user in offline_users:
			if not pm_participants or user.id in pm_participants:
				_create_user_item(user).modulate.a = 0.4

func _create_user_item(user: User) -> Control:
	var control: Control = user_item.instantiate()
	control.server = server
	control.user = user
	add_child(control)

	return control

func _create_divider(role: String) -> void:
	var label: Label = Label.new()
	label.text = " \n%s\n" % role
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set("theme_override_constants/line_spacing", -10)
	add_child(label)
