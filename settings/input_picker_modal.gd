extends Control

signal input_event(event: InputEvent)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouseMotion: return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5: return
	
	input_event.emit(event)
	queue_free()
