extends VBoxContainer

@export var conform_to_player_size: bool = false
var file_path: String

var stream:
	set(new):
		if new == stream:
			return
		stream = new

		var player_size: Vector2 = %VideoStreamPlayer.size

		if is_instance_valid(stream):
			%VideoStreamPlayer.stream = stream

			var duration: float = %VideoStreamPlayer.get_stream_length()
			%Timeline.max_value = duration
			%Time.text = "%02d:%02d" % [floorf(duration / 60.0), fmod(duration, 60.0)]

			var video_size: Vector2 = %VideoStreamPlayer.get_video_texture().get_size()
			var ratio: float = video_size.y / video_size.x
			
			if conform_to_player_size:
				var ratio_x: float = player_size.x / video_size.x
				var s: Vector2 = Vector2(player_size.y * ratio_x, player_size.y)
				var sub: float = s.x - player_size.x

				if sub > 0:
					s.x -= sub
					s.y -= sub * ratio

				%VideoStreamPlayer.custom_minimum_size = s
				%VideoStreamPlayer.size = s
			else:
				%VideoStreamPlayer.custom_minimum_size = Vector2(500, 500 * ratio)
				%VideoStreamPlayer.size = %VideoStreamPlayer.custom_minimum_size

			%VideoStreamPlayer.play()
			await Lib.frame
			%VideoStreamPlayer.paused = true

			await Lib.frame

			if conform_to_player_size:
				_on_pause_play_pressed()
		else:
			%VideoStreamPlayer.stream = null

			%Timeline.max_value = 1.0
			%Time.text = "00:00"
		%Timeline.value = 0.0
		%Time.text = "00:00"

@onready var player: VideoStreamPlayer = %VideoStreamPlayer

func _ready() -> void:
	%VolumeSlider.value = FS.get_pref("media_audio_volume", 0.75)
	%FullScreenButton.visible = not conform_to_player_size

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
		player.stream_position = %Timeline.value if %Timeline.value / %Timeline.max_value < 0.99 else 0.0

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

func _on_full_screen_button_pressed() -> void:
	var modal = ModalStack.open_modal("res://interface/modals/video_viewer_modal.tscn")
	modal.stream = stream
	modal.raw = FileAccess.get_file_as_bytes(file_path)
	modal.file_name = file_path.get_file()
