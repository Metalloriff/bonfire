class_name MobileControlsContainer extends Control

static var instance: MobileControlsContainer

const TRANSITION_TIME: float = 0.22
const PX_THRESHOLD: float = 100.0
const VELOCITY_THRESHOLD: float = 2000.0

var _start_drag: Vector2
var _velocity: Vector2
var _main_focused: bool

func _ready() -> void:
	instance = self

	await Lib.seconds(1.0)

	fade_to_channel_list()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_start_drag += event.relative
		if absf(_start_drag.x) < 10.0 or absf(_start_drag.y) > absf(_start_drag.x):
			return
		
		_velocity = event.screen_velocity

		$MobileChatContainer.global_position.x += event.relative.x

		if $MobileChatContainer.global_position.x > 0:
			$MobileChannelList.show()
			$MobileMemberList.hide()
		else:
			$MobileChannelList.hide()
			$MobileMemberList.show()
	elif event is InputEventScreenTouch:
		_start_drag = Vector2.ZERO

		if not event.pressed:
			# This is spaghetti, but I am not a mobile developer and it works
			if _main_focused:
				if absf($MobileChatContainer.global_position.x) < PX_THRESHOLD:
					fade_to_chat()
				else:
					if $MobileChatContainer.global_position.x > 0:
						fade_to_channel_list()
					else:
						fade_to_member_list()
			else:
				var width: float = get_viewport().size.x / Engine.get_main_loop().root.content_scale_factor

				# print(absf(_velocity.x))

				if absf($MobileChatContainer.global_position.x) < width - PX_THRESHOLD:
					fade_to_chat()
				else:
					if $MobileChatContainer.global_position.x > 0:
						fade_to_channel_list()
					else:
						fade_to_member_list()

func fade_to_chat() -> void:
	create_tween().set_trans(Tween.TRANS_BOUNCE).tween_property($MobileChatContainer, "global_position:x", 0.0, TRANSITION_TIME)
	_main_focused = true

func fade_to_channel_list() -> void:
	var width: float = get_viewport().size.x / Engine.get_main_loop().root.content_scale_factor
	create_tween().set_trans(Tween.TRANS_BOUNCE).tween_property($MobileChatContainer, "global_position:x", width, TRANSITION_TIME)
	_main_focused = false

func fade_to_member_list() -> void:
	var width: float = get_viewport().size.x / Engine.get_main_loop().root.content_scale_factor
	create_tween().set_trans(Tween.TRANS_BOUNCE).tween_property($MobileChatContainer, "global_position:x", -width, TRANSITION_TIME)
	_main_focused = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = true
		get_viewport().push_input(event)
