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

func _init_in_app_server() -> void:
	in_app_server = InAppServer.new()
	Engine.get_main_loop().root.add_child(in_app_server)

func _on_split_container_drag_ended() -> void:
	FS.set_pref("app_split_offsets", split_container.split_offsets)
