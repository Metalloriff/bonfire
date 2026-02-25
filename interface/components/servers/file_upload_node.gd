extends PanelContainer

var server: Server
var channel: Channel
var file_path: String

func _ready() -> void:
	assert(file_path, "No file path provided")
	assert(is_instance_valid(server), "No server provided")
	assert(is_instance_valid(channel), "No channel provided")

	%Label.text = file_path.get_file().get_basename()

	var auth: Dictionary = AuthPortal.get_auth(server.id)
	var encryption_key: String = ""

	if MessageEncryptionContextMenu.encrypt_message_enabled:
		encryption_key = MessageEncryptionContextMenu.encryption_key
	elif channel.is_private:
		encryption_key = channel.private_key

	server.com_node.file_server.upload_file(
		auth,
		file_path,
		channel.id,
		file_path.get_extension(),
		file_path.get_file().get_basename(),
		encryption_key,
		func(progress: float, offset: int, length: int, media_id: String
	) -> void:
		%ProgressBar.value = progress
		prints("progress", progress, offset, length)

		if progress >= 1.0 and media_id:
			prints("finished uploading file", media_id)
			%ProgressBar.hide()

			MainTextArea.instance.attachments.append(media_id)
	)
