extends PanelContainer

var NOT_SPEAKING_COLOR: Color = Color.html("#2b8fe0")
var SPEAKING_COLOR: Color = Color.html("#e02b6a")

var user: User:
	set(new):
		if user != new:
			user = new
			
			queue_redraw()
var server: Server

@onready var status_indicator: PanelContainer = %StatusIndicator

func _ready() -> void:
	for node in [ self , %Tagline]:
		ContextMenu.attach_listener(node, load("res://interface/components/context_menu/user_context_menu.tscn"), func(menu: ContextMenu) -> void:
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

func _process(delta: float) -> void:
	if not status_indicator.visible:
		return

	var voice_volume: float = 0.0

	if VoiceChat.active_channel:
		var peer_id: int = server.get_peer_id_by_user_id(user.id)
		if peer_id in VoiceChat.users:
			voice_volume = VoiceChat.users[peer_id].get_meta("speaking_activity_level")
		elif user.id == server.user_id:
			voice_volume = VoiceChat.local_speaking_activity_level

	status_indicator.self_modulate = NOT_SPEAKING_COLOR.lerp(SPEAKING_COLOR, clampf(voice_volume, 0.0, 1.0))
