extends PanelContainer

@export var channel: Channel
@export var media: Media

var force_load: bool = false

var cache_path: String:
	get:
		return "user://cache/media/%s/%s" % [channel.id, media.media_id]

func _ready() -> void:
	if OS.get_name() == "Android":
		Lib.frame.connect(func() -> void:
			set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
		, CONNECT_ONE_SHOT)

	FS.mkdir(cache_path.get_base_dir())

	%FileName.text = "%s.%s" % [media.file_name, media.ext]
	%FileSize.text = Lib.bytes_to_readable(media.size)

	if media.encrypted and not media.decryption_key:
		%Icon.texture = preload("res://icons/lock.png")
		%EncryptedContainer.show()
		%DownloadContainer.hide()
		%FileName.hide()

		%Password.text_changed.connect(func(_t: String) -> void:
			%EncryptedContainer/ErrorText.hide()
		)

		%EncryptedContainer/Encrypted/Button.pressed.connect(func() -> void:
			var decryption_key: String = %Password.text
			var decrypted_file_name: String = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(media.file_name), decryption_key)

			prints(media.file_name, decrypted_file_name)

			if "�" in decrypted_file_name or not decrypted_file_name:
				%EncryptedContainer/ErrorText.show()
				return
			
			media.file_name = decrypted_file_name
			media.decryption_key = decryption_key

			%Icon.texture = preload("res://icons/insertDriveFile.png")
			%EncryptedContainer.hide()
			%DownloadContainer.show()
			%FileName.show()

			_ready.call_deferred()
		)

		%FileType.text = "encrypted"
		return

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
					texture_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

					texture_rect.gui_input.connect(func(event: InputEvent) -> void:
						if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
							if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
								return
							
							if event.is_pressed():
								var modal = ModalStack.open_modal("res://interface/modals/image_viewer_modal.tscn")
								modal.image = texture_rect.texture
								modal.file_name = %FileName.text.validate_filename()
					)
				else:
					channel.get_media_file_data_then(media.media_id, func(data: PackedByteArray) -> void:
						var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
						file.store_buffer(data)
						file.close()

						_ready.call_deferred()
					, media)
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
						, media)
		"mp4", "webm", "mkv", "avi", "mov", "flv", "wmv", "3gp", "m4v", "m4a", "mpg", "mpeg":
			%FileType.text = "video"
			%Icon.texture = preload("res://icons/videoFile.png")

			if media.size > Lib.readable_to_bytes("20MB") and not force_load or OS.get_name() == "Android":
				%FileTooLargeContainer.show()
			else:
				if FileAccess.file_exists(cache_path):
					var stream = ClassDB.instantiate("FFmpegVideoStream")
					stream.file = cache_path
					_create_video_item(stream)
				else:
					channel.get_media_file_data_then(media.media_id, func(data: PackedByteArray) -> void:
						var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
						file.store_buffer(data)
						file.close()

						_ready.call_deferred()
					, media)
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

func _create_video_item(stream) -> void:
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
		, media,
		NotificationDaemon.show_toast_progress("Downloading file...")
	)

	$FileDialog.queue_free()

func _on_file_too_large_button_pressed() -> void:
	force_load = true
	_ready()

	%FileTooLargeContainer.hide()
