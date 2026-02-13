class_name App extends Control

static var instance: App
static var selected_server: Server:
	set(new):
		if selected_server != new:
			selected_server = new
			instance.server_selected.emit(selected_server)

signal server_selected(server: Server)

func _ready() -> void:
	instance = self

	for server_resource_path: String in FS.get_files("user://servers"):
		var server: Server = load("user://servers/%s" % server_resource_path)
		ServerComNode.new(server.address, server.port)

func _on_join_server_pressed() -> void:
	get_tree().current_scene.add_child(load("res://interface/modals/join_server_modal.tscn").instantiate())
