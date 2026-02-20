extends VBoxContainer

var stream: AudioStream:
	set(new):
		if new == stream:
			return
		stream = new

		if is_instance_valid(stream):
			$AudioStreamPlayer.stream = stream

			var duration: float = stream.get_length()
			%Timeline.max_value = duration
			%Time.text = "%02d:%02d" % [floorf(duration / 60.0), fmod(duration, 60.0)]
		else:
			$AudioStreamPlayer.stream = null

			%Timeline.max_value = 1.0
			%Time.text = "00:00"
		%Timeline.value = 0.0
		%Time.text = "00:00"

@onready var player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	%VolumeSlider.value = FS.get_pref("media_audio_volume", 0.75)

func _process(delta: float) -> void:
	if not is_instance_valid(stream):
		return
	
	var time: float = player.get_playback_position()
	
	%Timeline.set_value_no_signal(time)
	%Time.text = "%02d:%02d" % [floorf(time / 60.0), fmod(time, 60.0)]

func _on_pause_play_pressed() -> void:
	if not is_instance_valid(stream):
		return
	
	player.volume_linear = FS.get_pref("media_audio_volume", 0.75)
	%VolumeSlider.set_value_no_signal(player.volume_linear)
	
	player.stream_paused = not player.stream_paused
	if not player.stream_paused:
		player.play()
		player.seek(%Timeline.value)

	%PausePlay.icon = load("res://icons/playArrow.png") if player.stream_paused else load("res://icons/pause.png")

func _on_timeline_value_changed(value: float) -> void:
	if not is_instance_valid(stream):
		return
	
	player.seek(value)

func _on_volume_button_pressed() -> void:
	%VolumeContainer.visible = not %VolumeContainer.visible

func _on_volume_slider_value_changed(value: float) -> void:
	FS.set_pref("media_audio_volume", value)
	player.volume_linear = value

func _on_audio_stream_player_finished() -> void:
	%PausePlay.icon = load("res://icons/playArrow.png")
