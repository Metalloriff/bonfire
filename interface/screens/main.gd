extends Control

func _ready() -> void:
	for server_resource_path: String in FS.get_files("user://servers"):
		var server: Server = load("user://servers/%s" % server_resource_path)
		prints("server", server)
		ServerComNode.new(server.address, server.port)

func _on_join_server_pressed() -> void:
	get_tree().current_scene.add_child(load("res://interface/modals/join_server_modal.tscn").instantiate())
