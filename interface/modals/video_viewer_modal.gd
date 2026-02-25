extends Control

var stream: Variant
var raw: PackedByteArray
var file_name: String

func _ready() -> void:
	await Lib.frame

	if not is_instance_valid(stream):
		queue_free()
		return
	
	%VideoPlayer.stream = stream

func _on_save_button_pressed() -> void:
	var fd: FileDialog = $FileDialog
	fd.current_file = file_name
	fd.popup()

func _on_file_dialog_file_selected(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(raw)
	file.close()
	
	NotificationDaemon.show_toast("Video saved to %s" % path)
