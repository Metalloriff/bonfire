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

func _ready() -> void:
	instance = self

	for server_resource_path: String in DirAccess.get_files_at("user://servers"):
		var server: Server = load("user://servers/%s" % server_resource_path)
		ServerComNode.new(server.id)
	
	ModalStack._fade_out_modal(self , 0.0)
	ModalStack._fade_in_modal(self )
