extends ContextMenu

var user: User

func _ready() -> void:
	%VolumeSlider.value = user.local_volume

func _on_volume_slider_value_changed(value: float) -> void:
	user.local_volume = value
