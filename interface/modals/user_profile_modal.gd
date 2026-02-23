class_name UserProfileModal extends Control

static var instance: UserProfileModal

var user: User

var unsaved_changes: bool

func _ready() -> void:
	await Lib.frame

	if not is_instance_valid(user) or is_instance_valid(instance):
		queue_free()
		return
	
	instance = self
	
	%DisplayName.placeholder_text = user.name
	%DisplayName.text = user.display_name
	%Tagline.text = user.tagline
	%Bio.text = user.bio
	
	if user.avatar is ImageTexture:
		%AvatarPreview.texture = user.avatar

func _on_pick_pfp_button_pressed() -> void:
	$FileDialog.popup()

func _on_save_changes_button_pressed() -> void:
	if not unsaved_changes:
		ModalStack.fade_free_modal(self )
		return
	
	var payload: Dictionary = {
		display_name = %DisplayName.text,
		tagline = %Tagline.text,
		bio = %Bio.text
	}

	if %AvatarPreview.texture is ImageTexture:
		payload.avatar_data = %AvatarPreview.texture.get_image().save_png_to_buffer()

		if user.avatar is ImageTexture and payload.avatar_data == user.avatar.get_image().save_png_to_buffer():
			payload.erase("avatar_data")

	for server in ServerList.servers:
		if server.user_id == user.id:
			server.send_api_message("receive_user_profile_update", payload)
	
	user.display_name = %DisplayName.text
	user.avatar = %AvatarPreview.texture
	user.tagline = %Tagline.text
	user.bio = %Bio.text

	ResourceSaver.save(user, User.LOCAL_USER_PATH)
	%SaveChangesButton.disabled = true

func _on_cancel_button_pressed() -> void:
	if unsaved_changes:
		print("unsaved changes")

func _on_file_dialog_file_selected(path: String) -> void:
	var image: Image = Image.load_from_file(path)
	if image.get_size().x > 256 or image.get_size().y > 256:
		var ratio: float = min(float(image.get_size().x) / float(image.get_size().y), 1.0)
		image.resize(256, roundi(256.0 * ratio), Image.INTERPOLATE_BILINEAR)
	
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	%AvatarPreview.texture = texture
	unsaved_changes = true

func _on_avatar_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_pick_pfp_button_pressed()

func _on_tagline_text_changed(new_text: String) -> void:
	%TaglineCharLength.text = "(%d/%d)" % [len(new_text), 100]
	unsaved_changes = true

func _on_bio_text_changed() -> void:
	%BioCharLength.text = "(%d/%d)" % [len(%BioCharLength.text), 2000]
	unsaved_changes = true

func _on_display_name_text_changed(new_text: String) -> void:
	unsaved_changes = true
