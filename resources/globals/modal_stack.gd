extends Control

const DEFAULT_TWEEN_TIME: float = 0.21

var stack: Array:
	get:
		return [App.instance] + get_children()

func open_modal(modal_path: String) -> Control:
	move_to_front()
	
	assert(ResourceLoader.exists(modal_path), "Modal at path '%s' does not exist" % modal_path)

	var modal: Control = load(modal_path).instantiate()
	var background: ColorRect = modal.get_node_or_null("Background")

	if is_instance_valid(background):
		background.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				fade_free_modal(modal)
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				fade_free_modal(modal)
		)

	add_child(modal)
	_fade_out_modal(modal, 0.0)

	Lib.frame.connect(func() -> void:
		var _stack = stack
		for i in len(_stack):
			_fade_out_modal(_stack[i], DEFAULT_TWEEN_TIME, len(_stack) - i - 1)
		_fade_in_modal(modal, DEFAULT_TWEEN_TIME)
	, CONNECT_ONE_SHOT)

	return modal

func fade_free_modal(modal: Control, tween_time: float = DEFAULT_TWEEN_TIME) -> void:
	var _stack = stack
	_stack.erase(modal)
	for i in len(_stack):
		_fade_in_modal(_stack[i], DEFAULT_TWEEN_TIME, len(_stack) - i - 1)
	await _fade_out_modal(modal, tween_time)
	modal.queue_free()

func _fade_out_modal(modal: Control, tween_time: float = DEFAULT_TWEEN_TIME, depth: int = 1) -> void:
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)

	tween.tween_property(modal, "modulate:a", 0.25, tween_time)
	tween.tween_property(modal, "scale", Vector2.ONE * ((1.05 if modal.name == "Main" else 0.85) - (0.1 * depth)), tween_time)

	await tween.finished

func _fade_in_modal(modal: Control, tween_time: float = DEFAULT_TWEEN_TIME, depth: int = 0) -> void:
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)

	tween.tween_property(modal, "modulate:a", 1.0, tween_time)
	tween.tween_property(modal, "scale", Vector2.ONE * (1.0 - (0.1 * depth)), tween_time)

	await tween.finished
