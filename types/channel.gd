class_name Channel extends Resource

enum Type {
	TEXT,
	VOICE,
	MEDIA,
}

signal message_received(message: Message)
signal unread_count_updated()

@export var id: String = Lib.create_uid(32)
@export var name: String = "Invalid Channel":
	get:
		if is_private:
			if not is_instance_valid(server):
				return "..."
			
			for user in pm_participants:
				if user.user_id != server.user_id:
					var u: User = server.get_user(user.user_id)
					return u.username if is_instance_valid(u) else "Invalid User"
		return name
@export var type: int = Type.TEXT
@export var is_private: bool
@export var pm_participants: Array[Dictionary] = []
@export var last_message_timestamp: int = -1

var server: Server
var messages: Array[Message] = []
var messages_loaded: bool
var messages_loading: bool
var private_key: String
var last_read_message_timestamp: int = -1:
	set(new):
		if new == last_read_message_timestamp:
			return
		last_read_message_timestamp = new

		FS.set_pref("%s.lrmt_%s" % [server.id, id], new)
var unread_count: int = -1:
	set(new):
		if new == unread_count:
			return
		unread_count = new

		if unread_count >= 0:
			unread_count_updated.emit()

var _db_path: String:
	get:
		return HeadlessServer.instance.server_data_path.path_join("private_channels" if is_private else "channels").path_join(id + ".db")
var _db: SQLite

func _init() -> void:
	if HeadlessServer.is_headless_server:
		return
	
	message_received.connect(func(message: Message) -> void:
		if ChatFrame.instance.selected_channel == self:
			last_read_message_timestamp = message.timestamp
		else:
			unread_count += 1
	)

func get_unread_count() -> int:
	if unread_count == -1:
		if last_read_message_timestamp == -1:
			last_read_message_timestamp = FS.get_pref("%s.lrmt_%s" % [server.id, id], last_message_timestamp)
		unread_count = -2
		unread_count = await get_message_count_since(last_read_message_timestamp)

	while unread_count < 0:
		await Lib.frame
	
	return unread_count

func send_message(content: String, encryption_key: String = "", attachments: Array[String] = []) -> void:
	assert(not HeadlessServer.is_headless_server, "Cannot send message from headless server")
	assert(is_instance_valid(server), "No server for channel")

	var message_data: Dictionary = {
		channel_id = id,
		content = content,
		attachments = attachments
	}

	if encryption_key:
		message_data.encrypted = true
		message_data.content = Marshalls.raw_to_base64(EncryptionTools.encrypt_string(content, encryption_key))
	elif is_private:
		message_data.content = Marshalls.raw_to_base64(EncryptionTools.encrypt_string(content, private_key))

	server.send_api_message("send_message", message_data)

func delete_message(message: Message) -> void:
	assert(is_instance_valid(server.com_node), "No server connection")
	assert(message.author_id == server.user_id or server.local_user.has_permission(server, Permissions.MESSAGE_DELETE), "Cannot delete messages from other users")

	server.send_api_message("delete_message", {
		channel_id = id,
		message_id = message.timestamp
	})

func edit_message(message: Message, new_content: String) -> void:
	assert(is_instance_valid(server.com_node), "No server connection")
	assert(message.author_id == server.user_id, "Cannot edit messages from other users")

	server.send_api_message("edit_message", {
		channel_id = id,
		message_id = message.timestamp,
		content = new_content
	})

func load_messages(limit: int = 50, offset: int = 0) -> void:
	if messages_loaded or messages_loading or not is_instance_valid(server.com_node):
		return
	
	assert(limit < 100, "Cannot load more than 100 messages at once")
	
	messages_loading = true

	server.send_api_message("fetch_messages", {
		channel_id = id,
		limit = limit,
		offset = offset
	})

func find_message(message_id_or_timestamp: int) -> Message:
	for message in messages:
		if message.id == message_id_or_timestamp or message.timestamp == message_id_or_timestamp:
			return message
	return null

func purge_messages() -> void:
	if HeadlessServer.is_headless_server:
		_db.delete_rows("messages", "*")
		_db.query("SELECT * FROM media")
		for media_result in _db.query_result:
			var media_path: String = _get_media_path(media_result.media_id)
			if FileAccess.file_exists(media_path):
				DirAccess.remove_absolute(media_path)
		_db.delete_rows("media", "*")

		server.save_to_disk(false)

		if is_private:
			for participant in pm_participants:
				var pid: int = server.get_peer_id_by_user_id(participant.user_id)

				if pid > 0:
					HeadlessServer.send_api_message("purge_channel_messages", {
						channel_id = id
					}, pid)
		else:
			HeadlessServer.send_api_message("purge_channel_messages", {
				channel_id = id
			})
	else:
		if is_private:
			var allowed: bool = false
			for participant in pm_participants:
				if participant.user_id == server.user_id:
					allowed = true
					break
			
			if not allowed:
				return
		elif not server.local_user.has_permission(server, Permissions.MESSAGE_PURGE):
			return
			
		server.send_api_message("purge_channel_messages", {
			channel_id = id
		})

func delete_channel() -> void:
	if HeadlessServer.is_headless_server:
		purge_messages()

		await Lib.seconds(2.0)
		
		if self in server.private_channels:
			server.private_channels.erase(self )
		elif self in server.channels:
			server.channels.erase(self )
		else:
			prints("channel", id, "not found in server", server.id)
			return

		server.save_to_disk()
	else:
		if is_private:
			var allowed: bool = false
			for participant in pm_participants:
				if participant.user_id == server.user_id:
					allowed = true
					break
			
			if not allowed:
				return
			
			server.send_api_message("delete_channel", {
				channel_id = id
			})
		else:
			# TODO implement based on user permissions
			return

func _load_messages_from_db(limit: int = 50, offset: int = 0) -> Array[Dictionary]:
	# TODO implement pagination
	if not is_instance_valid(_db):
		return []
	
	assert(limit < 100, "Cannot load more than 100 messages at once")

	var serialized_messages: Array[Dictionary] = []
	
	_db.query("SELECT * FROM messages ORDER BY timestamp DESC LIMIT %d OFFSET %d" % [limit, offset])
	for message_result in _db.query_result:
		serialized_messages.append(message_result)

	serialized_messages.reverse()
	return serialized_messages

var _media_meta_cache: Dictionary = {}
func get_media_meta(media_id: String) -> Media: # TODO optimize this
	assert(media_id, "No media id provided")

	if not media_id in _media_meta_cache:
		await Lib.seconds(0.5)
		server.send_api_message("fetch_media_meta", {
			channel_id = id,
			media_id = media_id
		})

	var timeout: float = 0.0
	while not media_id in _media_meta_cache:
		timeout += await Lib.frame_with_delta()

		if timeout > 5.0:
			print("Timeout while waiting for media meta")
			return null
	
	if is_private and private_key and not _media_meta_cache[media_id].encrypted:
		print("should decrypt media meta")
		_media_meta_cache[media_id].decryption_key = private_key
		_media_meta_cache[media_id].file_name = EncryptionTools.decrypt_string(Marshalls.base64_to_raw(_media_meta_cache[media_id].file_name), private_key)
	
	return _media_meta_cache[media_id]

var _media_response_cache: Dictionary = {}
func get_media_file_data_then(media_id: String, callback: Callable, meta: Media = null, progress_callback: Callable = func(_v: float) -> void: pass ) -> void:
	assert(media_id, "No media id provided")

	if not media_id in _media_response_cache:
		_media_response_cache[media_id] = await server.com_node.file_server.request_file(AuthPortal.get_auth(server.id), id, media_id, progress_callback)

		if is_instance_valid(meta) and meta.decryption_key:
			_media_response_cache[media_id] = EncryptionTools.decrypt_raw_data(_media_response_cache[media_id], meta.decryption_key)

		prints("got media response", media_id, _media_response_cache[media_id])
	
	callback.call(_media_response_cache[media_id])

var _message_count_since_response: int = -1
func get_message_count_since(timestamp: int) -> int:
	if HeadlessServer.is_headless_server:
		_db.query("SELECT COUNT(*) FROM messages WHERE timestamp > %d" % timestamp)
		return _db.query_result[0]["COUNT(*)"]
	else:
		_message_count_since_response = -1
		server.send_api_message("fetch_message_count_since", {
			channel_ids = [id],
			timestamp = timestamp
		})

		var timeout: float = 0.0
		while _message_count_since_response == -1 and timeout < 3.0:
			timeout += await Lib.frame_with_delta()

		return _message_count_since_response

func _load_media_meta_from_db(media_id: String) -> Dictionary:
	assert(HeadlessServer.is_headless_server, "Cannot load media item from db as a client")
	assert(is_instance_valid(_db), "Database not initialized")

	_db.query("SELECT * FROM media WHERE media_id = '%s'" % media_id)
	if not _db.query_result:
		prints("media meta not found", media_id)
		return {}

	return _db.query_result[0]

func _get_media_path(media_id: String) -> String:
	return HeadlessServer.instance.server_data_path.path_join("media").path_join(id).path_join(media_id)

func _load_media_from_db(media_id: String) -> PackedByteArray:
	assert(HeadlessServer.is_headless_server, "Cannot load media item from db as a client")
	assert(is_instance_valid(_db), "Database not initialized")

	var meta: Dictionary = _load_media_meta_from_db(media_id)
	assert(meta, "Media item not found")
	
	var file_path: String = _get_media_path(media_id)
	assert(FileAccess.file_exists(file_path), "Media item not found")

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(file_path)
	assert(len(bytes) > 0, "Media item does not exist! " + error_string(FileAccess.get_open_error()))
	assert(len(bytes) == meta.size, "Media item size does not match")

	return bytes

func _commit_media(media: Media) -> bool:
	if not HeadlessServer.is_headless_server:
		print("Cannot commit media item as a client")
		return false
	
	if not is_instance_valid(_db):
		print("Database not initialized")
		return false

	return _db.insert_row("media", {
		media_id = media.media_id,
		encrypted = media.encrypted,
		file_name = media.file_name,
		ext = media.ext,
		md5 = media.md5,
		size = media.size,
		message_id = media.message_id,
		uploader_id = media.uploader_id
	})

func _commit_message(message: Message) -> void:
	assert(HeadlessServer.is_headless_server, "Cannot commit message as a client")
	assert(is_instance_valid(_db), "Database not initialized")

	var serialized_message: Dictionary = message.serialize()

	messages.append(message)

	var api_message_data: Dictionary = {
		channel_id = id,
		message = serialized_message
	}

	if is_private:
		for participant in pm_participants:
			var peer_id: int = server.get_peer_id_by_user_id(participant.user_id)
			if not peer_id in server.online_users:
				continue
			
			HeadlessServer.send_api_message("new_message", api_message_data, peer_id)
	else:
		HeadlessServer.send_api_message("new_message", api_message_data)

	_db.insert_row("messages", serialized_message)

func _initialize_messages_database() -> void:
	assert(HeadlessServer.is_headless_server, "Channel database can only be initialized by server")
	assert(is_instance_valid(HeadlessServer.instance), "No headless server instance")

	FS.mkdir(_db_path.get_base_dir())
	_db = SQLite.new()
	_db.path = _db_path
	_db.open_db()

	var messages_table_schema: Dictionary = {
		id = {data_type = "int", primary_key = true, not_null = true, auto_increment = true},
		author = {data_type = "text"},
		content = {data_type = "text"},
		timestamp = {data_type = "int"},
		encrypted = {data_type = "int"},
		attachments = {data_type = "text"}
	}

	_db.create_table("messages", messages_table_schema)

	var media_table_schema: Dictionary = {
		id = {data_type = "int", primary_key = true, not_null = true, auto_increment = true},
		media_id = {data_type = "text"},
		encrypted = {data_type = "int"},
		file_name = {data_type = "text"},
		ext = {data_type = "text"},
		md5 = {data_type = "text"},
		size = {data_type = "int"},
		message_id = {data_type = "int"},
		uploader_id = {data_type = "text"}
	}

	_db.create_table("media", media_table_schema)
	
	# create the table if it doesn't exist with properties: id, author, content, timestamp, attachments (array of strings)
	# _db.create_table(
	# _db.execute("CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, author TEXT, content TEXT, timestamp INTEGER, attachments TEXT)")
