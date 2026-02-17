class_name User extends Resource

const PROPERTIES: Array[String] = [
	"id",
	"name",
	"avatar",
	"member_join_date_time"
]

@export var id: String
@export var name: String = "Invalid User"
@export var avatar: Texture

@export var member_join_date_time: String = "Invalid Date"

func _init() -> void:
	local_volume = FS.get_pref("member_volumes.%s" % id, 100.0)

var local_volume: float = -1.0:
	set(new):
		if local_volume != new:
			local_volume = new

			FS.get_pref("member_volumes.%s" % id, 100.0)

# func save() -> void:
# 	assert(HeadlessServer.is_headless_server, "Cannot save user as a client")
	
# 	var USERS_PATH: String = "%s/users" % HeadlessServer.instance.server_data_path
# 	FS.mkdir(USERS_PATH)

# 	ResourceSaver.save(self , "%s/%s.res" % [USERS_PATH, id])

# static func load_from_disk(user_id: String) -> User:
# 	assert(HeadlessServer.is_headless_server, "Cannot load user from disk as a client")
	
# 	var path: String = "%s/users/%s.res" % [HeadlessServer.instance.server_data_path, user_id]
# 	return load(path) if FileAccess.file_exists(path) else null