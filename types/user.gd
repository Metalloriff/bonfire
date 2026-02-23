class_name User extends Resource

static var LOCAL_USER_PATH: String = "user://local_main_user.res"
static var local_main_user: User:
	get:
		if not local_main_user and ResourceLoader.exists(LOCAL_USER_PATH):
			return load(LOCAL_USER_PATH)
		return null

const PROPERTIES: Array[String] = [
	"id",
	"name",
	"avatar",
	"member_join_date_time"
]

@export var id: String
@export var name: String = "Invalid User"
@export var display_name: String
@export var avatar: Texture
@export_multiline var bio: String
@export var tagline: String

@export var member_join_date_time: String = "Invalid Date"

var local_volume: float = -1.0:
	set(new):
		if local_volume != new:
			local_volume = new

			FS.get_pref("member_volumes.%s" % id, 100.0)
var local_soundboard_volume: float = -1.0:
	set(new):
		if local_soundboard_volume != new:
			local_soundboard_volume = new
			
			FS.set_pref("member_volumes.%s_soundboard" % id, new)

func _init() -> void:
	local_volume = FS.get_pref("member_volumes.%s" % id, 100.0)
	local_soundboard_volume = FS.get_pref("member_volumes.%s_soundboard" % id, 50.0)

func is_online_in_server(server: Server) -> bool:
	for peer_id: int in server.online_users:
		if server.online_users[peer_id] == id:
			return true
	return false

func get_direct_message_channel(server: Server) -> Channel:
	for channel in server.private_channels:
		var found_users: int = 0

		for participant in channel.pm_participants:
			if participant.user_id == id or participant.user_id == server.user_id:
				found_users += 1
		
		if found_users == 2:
			return channel
	return null

# func save() -> void:
# 	assert(HeadlessServer.is_headless_server, "Cannot save user as a client")
	
# 	var USERS_PATH: String = "%s/users" % HeadlessServer.instance.server_data_path
# 	FS.mkdir(USERS_PATH)

# 	ResourceSaver.save(self , "%s/%s.res" % [USERS_PATH, id])

# static func load_from_disk(user_id: String) -> User:
# 	assert(HeadlessServer.is_headless_server, "Cannot load user from disk as a client")
	
# 	var path: String = "%s/users/%s.res" % [HeadlessServer.instance.server_data_path, user_id]
# 	return load(path) if FileAccess.file_exists(path) else null