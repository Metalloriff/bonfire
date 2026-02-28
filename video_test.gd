extends Control

func _ready() -> void:
	Lib.seconds(0.1).connect(func() -> void:
		$VideoStreamPlayer.stream_position = $VideoStreamPlayer.get_stream_length() - 1.0
	, CONNECT_ONE_SHOT)

	while true:
		var time: float = $VideoStreamPlayer.stream_position
		$VideoStreamPlayer.stream = null
		var stream = VideoStreamTheora.new()
		stream.file = "res://test.ogv"
		$VideoStreamPlayer.stream = stream
		$VideoStreamPlayer.play()

		var time_behind: float = $VideoStreamPlayer.get_stream_length() - time

		if time_behind < 0.5 or time_behind > 5.0:
			$VideoStreamPlayer.stream_position = $VideoStreamPlayer.get_stream_length() - 1.0
		else:
			$VideoStreamPlayer.stream_position = time

		await Lib.seconds(0.75)
