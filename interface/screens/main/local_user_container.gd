class_name LocalUserContainer extends PanelContainer

func _process(_delta: float) -> void:
	visible = is_instance_valid(App.instance.selected_server)

func _on_settings_button_pressed() -> void:
	Settings.ui.open()
