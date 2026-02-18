class_name Message extends Resource

var id: int
@export var author_id: String
@export var content: String
@export var timestamp: int
@export var attachment_ids: Array = []
@export var encrypted: bool

var decrypted_content: String

func _init(author_id: String = "", content: String = "") -> void:
	self.author_id = author_id
	self.content = content
	self.timestamp = int(Time.get_unix_time_from_system())

func serialize() -> Dictionary:
	return {
		author = author_id,
		content = content,
		timestamp = timestamp,
		attachments = JSON.stringify(attachment_ids),
		encrypted = 1 if encrypted else 0
	}

func deserialize(data: Dictionary) -> Message:
	self.id = data.id if "id" in data else -1
	self.author_id = data.author
	self.content = data.content
	self.timestamp = data.timestamp
	self.attachment_ids = JSON.parse_string(data.attachments)
	self.encrypted = 1 if (data.encrypted if "encrypted" in data else false) else 0

	return self
