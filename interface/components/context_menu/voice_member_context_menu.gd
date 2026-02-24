extends ContextMenu

var user: User

func _ready() -> void:
	await Lib.frame
	
	%BoostVolume.button_pressed = user.local_volume > 100.0
	%VolumeSlider.max_value = 300.0 if %BoostVolume.button_pressed else 100.0
	%VolumeSlider.value = user.local_volume
	%Username.text = user.username

func _on_volume_slider_value_changed(value: float) -> void:
	user.local_volume = value

func _on_boost_volume_toggled(toggled_on: bool) -> void:
	%VolumeSlider.max_value = 300.0 if toggled_on else 100.0

func _on_soundboard_volume_slider_value_changed(value: float) -> void:
	user.local_soundboard_volume = value

func _on_more_options_button_pressed() -> void:
	var user_context_menu: ContextMenu = ContextMenu.create_menu(preload("res://interface/components/context_menu/user_context_menu.tscn"))
	user_context_menu.user = user
	user_context_menu.server = App.instance.selected_server
	fade_free()

	await Lib.frame

	user_context_menu.global_position = get_global_mouse_position()
