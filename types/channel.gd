class_name Channel extends Resource

enum Type {
	TEXT,
	VOICE,
	MEDIA,
}

@export var id: String = Lib.create_uid(32)
@export var name: String = "Invalid Channel"
@export var type: int = Type.TEXT

var server: Server
var messages: Array[Message] = []