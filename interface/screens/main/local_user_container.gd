class_name LocalUserContainer extends PanelContainer

var NOT_SPEAKING_COLOR: Color = Color.html("#2b8fe0")
var SPEAKING_COLOR: Color = Color.html("#e02b6a")

static var instance: LocalUserContainer

var server: Server
var local_user: User

@onready var avatar: TextureRect = $MarginContainer/HBoxContainer/AvatarContainer/Avatar
@onready var username: Label = $MarginContainer/HBoxContainer/Username
@onready var status_indicator: PanelContainer = %StatusIndicator

func _ready() -> void:
	instance = self

	while not is_instance_valid(App.instance):
		await Lib.frame

	App.instance.server_selected.connect(func(selected_server: Server) -> void:
		server = selected_server
		queue_redraw()
	)

func _draw() -> void:
	if not is_instance_valid(server):
		local_user = User.new()
		local_user.name = FS.get_pref("auth.username", "Unknown User")
		var local_user_path: String = "user://local_user_profiles/%s.res" % local_user.profile_id

		if ResourceLoader.exists(local_user_path):
			local_user = load(local_user_path)
	else:
		local_user = server.local_user
	
	if not is_instance_valid(local_user):
		return

	if is_instance_valid(local_user.avatar):
		avatar.texture = local_user.avatar
	username.text = local_user.username

func _process(delta: float) -> void:
	if not is_instance_valid(VoiceChat.active_channel):
		status_indicator.self_modulate = NOT_SPEAKING_COLOR
		return
	
	status_indicator.self_modulate = NOT_SPEAKING_COLOR.lerp(SPEAKING_COLOR, clampf(VoiceChat.local_speaking_activity_level, 0.0, 1.0))

func _on_settings_button_pressed() -> void:
	Settings.ui.open()

func _on_profile_button_pressed() -> void:
	var modal: Control = ModalStack.open_modal("res://interface/modals/user_profile_modal.tscn")
	modal.user = server.local_user if is_instance_valid(server) else local_user
