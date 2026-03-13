class_name PushNotificationServer extends Node
static var instance: PushNotificationServer

var port: int = 26970
var server: Server

var _tcp_server: TCPServer
var _peers: Array[WebSocketPeer]

func _ready() -> void:
	instance = self

	_tcp_server = TCPServer.new()
	var err := _tcp_server.listen(port)
	if err != OK:
		print("Failed to start notification websocket server! Error: %s" % error_string(err))
		set_process(false)
		return
	
	print("NOTIFICATION_WS_SERVER: Started on port %d" % port)

func _process(_delta: float) -> void:
	while _tcp_server.is_connection_available():
		print("NOTIFICATION_WS_SERVER: New connection")
		var ws := WebSocketPeer.new()
		ws.accept_stream(_tcp_server.take_connection())
		_authenticate(ws)
	
	for peer in _peers:
		peer.poll()

		var state: int = peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			pass
		elif state == WebSocketPeer.STATE_CLOSED:
			print("NOTIFICATION_WS_SERVER: Peer '%s' closed" % peer.get_meta("user_id"))
			_peers.erase(peer)

func _authenticate(ws: WebSocketPeer) -> void:
	var timeout: float = 0.0
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		ws.poll()
		timeout += await Lib.frame_with_delta()

		if timeout > 5.0:
			print("NOTIFICATION_WS_SERVER: Failed to authenticate peer! Reason: Timeout")
			ws.close()
			return
	
	while ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify({type = "handshake"}))

		ws.poll()
		timeout += await Lib.frame_with_delta()

		if timeout > 5.0:
			print("NOTIFICATION_WS_SERVER: Failed to authenticate peer! Reason: Timeout")
			ws.close()
			return
		
		while ws.get_available_packet_count():
			var packet: PackedByteArray = ws.get_packet()
			if not ws.was_string_packet():
				print("NOTIFICATION_WS_SERVER: Failed to authenticate peer! Reason: Peer tried to send a non-string packet")
				ws.close()
				return
			
			var data: Dictionary = JSON.parse_string(packet.get_string_from_utf8())
			if not "username" in data or not "password_hash" in data or not data.username or not data.password_hash:
				print("NOTIFICATION_WS_SERVER: Failed to authenticate peer! Reason: Peer sent invalid data")
				ws.close()
				return

			var user_id: String = (data.username + ":" + data.password_hash).sha256_text()
			var user: User = server.get_user(user_id)
			if not is_instance_valid(user):
				print("NOTIFICATION_WS_SERVER: Failed to authenticate peer! Reason: No valid user found with ID '%s'" % user_id)
				ws.close()
				return
			
			print("NOTIFICATION_WS_SERVER: Authenticated peer '%s'" % user_id)
			
			ws.set_meta("user_id", user_id)
			_peers.append(ws)
			return

func _get_user_peers(user_id: String) -> Array[WebSocketPeer]:
	var peers: Array[WebSocketPeer] = []
	for peer in _peers:
		if not is_instance_valid(peer):
			continue
		
		if peer.get_meta("user_id") == user_id:
			peers.append(peer)
	return peers

static func send_push_notification(user_id: String, title: String, body: String) -> void:
	if not is_instance_valid(instance):
		print("NOTIFICATION_WS_SERVER: Cannot send push notification as a client")
		return
	var peers: Array[WebSocketPeer] = instance._get_user_peers(user_id)
	if not len(peers):
		print("NOTIFICATION_WS_SERVER: User not found, User ID: %s" % user_id)
		return

	for peer in peers:
		if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			print("NOTIFICATION_WS_SERVER: Peer not ready, User ID: %s" % user_id)
			continue
		
		peer.send_text(JSON.stringify({
			type = "notification",
			notif_type = "",
			title = title,
			body = body
		}))
