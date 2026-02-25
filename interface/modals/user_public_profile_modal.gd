extends Control

var user: User

func _ready() -> void:
	await Lib.frame

	if OS.get_name() == "Android":
		$Modal/MarginContainer.custom_minimum_size = Vector2(0, 0)
		$Modal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	
	if not is_instance_valid(user):
		queue_free()
		return
	
	%Username.text = user.username
	%Tagline.text = user.tagline
	%Tagline.visible = len(user.tagline.strip_edges()) > 0
	%Bio.text = MessageItem._process_message_content(user.bio) if user.bio else "No bio provided."
	
	if user.avatar is ImageTexture:
		%Avatar.texture = user.avatar
	
	if len(user.roles):
		%RolesLabel.show()
		%RolesContainer.show()
		
		for role in user.roles:
			var button: Button = Button.new()
			button.text = role
			%RolesContainer.add_child(button)

func _on_bio_meta_clicked(meta: Variant) -> void:
	if meta is String and meta.strip_edges().begins_with("https://"):
		OS.shell_open(meta)

func _on_bio_meta_hover_started(meta: Variant) -> void:
	if meta is String and meta.strip_edges().begins_with("https://"):
		%Bio.tooltip_text = meta

func _on_bio_meta_hover_ended(meta: Variant) -> void:
	%Bio.tooltip_text = ""

func _on_avatar_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		
		var modal = ModalStack.open_modal("res://interface/modals/image_viewer_modal.tscn")
		modal.image = user.avatar
		modal.file_name = "%s' Avatar.png" % user.username.validate_filename()
