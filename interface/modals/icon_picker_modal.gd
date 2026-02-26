extends Control

signal icon_selected(icon_name: String)

var has_emitted: bool

@onready var list: HFlowContainer = %List

func _ready() -> void:
	var icon_paths := DirAccess.get_files_at("res://icons")
	icon_paths.sort()

	for icon_path in icon_paths:
		if not icon_path.ends_with(".png"):
			continue
		
		var icon: Texture2D = load("res://icons/%s" % icon_path)
		var texture_rect: TextureRect = TextureRect.new()

		texture_rect.texture = icon

		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = Vector2(40, 40)

		texture_rect.gui_input.connect(func(event: InputEvent) -> void:
			if has_emitted:
				return
			
			if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT or event is InputEventScreenTouch) and event.is_pressed():
				icon_selected.emit(icon_path)
				ModalStack.fade_free_modal(self )
		)

		list.add_child(texture_rect)

func _exit_tree() -> void:
	if has_emitted:
		return
	
	icon_selected.emit("")

func _on_search_field_text_changed(new_text: String) -> void:
	for child in list.get_children():
		child.visible = not new_text or new_text.to_lower() in child.texture.resource_path.to_lower()
