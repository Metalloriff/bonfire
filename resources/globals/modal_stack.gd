extends Control

const DEFAULT_TWEEN_TIME: float = 0.21

func open_modal(modal_path: String) -> Control:
	move_to_front()
	
	assert(ResourceLoader.exists(modal_path), "Modal at path '%s' does not exist" % modal_path)

	var modal: Control = load(modal_path).instantiate()

	add_child(modal)
	_fade_out_modal(modal, 0.0)

	Lib.frame.connect(func() -> void:
		_fade_in_modal(modal, DEFAULT_TWEEN_TIME)
		_fade_out_modal(App.instance, DEFAULT_TWEEN_TIME)
	, CONNECT_ONE_SHOT)

	return modal

func fade_free_modal(modal: Control, tween_time: float = DEFAULT_TWEEN_TIME) -> void:
	_fade_in_modal(App.instance, tween_time)
	await _fade_out_modal(modal, tween_time)
	modal.queue_free()

func _fade_out_modal(modal: Control, tween_time: float = DEFAULT_TWEEN_TIME) -> void:
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)

	tween.tween_property(modal, "modulate:a", 0.25, tween_time)
	tween.tween_property(modal, "scale", Vector2.ONE * (0.95 if modal.name == "Main" else 0.85), tween_time)

	await tween.finished

func _fade_in_modal(modal: Control, tween_time: float = DEFAULT_TWEEN_TIME) -> void:
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)

	tween.tween_property(modal, "modulate:a", 1.0, tween_time)
	tween.tween_property(modal, "scale", Vector2.ONE, tween_time)

	await tween.finished
