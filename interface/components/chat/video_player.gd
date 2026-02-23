extends VBoxContainer

var stream:
	set(new):
		if new == stream:
			return
		stream = new

		if is_instance_valid(stream):
			$VideoStreamPlayer.stream = stream

			var duration: float = $VideoStreamPlayer.get_stream_length()
			%Timeline.max_value = duration
			%Time.text = "%02d:%02d" % [floorf(duration / 60.0), fmod(duration, 60.0)]

			$VideoStreamPlayer.play()
			await Lib.frame
			$VideoStreamPlayer.paused = true
		else:
			$VideoStreamPlayer.stream = null

			%Timeline.max_value = 1.0
			%Time.text = "00:00"
		%Timeline.value = 0.0
		%Time.text = "00:00"

@onready var player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	%VolumeSlider.value = FS.get_pref("media_audio_volume", 0.75)

func _process(delta: float) -> void:
	if not is_instance_valid(stream):
		return
	
	var time: float = player.stream_position
	
	%Timeline.set_value_no_signal(time)
	%Time.text = "%02d:%02d" % [floorf(time / 60.0), fmod(time, 60.0)]

func _on_pause_play_pressed() -> void:
	if not is_instance_valid(stream):
		return
	
	player.volume = FS.get_pref("media_audio_volume", 0.75)
	%VolumeSlider.set_value_no_signal(player.volume)
	
	player.paused = not player.paused
	if not player.paused:
		player.play()
		player.stream_position = %Timeline.value

	%PausePlay.icon = load("res://icons/playArrow.png") if player.paused else load("res://icons/pause.png")

func _on_timeline_value_changed(value: float) -> void:
	if not is_instance_valid(stream):
		return
	
	player.stream_position = value

func _on_volume_button_pressed() -> void:
	%VolumeContainer.visible = not %VolumeContainer.visible

func _on_volume_slider_value_changed(value: float) -> void:
	FS.set_pref("media_audio_volume", value)
	player.volume = value

func _on_video_stream_player_finished() -> void:
	%PausePlay.icon = load("res://icons/playArrow.png")

func _on_video_stream_player_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_on_pause_play_pressed()
	if event is InputEventScreenTouch and event.is_pressed():
		_on_pause_play_pressed()
