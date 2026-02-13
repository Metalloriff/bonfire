class_name User extends Resource

const PROPERTIES: Array[String] = [
	"id",
	"name",
	"avatar",
	"member_join_date_time"
]

@export var id: String
@export var name: String = "Invalid User"
@export var avatar: Texture = preload("res://icon.svg")

@export var member_join_date_time: String = "Invalid Date"

func save() -> void:
	if not HeadlessServer.is_headless_server:
		return
	
	var USERS_PATH: String = "%s/users" % HeadlessServer.instance.server_data_path
	FS.mkdir(USERS_PATH)

	ResourceSaver.save(self , "%s/%s.res" % [USERS_PATH, id])