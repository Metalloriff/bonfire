extends Control

var server: Server

var unsaved_changes: bool

func _ready() -> void:
	await Lib.frame

	if not is_instance_valid(server):
		return

	%Name.text = server.name
	if server.icon is ImageTexture:
		%IconPreview.texture = server.icon

func _on_icon_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_pick_image_button_pressed()

func _on_pick_image_button_pressed() -> void:
	$FileDialog.popup()

func _on_save_changes_button_pressed() -> void:
	if not server.local_user.has_permission(server, Permissions.SERVER_PROFILE_MANAGE):
		return

	if not unsaved_changes:
		ModalStack.fade_free_modal(self )
		return
	
	unsaved_changes = false
	
	var payload: Dictionary = {
		name = %Name.text
	}

	if %IconPreview.texture is ImageTexture:
		payload.icon = %IconPreview.texture.get_image().save_png_to_buffer()

		if server.icon is ImageTexture and payload.icon == server.icon.get_image().save_png_to_buffer():
			payload.erase("icon")
	
	server.send_api_message("edit_server", payload)
	ModalStack.fade_free_modal(self )

func _on_cancel_button_pressed() -> void:
	unsaved_changes = false
	ModalStack.fade_free_modal(self )

func _on_file_dialog_file_selected(path: String) -> void:
	var image: Image = Image.load_from_file(path)
	if image.get_size().x > 256 or image.get_size().y > 256:
		var ratio: float = min(float(image.get_size().x) / float(image.get_size().y), 1.0)
		image.resize(256, roundi(256.0 * ratio), Image.INTERPOLATE_BILINEAR)
	
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	%IconPreview.texture = texture
	unsaved_changes = true

func _on_name_text_changed(_new_text: String) -> void:
	unsaved_changes = true
