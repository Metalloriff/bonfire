extends ContextMenu

var user: User

func _ready() -> void:
	await Lib.frame
	
	%VolumeSlider.value = user.local_volume
	%Username.text = user.name

func _on_volume_slider_value_changed(value: float) -> void:
	user.local_volume = value
