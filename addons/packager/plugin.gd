@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin = load("res://addons/packager/export_plugin.gd").new()

func _enter_tree() -> void:
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
