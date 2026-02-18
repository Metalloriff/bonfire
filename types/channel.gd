class_name Channel extends Resource

enum Type {
	TEXT,
	VOICE,
	MEDIA,
}

signal message_received(message: Message)

@export var id: String = Lib.create_uid(32)
@export var name: String = "Invalid Channel"
@export var type: int = Type.TEXT

var server: Server
var messages: Array[Message] = []
var messages_loaded: bool
var messages_loading: bool

var _db_path: String:
	get: return HeadlessServer.instance.server_data_path.path_join("channels").path_join(id + ".db")
var _db: SQLite

func send_message(content: String, encryption_key: String = "") -> void: # TODO add attachments support
	assert(not HeadlessServer.is_headless_server, "Cannot send message from headless server")
	assert(is_instance_valid(server), "No server for channel")

	var message_data: Dictionary = {
		channel_id = id,
		content = content
	}

	if encryption_key:
		message_data.encrypted = true
		message_data.content = Marshalls.raw_to_base64(EncryptionTools.encrypt_string(content, encryption_key))

	server.send_api_message("send_message", message_data)

func delete_message(message: Message) -> void:
	assert(is_instance_valid(server.com_node), "No server connection")
	assert(message.author_id == server.user_id, "Cannot delete messages from other users")

	server.send_api_message("delete_message", {
		channel_id = id,
		message_id = message.timestamp
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

func _load_messages_from_db(limit: int = 50, offset: int = 0) -> Array[Dictionary]:
	# TODO implement pagination
	assert(is_instance_valid(_db), "Database not initialized")

	var serialized_messages: Array[Dictionary] = []
	
	_db.query("SELECT * FROM messages ORDER BY timestamp DESC LIMIT %d OFFSET %d" % [limit, offset])
	for message_result in _db.query_result:
		serialized_messages.append(message_result)

	serialized_messages.reverse()
	return serialized_messages

func _commit_message(message: Message) -> void:
	assert(HeadlessServer.is_headless_server, "Cannot commit message as a client")
	assert(is_instance_valid(_db), "Database not initialized")

	var serialized_message: Dictionary = message.serialize()

	messages.append(message)
	HeadlessServer.send_api_message("new_message", {
		channel_id = id,
		message = serialized_message
	})

	_db.insert_row("messages", serialized_message)

func _initialize_messages_database() -> void:
	assert(HeadlessServer.is_headless_server, "Channel database can only be initialized by server")
	assert(is_instance_valid(HeadlessServer.instance), "No headless server instance")
	# assert(not FileAccess.file_exists(_db_path), "Channel database already exists")

	var messages_table_schema: Dictionary = {
		id = {data_type = "int", primary_key = true, not_null = true, auto_increment = true},
		author = {data_type = "text"},
		content = {data_type = "text"},
		timestamp = {data_type = "int"},
		encrypted = {data_type = "int"},
		attachments = {data_type = "text"}
	}

	FS.mkdir(_db_path.get_base_dir())

	_db = SQLite.new()
	_db.path = _db_path
	_db.open_db()
	_db.create_table("messages", messages_table_schema)
	
	# create the table if it doesn't exist with properties: id, author, content, timestamp, attachments (array of strings)
	# _db.create_table(
	# _db.execute("CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, author TEXT, content TEXT, timestamp INTEGER, attachments TEXT)")
