extends CanvasLayer

const IGNORED_SETTINGS := ["label", "div", "btn", "note", "collapse"]
@export var SCHEMA_PATH: StringName = "res://settings/schema.cfg"
@export var USER_SETTINGS_PATH: StringName = "user://settings.cfg"

signal setting_updated(category: String, property_name: String, new_value: Variant)
signal button_pressed(category: String, property_name: String)
signal setting_init(property_name: String, node: Control)

var schema := {}
var settings := ConfigFile.new()

@onready var ui: SettingsUI = $UI

func _ready() -> void:
	assert(FS.exists(SCHEMA_PATH), "Settings schema.cfg could not be found!")

	if HeadlessServer.is_headless_server:
		while not is_instance_valid(HeadlessServer.instance):
			await Lib.frame
		
		USER_SETTINGS_PATH = HeadlessServer.instance.server_data_path.path_join("client_settings.cfg")
	
	_init_schema()
	_load_settings()
	
	if has_node("ProjectSettingsManager"):
		get_node("ProjectSettingsManager").initialize()
	
	ui._build_interface()

func _load_settings() -> void:
	if USER_SETTINGS_PATH:
		if FS.exists(USER_SETTINGS_PATH):
			settings.load(USER_SETTINGS_PATH)
	_validate_settings_schema()

func _save_settings() -> void:
	if USER_SETTINGS_PATH:
		settings.save(USER_SETTINGS_PATH)

var _save_debouncer := Timer.new()
func _save_settings_debounced() -> void:
	if len(_save_debouncer.timeout.get_connections()) == 0:
		_save_debouncer.timeout.connect(_save_settings)
		add_child(_save_debouncer)
	
	_save_debouncer.start(3.0)

func _validate_settings_schema() -> void:
	for category in schema:
		for prop in schema[category]:
			if schema[category][prop].type in IGNORED_SETTINGS: continue
			
			if not settings.has_section(category) \
			or not settings.has_section_key(category, prop):
				settings.set_value(category, prop, schema[category][prop].default_value)

func _init_schema() -> void:
	var file := FileAccess.open(SCHEMA_PATH, FileAccess.READ)
	var lines := file.get_as_text().split("\n")
	
	var re_category := RegEx.create_from_string("\\[(.+)\\]")
	var re_setting := RegEx.create_from_string("(\\S+).?=")
	
	var current_category: String
	var current_setting: String
	
	for line in lines:
		var category = re_category.search(line)
		var setting = re_setting.search(line)
		
		if category:
			current_category = category.get_string(1)
			schema[current_category] = {}
		elif setting:
			var split := setting.get_string(1).split("_")
			current_setting = "_".join(split.slice(1))
			
			schema[current_category][current_setting] = {"type": split[0]}
			
			if split[0] == "collapse":
				schema[current_category][current_setting].is_collapse_begin = split[1] == "begin" or split[1] == "start"
			
			var value = _parse_prop(line.split("=")[1].strip_edges(), split[0], current_category)
			schema[current_category][current_setting].default_value = value
			 
			if not split[0] in IGNORED_SETTINGS:
				settings.set_value(current_category, current_setting, value)
		elif line.begins_with(";"):
			if not current_category or not current_setting: continue
			
			var split := line.split(";")[1].strip_edges().split("|")
			var type := split[0].strip_edges()
			var args: Array = Array(split).slice(1).map(func(str: String) -> String: return str.strip_edges())
			
			_process_schema_meta_entry(schema[current_category][current_setting], type, args)

func _process_schema_meta_entry(schema: Dictionary, type: String, args: Array = []) -> void:
	match type:
		"range":
			schema.range = Vector2(float(args[0]), float(args[1]))
		"if":
			schema.if_category = args[0]
			schema.if_property = args[1]
			schema.if_value = args[2]
		"step":
			schema.step = float(args[0])
		"enum_type":
			var enum_split = args[0].split(".")
			schema.enum_items = ClassDB.class_get_enum_constants(enum_split[0], enum_split[1])
		"enum_items":
			schema.enum_items = args
		"filter":
			schema.filter = args
		"disabled":
			schema.disabled = true
		_:
			var meta_line := "meta"
			var meta_idx := 1
			
			while meta_line in schema:
				meta_line = "meta_%s" % meta_idx
				meta_idx += 1
			
			schema[meta_line] = type

func _parse_prop(property: String, type: String, category: String) -> Variant:
	match type:
		"str", "label", "div", "btn", "note", "collapse":
			return property
		"flt":
			return float(property)
		"int", "enum":
			return int(property)
		"bool":
			return property.to_lower() == "true"
		"color":
			return Color(property)
		_:
			push_warning("Setting '%s' does not have a valid type. (%s)" % [property, type])
			return property

func _validate_value(category: String, property_name: String) -> bool:
	if not settings.has_section(category):
		if not OS.has_feature("standalone"):
			push_warning("No setting category named '%s'!" % category)
		return false
	if not settings.has_section_key(category, property_name):
		if not OS.has_feature("standalone"):
			push_warning("No setting named '%s' in category '%s'!" % [property_name, category])
		return false
	return true

func get_value(category: String, property_name: String) -> Variant:
	if not _validate_value(category, property_name):
		return null
	return settings.get_value(category, property_name)

func make_setting_link(category: String, property_name: String, object: Object, property_path: NodePath) -> Callable:
	if not _validate_value(category, property_name):
		return Callable()
	
	var callback: Callable
	callback = func(_category: String, _property_name: String, new_value: Variant) -> void:
		if not is_instance_valid(object):
			setting_updated.disconnect(callback)
			return
		
		if _category == category and _property_name == property_name:
			object.set_indexed(property_path, new_value)
	object.set_indexed(property_path, get_value(category, property_name))
	
	var disconnect_func := func() -> void: setting_updated.disconnect(callback)
	setting_updated.connect(callback)
	
	if object is Node:
		object.tree_exited.connect(func() -> void:
			if not is_instance_valid(get_tree()):
				return
			
			await get_tree().process_frame
			if is_instance_valid(object) and object.is_inside_tree(): return
			
			disconnect_func.call(),
			CONNECT_ONE_SHOT
		)
	
	return disconnect_func

func make_setting_link_method(category: String, property_name: String, callback: Callable, do_initial_call: bool = true) -> Callable:
	if not _validate_value(category, property_name):
		return Callable()
	
	var _callback = func(_category: String, _property_name: String, new_value: Variant) -> void:
		if _category == category and _property_name == property_name:
			callback.call(new_value)
	if do_initial_call:
		callback.call(get_value(category, property_name))
	
	setting_updated.connect(_callback)
	return func() -> void: setting_updated.disconnect(_callback)

func set_value(category: String, property_name: String, new_value: Variant) -> void:
	settings.set_value(category, property_name, new_value)
	setting_updated.emit(category, property_name, new_value)
	
	_save_settings_debounced()
