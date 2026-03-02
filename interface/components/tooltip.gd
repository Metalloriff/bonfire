class_name Tooltip extends PanelContainer

var text: String:
	set(new):
		if text == new:
			return
		
		text = new
		%Label.text = new

func _ready() -> void:
	modulate.a = 0.0
	scale = Vector2.ONE * 0.9

	await Lib.frame

	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)
	tween.tween_property(self , "modulate:a", 1.0, 0.11)
	tween.tween_property(self , "scale", Vector2.ONE, 0.11)

func fade_free() -> void:
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_IN)
	tween.tween_property(self , "modulate:a", 0.0, 0.15)
	tween.tween_property(self , "scale", Vector2.ONE * 0.9, 0.15)

static func attach(control: Control, text: String) -> void:
	control.mouse_entered.connect(func() -> void:
		if control.has_meta("tooltip"):
			return

		var tooltip: Tooltip = preload("res://interface/components/tooltip.tscn").instantiate()
		tooltip.text = text
		Engine.get_main_loop().root.add_child(tooltip)
		control.set_meta("tooltip", tooltip)
		tooltip.global_position = control.global_position
		tooltip.global_position.x -= tooltip.size.x / 2.0
		tooltip.global_position.x += (control.size.x / 2.0) + 7.0
		tooltip.global_position.y -= control.size.y + 10.0
	)

	control.mouse_exited.connect(func() -> void:
		if not control.has_meta("tooltip"):
			return
		
		var tooltip: Tooltip = control.get_meta("tooltip")
		tooltip.fade_free()
		control.remove_meta("tooltip")
	)
