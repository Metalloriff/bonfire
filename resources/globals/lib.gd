extends Node

signal input_method_changed

var input_controller: bool = false:
	set(new):
		if input_controller != new:
			input_controller = new
			
			input_method_changed.emit()

func create_uid(length: int = 7) -> String:
	const characters := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	var id := ""
	
	for i in range(length):
		id += characters.substr(randi() % len(characters), 1)
	
	return id

func construct(input: Variant, properties: Dictionary) -> Variant:
	for prop_name in properties:
		if prop_name in input:
			input[prop_name] = properties[prop_name]
		else:
			push_warning("Lib.construct error: Invalid property name '%s' in " % prop_name, input)
	return input

func find_child_nodes(parent_node: Node, condition: Variant = null, include_self: bool = false) -> Array[Node]:
	if not is_instance_valid(parent_node):
		return []
	
	var nodes: Array[Node] = []
	var children := parent_node.get_children()
	
	if include_self and (not condition or condition.call(parent_node)):
		nodes.append(parent_node)
	
	for child in children:
		if not condition or condition.call(child):
			nodes.append(child)
		
		if child.get_child_count() > 0:
			nodes += find_child_nodes(child, condition)
	
	return nodes

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		input_controller = true
	if event is InputEventMouseButton or event is InputEventKey:
		input_controller = false

func clear_child_nodes(parent_node: Node, instant: bool = false) -> void:
	for node in parent_node.get_children():
		if instant:
			node.free()
		else:
			node.queue_free()

func coalesce(a: Variant, b: Variant) -> Variant:
	return a if is_instance_valid(a) else b

var _debouncers: Dictionary
func debounce(time_seconds: float, callback: Callable) -> void:
	if callback in _debouncers:
		_debouncers[callback].start(time_seconds)
	else:
		var timer := Timer.new()
		
		timer.autostart = true
		timer.one_shot = true
		timer.wait_time = time_seconds
		
		timer.timeout.connect(func() -> void:
			_debouncers.erase(callback)
			timer.queue_free()
		)
		
		timer.timeout.connect(callback)
		add_child(timer)
		
		_debouncers[callback] = timer

var _debouncer_ids: Dictionary
func create_debouncer(time_seconds: float, callback: Callable, id: String = create_uid()) -> Callable:
	if not id in _debouncer_ids:
		var timer := Timer.new()
		
		timer.one_shot = true
		timer.wait_time = time_seconds
		timer.one_shot = true
		
		timer.timeout.connect(callback)
		add_child(timer)
		
		_debouncer_ids[id] = func() -> void:
			timer.start(time_seconds)
	return _debouncer_ids[id]

func measure_usec(method: Callable) -> int:
	var s := Time.get_ticks_usec()
	method.call()
	return Time.get_ticks_usec() - s

func measure_msec(method: Callable, times: int = 1) -> int:
	var s := Time.get_ticks_usec()
	
	for i in times:
		method.call()
	
	return Time.get_ticks_usec() - s

@rpc("any_peer", "call_local")
func play_audio(path: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	var aud := AudioStreamPlayer.new()
	aud.stream = load(path)
	aud.autoplay = true
	aud.volume_db = volume_db
	aud.finished.connect(func() -> void: aud.queue_free())
	
	get_tree().current_scene.add_child(aud)
	return aud

@rpc("any_peer", "call_local")
func play_audio_at_position(position: Vector3, path: String, distance: float = 20.0) -> AudioStreamPlayer3D:
	var aud := AudioStreamPlayer3D.new()
	aud.stream = load(path)
	aud.unit_size = distance
	aud.autoplay = true
	aud.finished.connect(func() -> void: aud.queue_free())
	
	get_tree().current_scene.add_child(aud)
	aud.global_position = position
	return aud

var frame: Signal:
	get: return Engine.get_main_loop().process_frame

func seconds(seconds: float) -> Signal:
	return Engine.get_main_loop().create_timer(seconds).timeout

func frame_with_delta() -> float:
	var start: float = float(Time.get_ticks_msec()) / 1000.0
	await frame
	var end: float = float(Time.get_ticks_msec()) / 1000.0
	
	return end - start

func condition(condition_check: Callable, check_rate_seconds: float = 0.0) -> void:
	if condition_check.call() != true:
		var recall: Callable = func(): condition(condition_check, check_rate_seconds)
		
		if check_rate_seconds > 0.0:
			await seconds(check_rate_seconds)
		else:
			await frame
		
		if not is_instance_valid(condition_check):
			return
		await condition(condition_check, check_rate_seconds)

func validate(objects_to_validate: Array) -> bool:
	for obj in objects_to_validate:
		if not is_instance_valid(obj):
			return false
	return true

func validate_properties(object: Object, properties: PackedStringArray) -> bool:
	if not is_instance_valid(object):
		return false
	
	for prop: String in properties:
		if not prop in object or not is_instance_valid(object[prop]):
			return false
	
	return true

func get_indexed_fixed(node: Node, path: NodePath) -> Variant:
	var node_path := str(path.get_concatenated_names())
	var index_path := str(path.get_concatenated_subnames())
	
	if node_path:
		node = node.get_node_or_null(node_path)
	return node.get_indexed(index_path) if is_instance_valid(node) else null

func set_indexed_fixed(node: Node, path: NodePath, value: Variant) -> void:
	var node_path := str(path.get_concatenated_names())
	var index_path := str(path.get_concatenated_subnames())
	
	if node_path:
		node = node.get_node_or_null(node_path)
	if is_instance_valid(node):
		node.set_indexed(index_path, value)

func set_owner_recursive(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	
	for child in node.get_children():
		set_owner_recursive(child, new_owner)

func clear_signals(sig: Signal) -> void:
	for connection in sig.get_connections():
		sig.disconnect(connection.callable)

func create_timer(target_node: Node, callback: Callable, wait_time: float, one_shot: bool = false) -> Timer:
	var timer := Timer.new()
	timer.autostart = true
	timer.wait_time = wait_time
	timer.timeout.connect(callback)
	timer.one_shot = one_shot
	target_node.add_child(timer)
	return timer

func _ready() -> void:
	if OS.has_feature("editor"):
		var output: Array
		var exit_code: int = OS.execute("git", ["rev-parse", "--short", "HEAD"], output)
		
		# if exit_code == 0:
		# 	var build_version: String = output[0].split("\n")[0]
			
		# 	if ProjectSettings.get_setting("application/config/version") != build_version:
		# 		ProjectSettings.set_setting("application/config/version", build_version)
		# 		ProjectSettings.save()