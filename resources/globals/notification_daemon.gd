extends Node2D

enum NotificationType {
	Default,
	Warning,
	Error,
	Success
}

@onready var toasts := %Toasts
@onready var toast_notification: PanelContainer = create_item_instance(%ToastNotification)
@onready var status_list := %Statuses

func create_item_instance(item: Node) -> Node:
	var dupe = item.duplicate()
	item.queue_free()
	return dupe

func _process(_delta: float) -> void:
	status_list.modulate.a = 0.2 + (0.7 - 0.2) * (sin(Time.get_ticks_msec() / 500.0) + 1.0) / 2.0

func show_toast(message: String, type: NotificationType = NotificationType.Default, lifetime: float = 7.0) -> void:
	var toast := toast_notification.duplicate()
	
	toast.get_node("M/Label").text = message
	
	if type != NotificationType.Default:
		var panel: StyleBoxFlat = toast["theme_override_styles/panel"].duplicate()
		panel.bg_color = get_bg_color_for_type(type)
		toast["theme_override_styles/panel"] = panel
	
	toasts.add_child(toast)
	
	await Lib.frame

	toast.show()
	toast.position.x = get_window().size.x

	
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(toast, "position:x", get_window().size.x - (toast.size.x * 2.0) + 25.0, 1.0)
	
	create_tween().tween_property(toast.get_node("ProgressBar"), "value", 100.0, lifetime)
	
	await get_tree().create_timer(lifetime).timeout
	
	tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC).set_parallel()
	tween.tween_property(toast, "position:x", get_window().size.x, 1.0)
	tween.tween_property(toast, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	toast.queue_free()

func show_toast_progress(message: String, max_value: float = 1.0) -> Callable:
	var toast := toast_notification.duplicate()
	toast.position.x = get_window().size.x * 0.4
	
	toast.get_node("M/Label").text = message
	toast.get_node("ProgressBar").max_value = max_value
	toast.get_node("ProgressBar").value = 0.0

	toasts.add_child(toast)
	toast.show()
	
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(toast, "position:x", 0.0, 1.0)

	var end: Callable = func() -> void:
		if not is_instance_valid(toast): return

		var t := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
		t.tween_property(toast, "position:x", get_window().size.x * 0.4, 1.0)

		await t.finished

		if is_instance_valid(toast):
			toast.queue_free()
	
	var progress: Callable = func(data: Variant) -> void:
		var value: float = 0.0
		
		if data is Dictionary:
			if "text" in data:
				toast.get_node("M/Label").text = data.text
			value = data.value
		else:
			value = data
		
		toast.get_node("ProgressBar").value = value

		if value >= max_value:
			end.call()
	return progress

func set_status_state(status_name: String, state: bool) -> void:
	status_list.get_node(status_name).visible = state

func get_bg_color_for_type(type: NotificationType) -> Color:
	match type:
		NotificationType.Warning:
			return Color.html("#ff9900")
		NotificationType.Error:
			return Color.html("#ff5555")
	return Color.TRANSPARENT
