class_name ContextMenu extends Control

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		fade_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		fade_free()

func fade_free() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)
	tween.tween_property(self , "modulate:a", 0.0, 0.15)
	tween.tween_property(self , "scale", Vector2.ONE * 0.9, 0.15)

	await tween.finished
	queue_free()

static func create_menu(menu_packed_scene: PackedScene) -> ContextMenu:
	var menu: ContextMenu = menu_packed_scene.instantiate()
	Engine.get_main_loop().current_scene.add_child(menu)

	Lib.frame.connect(func() -> void:
		menu.pivot_offset = menu.get_global_mouse_position() - menu.global_position
		menu.scale = Vector2.ONE * 0.95
		menu.modulate.a = 0.0

		var tween := menu.create_tween().set_parallel().set_ease(Tween.EASE_IN)
		tween.tween_property(menu, "modulate:a", 1.0, 0.11)
		tween.tween_property(menu, "scale", Vector2.ONE, 0.11)
	, CONNECT_ONE_SHOT)

	return menu

static func attach_listener(control: Control, menu_packed_scene: PackedScene, create_callback: Callable = func(_m: ContextMenu) -> void: pass ) -> void:
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			var menu := create_menu(menu_packed_scene)
			create_callback.call(menu)
			menu.global_position = control.get_global_mouse_position()

			await Lib.frame

			if not is_instance_valid(menu) or not menu.is_inside_tree():
				return
			
			var panel: PanelContainer = menu.get_node("PanelContainer")
			var window_width: float = menu.get_viewport_rect().size.x
			var window_height: float = menu.get_viewport_rect().size.y
			while menu.global_position.x + panel.size.x > window_width:
				menu.global_position.x -= 20.0
			while menu.global_position.y + panel.size.y > window_height:
				menu.global_position.y -= 20.0
	)
