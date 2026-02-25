class_name FileServer extends Node

signal download_confirmed(player_id: int, path: String)
signal on_file_received(path: String)

var tcp_server := TCPServer.new()
var server: Server

var ip_address: String = "localhost"
var port: int = 26969

var _authorized_files_to_send: Array[String]
var _downloading_files: Array[String]

func host(port: int = 26969) -> void:
	tcp_server = TCPServer.new()
	tcp_server.listen(port)

func set_connection_details(ip_address: String = self.ip_address, port: int = self.port) -> void:
	self.ip_address = ip_address
	self.port = port

func _process(_delta: float) -> void:
	if is_instance_valid(tcp_server) and tcp_server.is_listening():
		if tcp_server.is_connection_available():
			var client := tcp_server.take_connection()
			_handle_api_request_server(client)

			# var thread := Thread.new()
			# thread.start(_handle_api_request_server.bind(client))

func _handle_api_request_server(client: StreamPeerTCP) -> void:
	while client.get_available_bytes() <= 0:
		client.poll()
		await Engine.get_main_loop().process_frame

	var request_data: Dictionary = JSON.parse_string(client.get_string())

	if not "auth" in request_data or not "username" in request_data.auth or not "password_hash" in request_data.auth:
		print("Invalid auth data! User did not provide username and password hash.")
		return
	
	var user_id: String = (request_data.auth.username + ":" + request_data.auth.password_hash).sha256_text()
	var user: User = server.get_user(user_id)
	if not is_instance_valid(user) or not user.is_online_in_server(server):
		prints("Invalid auth data! User could not be found.", user_id)
		return
	
	match request_data.endpoint:
		"request_file":
			if not "media_id" in request_data or not "channel_id" in request_data:
				return
			
			var media_id: String = request_data.media_id
			var channel_id: String = request_data.channel_id

			var channel: Channel = server.get_channel(channel_id)
			if not is_instance_valid(channel):
				print("Invalid channel for file request")
				return
			
			var meta: Dictionary = channel._load_media_meta_from_db(media_id)
			if not meta:
				print("Media item not found - _load_media_meta_from_db")
				return
			
			var bytes: PackedByteArray = channel._load_media_from_db(media_id)
			if not len(bytes):
				print("Media item not found - _load_media_from_db")
				return
			
			client.put_64(len(bytes))
			
			var offset := 0
			while offset < len(bytes):
				client.poll()

				var block_size = 8192 * 16
				var chunk_size: int = min(block_size, len(bytes) - offset)

				var response = client.put_partial_data(bytes.slice(offset, offset + chunk_size))
				offset += response[1]
				
				await Lib.frame
			
			client.disconnect_from_host()
		"receive_file":
			if not "file_type" in request_data or not "channel_id" in request_data:
				return
			
			var channel_id: String = request_data.channel_id
			var channel: Channel = server.get_channel(channel_id)
			if not is_instance_valid(channel):
				print("Invalid channel for file request")
				return

			var file_type: String = request_data.file_type
			var file_name: String = request_data.file_name if "file_name" in request_data else Lib.create_uid(12)
			var file_size: int = client.get_64()
			var data: PackedByteArray
			var i: int = 0
			var timeout: float = 0.0

			if file_size > server.max_file_upload_size:
				print("File size too large")
				client.disconnect_from_host()
				return

			while len(data) < file_size:
				client.poll()

				i += 1
				if i > 100:
					i = 0
					timeout += await Lib.frame_with_delta()
					
					if timeout > 300.0:
						print("Timeout while receiving file")
						client.disconnect_from_host()
						return
				
				var available_bytes := client.get_available_bytes()
				if available_bytes > 0:
					var d: Array = client.get_partial_data(available_bytes)
					if d[0] != OK:
						prints("error", error_string(d[0]))
						client.disconnect_from_host()
						print("Error while receiving file")
						return
					
					data.append_array(d[1])

					if len(data) > server.max_file_upload_size:
						print("File size too large")
						client.disconnect_from_host()
						return
			
			var media: Media = Media.new()
			var media_path: String = channel._get_media_path(media.media_id)

			media.uploader_id = user_id
			media.encrypted = "encrypted" in request_data and request_data.encrypted
			media.file_name = file_name
			media.size = len(data)
			media.ext = file_type
			media.encrypted = request_data.encrypted

			var hashing_context := HashingContext.new()
			hashing_context.start(HashingContext.HASH_MD5)
			hashing_context.update(data)
			media.md5 = hashing_context.finish().hex_encode()

			if not channel._commit_media(media):
				print("Failed to commit media item")
				return
			
			FS.mkdir(media_path.get_base_dir())

			var file := FileAccess.open(media_path, FileAccess.WRITE)
			if not file:
				channel._db.delete_rows("media", "media_id = '%s'" % media.media_id)
				print("Failed to create media file! File path: %s, error: %s" % [media_path, error_string(FileAccess.get_open_error())])
				return
			
			if not file.store_buffer(data):
				channel._db.delete_rows("media", "media_id = '%s'" % media.media_id)
				print("Failed to write media file! File path: %s, error: %s" % [media_path, error_string(FileAccess.get_open_error())])
				return
			
			file.close()
			client.put_string("finished:%s" % media.media_id)

func send_api_message(endpoint: String, request_data: Dictionary = {}) -> StreamPeerTCP:
	request_data = request_data.merged({endpoint = endpoint}, true)
	
	var client := StreamPeerTCP.new()
	
	if client.connect_to_host(ip_address, port) != OK:
		print("Error: Could not connect to TCP server!")
	else:
		while client.get_status() == StreamPeerTCP.STATUS_CONNECTING:
			print("Connecting to TCP server...")
			client.poll()
			await Lib.frame
		
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			prints("Failed to connect to TCP server!", client.get_status())
			return null
		
		client.put_string(JSON.stringify(request_data))
		return client
	return null

func request_file(auth: Dictionary, channel_id: String, media_id: String, progress_callback: Callable = func() -> void: pass ) -> PackedByteArray:
	var client := await send_api_message("request_file", {
		auth = auth,
		channel_id = channel_id,
		media_id = media_id
	})

	var size: int = client.get_64()
	prints("file size", size)

	progress_callback.call(0.0)
	
	var data: PackedByteArray
	var i: int = 0
	while len(data) < size:
		client.poll()

		i += 1
		if i > 100:
			i = 0
			await Lib.frame

		var available_bytes := client.get_available_bytes()
		if available_bytes > 0:
			var d: Array = client.get_partial_data(available_bytes)
			if d[0] != OK:
				prints("error", error_string(d[0]))
				client.disconnect_from_host()
				print("Error while receiving file")
				return []
			
			progress_callback.call(float(len(data)) / float(size))
			data.append_array(d[1])
	
	progress_callback.call(1.0)
	return data

func upload_file(auth: Dictionary, file_path: String, channel_id: String, file_type: String, file_name: String, encryption_key: String, progress_callback: Callable) -> void:
	var client := await send_api_message("receive_file", {
		auth = auth,
		channel_id = channel_id,
		file_type = file_type,
		file_name = Marshalls.raw_to_base64(EncryptionTools.encrypt_string(file_name, encryption_key)) if encryption_key else file_name,
		encrypted = len(encryption_key) > 0 and encryption_key != server.get_channel(channel_id).private_key
	})
	var data := FileAccess.get_file_as_bytes(file_path)

	if encryption_key:
		data = EncryptionTools.encrypt_raw_data(data, encryption_key)
	
	client.put_64(len(data))
	
	progress_callback.call(0.0, 0, len(data), "")

	var offset := 0
	while offset < len(data):
		client.poll()

		var block_size = 8192 * 16
		var chunk_size: int = min(block_size, len(data) - offset)

		var response = client.put_partial_data(data.slice(offset, offset + chunk_size))
		offset += response[1]
		
		progress_callback.call(float(offset) / float(len(data)), offset, len(data), "")
		await Lib.frame

	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		client.poll()
		
		if client.get_available_bytes() > 0:
			var string := client.get_string()
			
			if string.begins_with("finished:"):
				progress_callback.call(1.0, len(data), len(data), string.substr(9))
				client.disconnect_from_host()
				return
		
		await Lib.frame
