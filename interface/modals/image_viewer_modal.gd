extends Control

var image: ImageTexture
var file_name: String

func _ready() -> void:
	await Lib.frame

	if not is_instance_valid(image):
		queue_free()
		return
	
	%Image.texture = image

func _on_save_button_pressed() -> void:
	var fd: FileDialog = $FileDialog
	fd.current_file = file_name
	fd.popup()

func _on_file_dialog_file_selected(path: String) -> void:
	match path.get_extension():
		"png":
			image.get_image().save_png(path)
		"jpg", "jpeg":
			image.get_image().save_jpg(path)
		"webp":
			image.get_image().save_webp(path)
		"bmp":
			image.get_image().save_bmp(path)
	
	NotificationDaemon.show_toast("Image saved to %s" % path)
