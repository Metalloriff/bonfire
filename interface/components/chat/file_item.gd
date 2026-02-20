extends PanelContainer

@export var channel: Channel
@export var media: Media

var force_load: bool = false

var cache_path: String:
	get:
		return "user://cache/media/%s/%s" % [channel.id, media.media_id]

func _ready() -> void:
	FS.mkdir(cache_path.get_base_dir())

	%FileName.text = "%s.%s" % [media.file_name, media.ext]
	%FileSize.text = Lib.bytes_to_readable(media.size)

	match media.ext:
		"png", "jpg", "jpeg", "svg", "webp":
			%FileType.text = "image"
			var texture_rect: TextureRect = %Icon

			if media.size > Lib.readable_to_bytes("1MB") and not force_load:
				%FileTooLargeContainer.show()
			else:
				if FileAccess.file_exists(cache_path):
					var data: PackedByteArray = FileAccess.get_file_as_bytes(cache_path)
					var image: Image = Image.new()
					image["load_%s_from_buffer" % media.ext.to_lower().replace("jpeg", "jpg")].call(data)
					texture_rect.texture = ImageTexture.create_from_image(image)
				else:
					channel.get_media_file_data_then(media.media_id, func(data: PackedByteArray) -> void:
						var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
						file.store_buffer(data)
						file.close()

						_ready.call_deferred()
					)
		"mp3", "wav", "ogg", "flac", "opus", "midi":
			%FileType.text = "audio"
			%Icon.texture = preload("res://icons/audioFile.png")

			if media.size > Lib.readable_to_bytes("8MB") and not force_load:
				%FileTooLargeContainer.show()
			else:
				var stream: AudioStream
				match media.ext:
					"mp3":
						stream = AudioStreamMP3.new()
					"wav":
						stream = AudioStreamWAV.new()
					"ogg":
						stream = AudioStreamOggVorbis.new()
				
				if not is_instance_valid(stream):
					%ControlsContainer.show()

					var label: Label = Label.new()
					label.text = "Unsupported audio format."
					label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					%ControlsContainer.add_child(label)
				else:
					if FileAccess.file_exists(cache_path):
						stream = stream.load_from_file(cache_path)
						_create_audio_item(stream)
					else:
						channel.get_media_file_data_then(media.media_id, func(data: PackedByteArray) -> void:
							var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
							file.store_buffer(data)
							file.close()

							_ready.call_deferred()
						)
		"mp4", "webm", "mkv", "avi", "mov", "flv", "wmv", "3gp", "m4v", "m4a", "mpg", "mpeg":
			%FileType.text = "video"
			%Icon.texture = preload("res://icons/videoFile.png")

			if media.size > Lib.readable_to_bytes("20MB") and not force_load:
				%FileTooLargeContainer.show()
			else:
				if FileAccess.file_exists(cache_path):
					var stream: FFmpegVideoStream = FFmpegVideoStream.new()
					stream.file = cache_path
					_create_video_item(stream)
				else:
					channel.get_media_file_data_then(media.media_id, func(data: PackedByteArray) -> void:
						var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
						file.store_buffer(data)
						file.close()

						_ready.call_deferred()
					)
		"exe", "x86_64", "appimage":
			%FileType.text = "executable(!)"
			%FileType.modulate = Color.html("#e02b4f")
			%FileType.tooltip = "This file is an executable. Only run it if you trust the author."
		"zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz", "txz", "tbz2", "tlz", "txz":
			%FileType.text = "archive"
		"pdf", "epub", "cbz", "cbr", "cb7", "cbt":
			%FileType.text = "document"
		"txt", "md":
			%FileType.text = "text"
			%Icon.texture = preload("res://icons/textSnippet.png")
		"html", "htm", "php":
			%FileType.text = "webpage"
		# There's so many code languages, I'm sure I got like 0.000001%.
		"gd", "py", "js", "css", "scss", "sass", "c", "cpp", "h", "hpp", "java", "cs", "go", "rs", "rb", "php", "pl", "lua", "sh", "bat", "ps1", "clj", "coffee", "ts", "tsx", "cjsx", "less":
			%FileType.text = "code"
			%Icon.texture = preload("res://icons/code.png")
		_:
			%FileType.text = "unknown"
	
	await Lib.frame
	await Lib.frame
	for text_chat_scroller: ScrollContainer in get_tree().get_nodes_in_group("text_chat_screen"):
		text_chat_scroller.scroll_vertical += size.y

func _create_audio_item(stream: AudioStream) -> void:
	var audio_controls = preload("res://interface/components/chat/audio_controls.tscn").instantiate()
	audio_controls.stream = stream

	%ControlsContainer.add_child(audio_controls)
	%ControlsContainer.show()
	%Icon.hide()

func _create_video_item(stream: FFmpegVideoStream) -> void:
	var video_player = preload("res://interface/components/chat/video_player.tscn").instantiate()
	video_player.stream = stream

	%ControlsContainer.add_child(video_player)
	%ControlsContainer.show()
	%Icon.hide()

func _on_download_button_pressed() -> void:
	var fd: FileDialog = FileDialog.new()
	add_child(fd)
	fd.name = "FileDialog"

	fd.current_file = "%s.%s" % [media.file_name, media.ext]
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.title = "Download File"

	fd.file_selected.connect(_on_file_dialog_file_selected)
	fd.canceled.connect(func() -> void: fd.queue_free())

	fd.popup_centered()

func _on_file_dialog_file_selected(path: String) -> void:
	channel.get_media_file_data_then(
		media.media_id,
		func(data: PackedByteArray) -> void:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(data)
		file.close()
		,
		NotificationDaemon.show_toast_progress("Downloading file...")
	)

	$FileDialog.queue_free()

func _on_file_too_large_button_pressed() -> void:
	force_load = true
	_ready()

	%FileTooLargeContainer.hide()
