class_name InAppServer extends Node

signal on_std_line(line: String, error: bool)

var pid: int = -1
var thread: Thread
var server_id: String

var stdio: FileAccess
var stderr: FileAccess
var running: bool

@onready var ipc_private_key: String = EncryptionTools.generate_token().sha256_text()

func _ready() -> void:
	thread = Thread.new()
	thread.start(_run)

	var heartbeat_timer: Timer = Timer.new()
	heartbeat_timer.wait_time = 1.0
	heartbeat_timer.autostart = true
	heartbeat_timer.timeout.connect(func() -> void:
		if not running or not server_id:
			return
		
		var server: Server = Server.get_server(server_id)
		if not is_instance_valid(server) or not is_instance_valid(server.com_node):
			return
		if not server.com_node.local_multiplayer.multiplayer_peer or server.com_node.local_multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return
		
		server.send_api_message("ipc_msg", {
			pk = ipc_private_key,
			type = "heartbeat"
		})
	)
	add_child(heartbeat_timer)

func _run() -> void:
	var executable_path: String = OS.get_executable_path()
	var args: Array = ["--headless"] + Array(OS.get_cmdline_user_args()) + ["--server", "--ipc-private-key=%s" % ipc_private_key]

	if OS.has_feature("editor"):
		args = ["--path %s" % ProjectSettings.globalize_path("res://")] + args

	var info: Dictionary = OS.execute_with_pipe(executable_path, args)
	
	stdio = info.stdio
	stderr = info.stderr
	pid = info.pid

	running = true
	
	while stdio.is_open() and stdio.get_error() == OK:
		var lines: PackedStringArray = []
		var errors: PackedStringArray = []

		while stdio.get_position() < stdio.get_length():
			var line: String = stdio.get_line()

			if line.begins_with("IPC_SERVER_ID_SIG="):
				server_id = line.split("=", false)[1]

			lines.append(line)
		
		while stderr.get_position() < stderr.get_length():
			var line: String = stderr.get_line()
			errors.append(line)

		for line in lines:
			if line:
				on_std_line.emit.call_deferred(line, false)
		
		for line in errors:
			if line:
				on_std_line.emit.call_deferred(line, true)
		
		if not len(lines) and not len(errors):
			OS.delay_msec(100)
	
	running = false
