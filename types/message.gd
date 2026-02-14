class_name Message extends Resource

@export var author_id: String
@export var content: String
@export var timestamp: int
@export var attachment_ids: Array = []

func _init(author_id: String = "", content: String = "") -> void:
	self.author_id = author_id
	self.content = content
	self.timestamp = int(Time.get_unix_time_from_system())

func serialize() -> Dictionary:
	return {
		author = author_id,
		content = content,
		timestamp = timestamp,
		attachments = JSON.stringify(attachment_ids)
	}

func deserialize(data: Dictionary) -> Message:
	self.author_id = data.author
	self.content = data.content
	self.timestamp = data.timestamp
	self.attachment_ids = JSON.parse_string(data.attachments)

	return self
