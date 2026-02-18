class_name ContextMenu extends Control

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		queue_free()

static func create_menu(menu_packed_scene: PackedScene) -> ContextMenu:
	var menu: ContextMenu = menu_packed_scene.instantiate()
	Engine.get_main_loop().current_scene.add_child(menu)
	return menu

static func attach_listener(control: Control, menu_packed_scene: PackedScene, create_callback: Callable = func(_m: ContextMenu) -> void: pass ) -> void:
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			var menu := create_menu(menu_packed_scene)
			create_callback.call(menu)
			menu.global_position = control.get_global_mouse_position()

			await Lib.frame
			
			var panel: PanelContainer = menu.get_node("PanelContainer")
			var window_height: float = menu.get_viewport_rect().size.y
			while menu.global_position.y + panel.size.y > window_height:
				menu.global_position.y -= 20.0
	)
