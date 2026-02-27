extends Control

func _ready() -> void:
	_update_config_text()

	if is_instance_valid(App.in_app_server) and App.in_app_server.running:
		for history_entry in App.in_app_server.history:
			_on_std_line.call_deferred(history_entry[0], history_entry[1])

		App.in_app_server.on_std_line.connect(_on_std_line)
	else:
		_on_std_line.call_deferred("[INFO] Server is not running.", false)

func _on_stop_server_button_pressed() -> void:
	if not is_instance_valid(App.in_app_server) or not App.in_app_server.running:
		return
	
	_on_console_line_text_submitted("stop")

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

var commands: Dictionary = {
	help = {
		log = "[INFO] Not yet added."
	},
	stop = {
		log = "[INFO] Stopping server...",
		ipc = {
			type = "stop_server"
		}
	}
}

func _on_console_line_text_submitted(new_text: String) -> void:
	if not is_instance_valid(App.in_app_server) or not App.in_app_server.running:
		_on_std_line.call_deferred("[INFO] Server is not running!", true)
		return

	var split: PackedStringArray = new_text.split(" ")
	var command: String = split[0]
	var args: PackedStringArray = split.slice(1)
	
	if command in commands:
		var command_data: Dictionary = commands[command]
		
		if "log" in command_data:
			_on_std_line.call_deferred(command_data.log, false)
		
		if "ipc" in command_data:
			var ipc_data: Dictionary = command_data.ipc
			ipc_data.pk = App.in_app_server.ipc_private_key
			Server.get_server(App.in_app_server.server_id).send_api_message("ipc_msg", ipc_data)
	else:
		_on_std_line.call_deferred("[INFO] Unknown command '%s'" % command, true)
	
	%ConsoleLine.text = ""
	%ConsoleLine.release_focus()
	await Lib.frame
	%ConsoleLine.grab_focus()

func _on_save_config_pressed() -> void:
	var file: FileAccess = FileAccess.open("user://server_data/config.yml", FileAccess.WRITE)
	file.store_string(%Config.text)
	file.close()
	
	_on_std_line.call_deferred("[INFO] Config saved.", false)
