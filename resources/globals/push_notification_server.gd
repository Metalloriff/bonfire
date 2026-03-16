class_name PushNotificationServer extends Node
static var instance: PushNotificationServer

var KEY_DB_PATH: String:
	get:
		if not KEY_DB_PATH:
			KEY_DB_PATH = HeadlessServer.instance.server_data_path.path_join("push_notification_keys.res")
		return KEY_DB_PATH
var EXECUTABLE_PATH: String:
	get:
		if not EXECUTABLE_PATH:
			if OS.has_feature("editor"):
				EXECUTABLE_PATH = ProjectSettings.globalize_path("res://dist/linux/ntfy/ntfy")
			else:
				EXECUTABLE_PATH = OS.get_executable_path().get_base_dir().path_join("ntfy").path_join("ntfy" if OS.get_name() == "Linux" else "ntfy.exe")
		return EXECUTABLE_PATH
var CONFIG_ARGS: Array[String]:
	get:
		if not CONFIG_ARGS:
			CONFIG_ARGS = [
				"-c", EXECUTABLE_PATH.get_base_dir().path_join("config.yml"),
				"-H", EXECUTABLE_PATH.get_base_dir().path_join("auth.db")
			]
		return CONFIG_ARGS

var server: Server
var port: int = 26970
var key_db: PushNotificationKeys = PushNotificationKeys.new()

var _pid: int = -1

func _ready() -> void:
	if not FileAccess.file_exists(EXECUTABLE_PATH):
		print("ERROR: ntfy executable not found at '%s'!" % EXECUTABLE_PATH)
		return
	
	var auth_path: String = EXECUTABLE_PATH.get_base_dir().path_join("auth.db")
	if FileAccess.file_exists(auth_path):
		DirAccess.remove_absolute(auth_path)
	
	var lck_path: String = EXECUTABLE_PATH.get_base_dir().path_join(".LCK")
	if FileAccess.file_exists(lck_path):
		OS.kill(int(FileAccess.get_file_as_string(lck_path)))
		DirAccess.remove_absolute(lck_path)
	
	if ResourceLoader.exists(KEY_DB_PATH):
		key_db = ResourceLoader.load(KEY_DB_PATH)
	
	_pid = OS.create_process(EXECUTABLE_PATH, [
		"serve",
		"--listen-http", ":%d" % port,
		"-p", "ro"
	] + CONFIG_ARGS)

	if _pid == -1:
		print("ERROR: Failed to start ntfy server!")
		return
	
	var lck_file: FileAccess = FileAccess.open(lck_path, FileAccess.WRITE)
	lck_file.store_string(str(_pid))
	lck_file.close()
	
	tree_exiting.connect(func() -> void:
		if _pid != -1:
			OS.kill(_pid)
			_pid = -1
	)
	
	instance = self

	await Lib.seconds(2.0)

	_initialize_auth()

func _initialize_auth() -> bool:
	var output: Array = []
	OS.set_environment("NTFY_PASSWORD", key_db.private_key)
	var exit_code: int = OS.execute(EXECUTABLE_PATH, ["user"] + CONFIG_ARGS + [
		"add", "--role=admin", "server"
	], output)

	prints(exit_code, output)

	if exit_code != 0:
		print("ERROR: Failed to initialize ntfy server auth!")
	OS.unset_environment("NTFY_PASSWORD")

	return exit_code == 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _pid != -1:
			OS.kill(_pid)
			_pid = -1

func update_key(user_id: String, key: String) -> void:
	key_db.keys[user_id] = key
	ResourceSaver.save(key_db, KEY_DB_PATH)

static func send_push_notification(user_id: String, title: String, body: String) -> void:
	if not is_instance_valid(instance):
		return
	
	var channel: String = user_id

	match channel:
		"public", "all", "announcements":
			pass
		_:
			channel = instance.key_db.keys[user_id]
			
			if not user_id in instance.key_db:
				return
	
	print("pub -t '%s' -m '%s' -p high -u server:%s http://localhost:%d/%s" % [
		title, body, instance.key_db.private_key, instance.port, channel
	])
	
	OS.execute(instance.EXECUTABLE_PATH, [
		"pub",
		"-t", title,
		"-m", body,
		"-p", "high",
		"-u", "server:%s" % instance.key_db.private_key,
		"http://localhost:%d/%s" % [instance.port, channel]
	])
