extends Control

func _ready() -> void:
	_update_config_text()

	if is_instance_valid(App.in_app_server) and App.in_app_server.running:
		App.in_app_server.on_std_line.connect(_on_std_line)

func _on_stop_server_button_pressed() -> void:
	if not is_instance_valid(App.in_app_server) or not App.in_app_server.running:
		return

func _on_start_server_button_pressed() -> void:
	if is_instance_valid(App.in_app_server) and App.in_app_server.running:
		return

	FS.set_pref("in_app_server_enabled", true)
	App.instance._init_in_app_server()
	App.in_app_server.on_std_line.connect(_on_std_line)

	await Lib.seconds(1.0)

	_update_config_text()

func _update_config_text() -> void:
	var config_path: String = "user://server_data/config.yml"

	if not FileAccess.file_exists(config_path):
		return
	
	%Config.text = FileAccess.get_file_as_string(config_path)

func _on_std_line(line: String, error: bool) -> void:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if error:
		label.text = "ERROR: %s" % line
		label.modulate = Color.html("#E02B43")
	else:
		label.text = line
	
	%LogItems.add_child(label)

	await Lib.frame

	%LogScroller.scroll_vertical = %LogScroller.get_v_scroll_bar().max_value

func _process(_delta: float) -> void:
	%StopButton.visible = is_instance_valid(App.in_app_server) and App.in_app_server.running
	%StartButton.visible = not %StopButton.visible
