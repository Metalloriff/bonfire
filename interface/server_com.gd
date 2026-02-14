extends Node

func _ready() -> void:
	var handshake_node := ServerHandshake.new()
	add_child(handshake_node)
	handshake_node.name = "ServerHandshake"