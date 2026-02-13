class_name MemberList extends VBoxContainer

static var instance: MemberList

var server: Server:
	set(new):
		if server != new:
			server = new
			
			queue_redraw()
var user_item: PackedScene = preload("res://interface/components/user/user_item.tscn")

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

	for user in offline_users:
		if user.id in online_users_list_flat:
			online_users.append(user)
			offline_users.erase(user)
	
	if len(online_users):
		_create_divider("Online")
		for user in online_users:
			_create_user_item(user)
	
	if len(offline_users):
		_create_divider("Offline")
		for user in offline_users:
			_create_user_item(user)

func _create_user_item(user: User) -> void:
	var control: Control = user_item.instantiate()
	control.server = server
	control.user = user
	add_child(control)

func _create_divider(role: String) -> void:
	var label: Label = Label.new()
	label.text = " \n%s\n" % role
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set("theme_override_constants/line_spacing", -10)
	add_child(label)
