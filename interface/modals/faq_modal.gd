extends Control

func _ready() -> void:
	if OS.get_name() == "Android":
		$Modal.custom_minimum_size = Vector2.ZERO
		$Modal/MarginContainer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
