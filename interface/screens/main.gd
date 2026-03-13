class_name App extends Control

static var instance: App
static var selected_server: Server:
	set(new):
		if selected_server != new:
			selected_server = new
			instance.server_selected.emit(selected_server)

			# TODO make this remember the last channel you were on
			if is_instance_valid(new):
				ChatFrame.instance.selected_channel = new.channels[0]
			else:
				ChatFrame.instance.selected_channel = null

			ChannelList.instance.queue_redraw()
			ChatFrame.instance.queue_redraw()

			MemberList.instance.server = selected_server
static var in_app_server: InAppServer

signal server_selected(server: Server)

var selected_server_connection_issue: bool:
	set(new):
		if selected_server_connection_issue != new:
			selected_server_connection_issue = new

			%ConnectionIssueNotice.visible = selected_server_connection_issue

			if not selected_server_connection_issue:
				ChannelList.instance.get_parent().modulate.a = 1.0
				ChatFrame.instance.modulate.a = 1.0
				LocalUserContainer.instance.modulate.a = 1.0
				MemberList.instance.get_parent().modulate.a = 1.0
				MainTextArea.instance.modulate.a = 1.0
			else:
				ChannelList.instance.get_parent().modulate.a = 0.25
				ChatFrame.instance.modulate.a = 0.25
				LocalUserContainer.instance.modulate.a = 0.25
				MemberList.instance.get_parent().modulate.a = 0.25
				MainTextArea.instance.modulate.a = 0.25

@onready var split_container: HSplitContainer = get_node_or_null("%SplitContainer")
var _pn_debouncer: float = -1.0

func _ready() -> void:
	instance = self

	for server_resource_path: String in DirAccess.get_files_at("user://servers"):
		var server: Server = load("user://servers/%s" % server_resource_path)
		ServerComNode.new(server.id)
	
	ModalStack._fade_out_modal(self , 0.0)
	ModalStack._fade_in_modal(self )

	if is_instance_valid(split_container):
		split_container.split_offsets = FS.get_pref("app_split_offsets", split_container.split_offsets)

	Settings.make_setting_link_method("appearance", "background_image", func(path: String) -> void:
		if not path or not FileAccess.file_exists(path):
			$BackgroundImage.texture = null
			return
		
		var image: Image = Image.load_from_file(path)
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		$BackgroundImage.texture = texture
	)
	
	Settings.make_setting_link("appearance", "background_image_opacity", $BackgroundImage, "modulate:a")
	Settings.make_setting_link("appearance", "background_blur_radius", $BackgroundImage, "material:shader_parameter/radius")
	Settings.make_setting_link("appearance", "background_blur_x", $BackgroundImage, "material:shader_parameter/step:x")
	Settings.make_setting_link("appearance", "background_blur_y", $BackgroundImage, "material:shader_parameter/step:y")

	if FS.get_pref("in_app_server_enabled", false):
		_init_in_app_server()
	
	Settings.button_pressed.connect(func(category: String, property_name: String) -> void:
		if category == "system":
			match property_name:
				"clear_cache":
					_clear_all_cache()
				"open_licenses":
					ModalStack.open_modal("res://interface/modals/licenses_modal.tscn")
					Settings.ui.close()
	)

	var cache_cleanup_timer: Timer = Timer.new()
	cache_cleanup_timer.name = "CacheCleanupTimer"
	cache_cleanup_timer.wait_time = 600.0
	cache_cleanup_timer.autostart = true
	cache_cleanup_timer.timeout.connect(_clean_cache)
	add_child(cache_cleanup_timer)

func _process(delta: float) -> void:
	if _pn_debouncer > -1.0:
		_pn_debouncer += delta

		if _pn_debouncer > 2.0:
			_pn_debouncer = -1.0
			_update_push_notification_listener()

func _update_push_notification_listener() -> void:
	if OS.get_name() != "Android":
		return
	
	if not Engine.has_singleton(&"NotificationListener"):
		print("NotificationListener not found")
		return
	
	var addresses: Array[String] = []
	var auth_datas: Array[String] = []

	for server: Server in ServerList.instance.servers:
		if not is_instance_valid(server) or not is_instance_valid(server.com_node) or not server.address:
			continue
		if not is_instance_valid(server.com_node.local_multiplayer) or not server.com_node.local_multiplayer.multiplayer_peer:
			continue
		if not server.com_node.local_multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			continue
		
		var local_auth_data: Dictionary = AuthPortal.get_auth(server.id)
		addresses.append("http://%s:%d" % [server.address, 26970]) # TODO make the server sync their notification port, and use that instead
		auth_datas.append(JSON.stringify(local_auth_data))
	
	var notification_listener = Engine.get_singleton(&"NotificationListener")
	notification_listener.sync_notification_servers(addresses, auth_datas)

func _clear_all_cache() -> void:
	for file in FS.get_files_recursive("user://cache/media", false):
		DirAccess.remove_absolute(file)
	NotificationDaemon.show_toast("Media cache cleared.")

func _clean_cache() -> void:
	var time_days: int = Settings.get_value("system", "cache_lifetime_days")
	
	for file in FS.get_files_recursive("user://cache/media", false):
		var file_time: int = FileAccess.get_modified_time(file)
		var time_difference: float = Time.get_unix_time_from_system() - float(file_time)
		
		if time_difference > time_days * 86400:
			DirAccess.remove_absolute(file)

func _init_in_app_server() -> void:
	in_app_server = InAppServer.new()
	Engine.get_main_loop().root.add_child(in_app_server)

func _on_split_container_drag_ended() -> void:
	FS.set_pref("app_split_offsets", split_container.split_offsets)
