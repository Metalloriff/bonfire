class_name LocalUserContainer extends PanelContainer

static var instance: LocalUserContainer

var server: Server

@onready var avatar: TextureRect = $MarginContainer/HBoxContainer/AvatarContainer/Avatar
@onready var username: Label = $MarginContainer/HBoxContainer/Username

func _ready() -> void:
	instance = self

func _process(_delta: float) -> void:
	visible = is_instance_valid(App.instance.selected_server)

	if server != App.instance.selected_server:
		server = App.instance.selected_server
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(server):
		return
	
	var local_user: User = server.local_user
	if not is_instance_valid(local_user):
		return

	if is_instance_valid(local_user.avatar):
		avatar.texture = local_user.avatar
	username.text = local_user.username

func _on_settings_button_pressed() -> void:
	Settings.ui.open()

func _on_profile_button_pressed() -> void:
	var modal: Control = ModalStack.open_modal("res://interface/modals/user_profile_modal.tscn")
	modal.user = server.local_user
