class_name App extends Control

static var instance: App
static var selected_server: Server:
	set(new):
		if selected_server != new:
			selected_server = new
			instance.server_selected.emit(selected_server)

			# TODO make this remember the last channel you were on
			ChatFrame.instance.selected_channel = new.channels[0]

			ChannelList.instance.queue_redraw()
			ChatFrame.instance.queue_redraw()

			MemberList.instance.server = selected_server

signal server_selected(server: Server)

func _ready() -> void:
	instance = self

	for server_resource_path: String in DirAccess.get_files_at("user://servers"):
		var server: Server = load("user://servers/%s" % server_resource_path)
		ServerComNode.new(server.id)
	
	ModalStack._fade_out_modal(self , 0.0)
	ModalStack._fade_in_modal(self )
