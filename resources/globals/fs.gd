extends Node

var _cache = {}

func _init() -> void:
	_handle_recursive_caching()

func _handle_recursive_caching(path: String = "res://") -> void:
	# prevent caching of addon paths that never need to be accessed
	if "res://addons" in path: return
	# prevent circular imports
	if path in _cache: return
	
	_cache_directory(path)
	
	if not path in _cache: return
	
	for directory in _cache[path].directories:
		_handle_recursive_caching(path.path_join(directory))

func _cache_directory(path: String) -> Dictionary:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		#print("Directory not found! Directory: " + path)
		return {
			"directories": [],
			"files": []
		}
	
	dir.list_dir_begin()
	
	var _files: PackedStringArray = dir.get_files()
	var files: Array[String] = []
	
	for file_name in _files:
		if file_name.get_extension() == "uid": continue
		files.append(file_name.replace(".import", "").replace(".remap", ""))
	
	dir.list_dir_end()
	
	if path in _cache:
		_cache[path].directories += dir.get_directories()
		_cache[path].files += files
	else:
		_cache[path] = {
			"directories": dir.get_directories(),
			"files": files
		}
	
	return _cache[path]

func exists(path: String) -> bool:
	if path.get_base_dir() in _cache and path.get_file() in get_files(path.get_base_dir()):
		return true
	return path in _cache or FileAccess.file_exists(path)

func mkdir(path: String):
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

#func mkdir_recursive(path: String) -> void:
	#var path_root: String = path.split("://")[0] + "://"
	#var path_bits: PackedStringArray = path.split("://")[1].split("/")
	#var current_path: String = path_root
	#
	#for path_bit in path_bits:
		#current_path = current_path.path_join(path_bit)
		#if not DirAccess.dir_exists_absolute(current_path):
			#DirAccess.make_dir_recursive_absolute()

func get_files(path: String, use_cache: bool = true) -> Array:
	var files: Array = []
	
	if not use_cache or path not in _cache:
		files = _cache_directory(path).files
	else:
		files = _cache[path].files
	
	return files

func get_files_recursive(path: String, use_cache: bool = true) -> Array:
	if not DirAccess.dir_exists_absolute(path): return []
	
	var files: Array = []
	
	if "user://" in path:
		use_cache = false
	
	if use_cache:
		_handle_recursive_caching(path)
		
		if not path in _cache:
			return []
		
		for dir in _cache[path].directories:
			files += get_files_recursive(path.path_join(dir), use_cache)
		for file in _cache[path].files:
			files.append(path.path_join(file))
	else:
		var dir := DirAccess.open(path)
		if not dir: return []
		
		dir.list_dir_begin()
		for file_name in dir.get_files():
			if file_name.get_extension() == "uid": continue
			files.append(path.path_join(file_name.replace(".import", "").replace(".remap", "")))
		dir.list_dir_end()
		
		for file_path in dir.get_directories():
			files += get_files_recursive(path.path_join(file_path), use_cache)
	
	return files

func get_directories(path: String, use_cache: bool = true):
	var dirs = []
	
	if not use_cache or path not in _cache:
		dirs = _cache_directory(path).directories
	else:
		dirs = _cache[path].directories
	
	return dirs

func ls(path: String, use_cache: bool = true):
	if not use_cache or path not in _cache:
		return _cache_directory(path)
	else:
		return _cache[path]

func save_data(path: String, data: Variant):
	if "contains_errors" in data and data.contains_errors == true:
		print("Warning! Not saving data at ", path, " because it contains errors from previous load!")
		return
	
	path = "user://" + path
	var dir = path.split("/")
	var file_name = dir[-1]
	dir.remove_at(len(dir) - 1)
	FS.mkdir("/".join(dir))
	
	if "." not in file_name:
		path += ".json"
	
	var save = FileAccess.open(path, FileAccess.WRITE)
	save.store_line(JSON.stringify(data))
	save.close()

func load_data(path: String, default: Variant = {}):
	path = "user://" + path
	var dir = path.split("/")
	var file_name = dir[-1]
	dir.remove_at(len(dir) - 1)
	FS.mkdir("/".join(dir))
	
	if "." not in file_name:
		path += ".json"
	
	if not FileAccess.file_exists(path):
		return default
	
	var save = FileAccess.open(path, FileAccess.READ)
	var json_string = save.get_line()
	save.close()
	
	var json = JSON.new()
	var result = json.parse(json_string)
	
	if result != OK:
		print("Error loading save data at ", path)
		print("JSON parse error: ", json.get_error_message())
		print("JSON data: ", json_string)
		
		default.merge({
			"contains_errors": true
		})
		
		return default
	return json.get_data()

var _prefs_cache: Dictionary = {}

func get_pref(prop_name: String, default_value: Variant = null, save_if_default: bool = false) -> Variant:
	if HeadlessServer.is_headless_server:
		return default_value

	var split = prop_name.split(".")
	var file_name = split[0] if len(split) > 1 else "prefs"
	var pref_name = split[1] if len(split) > 1 else split[0]
	
	var data = _prefs_cache[file_name] if file_name in _prefs_cache else load_data("prefs/" + file_name)
	
	if pref_name in data:
		return data[pref_name]
	else:
		if save_if_default:
			set_pref(prop_name, default_value)
		
		return default_value

func set_pref(prop_name: String, value: Variant) -> void:
	var split = prop_name.split(".")
	var file_name = split[0] if len(split) > 1 else "prefs"
	var pref_name = split[1] if len(split) > 1 else split[0]
	
	var data = _prefs_cache[file_name] if file_name in _prefs_cache else load_data("prefs/" + file_name)
	data[pref_name] = value
	save_data("prefs/" + file_name, data)

func join_path(paths: Array[String]) -> String:
	var output = ""
	
	for path in paths:
		output += path if path.ends_with("/") or path == paths[-1] else (path + "/")
	
	return output
