class_name Media extends Resource

@export var id: int
@export var media_id: String = Lib.create_uid(32)
@export var encrypted: bool
@export var file_name: String
@export var ext: String
@export var md5: String
@export var size: int
@export var message_id: int = -1
@export var uploader_id: String

var decryption_key: String

func serialize() -> Dictionary:
	return {
		media_id = media_id,
		encrypted = encrypted,
		file_name = file_name,
		ext = ext,
		md5 = md5,
		size = size,
		message_id = message_id,
		uploader_id = uploader_id
	}

func deserialize(data: Dictionary) -> Media:
	self.id = data.id if "id" in data else -1
	self.media_id = data.media_id
	self.encrypted = data.encrypted if "encrypted" in data else false
	self.file_name = data.file_name if "file_name" in data else ""
	self.ext = data.ext
	self.md5 = data.md5 if "md5" in data else ""
	self.size = data.size
	self.message_id = data.message_id if "message_id" in data else -1
	self.uploader_id = data.uploader_id if "uploader_id" in data else ""

	return self
