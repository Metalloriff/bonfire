extends Timer

signal update_available(data)

@onready var _check_debounced: Callable = Lib.create_debouncer(3.0, check_for_updates)

func _ready() -> void:
	if OS.has_feature("editor"):
		return
	if HeadlessServer.is_headless_server:
		return

	Settings.make_setting_link_method("system", "automatically_check_for_updates", func(auto_update: bool) -> void:
		if auto_update:
			_check_debounced.call()
	)

	Settings.make_setting_link_method("system", "include_prereleases", func(include_prereleases: bool) -> void:
		if Settings.get_value("system", "automatically_check_for_updates"):
			_check_debounced.call()
	)

	_check_debounced.call()
	timeout.connect(_check_debounced)

func check_for_updates() -> void:
	if not Settings.get_value("system", "automatically_check_for_updates") and not HeadlessServer.is_headless_server:
		return
	
	print("Checking for updates...")

	var latest_release_data: Dictionary = await _get_latest_release_data()
	if not latest_release_data:
		return
	
	var current_version: SemanticVersion = SemanticVersion.new(ProjectSettings.get_setting("application/config/version"))
	var latest_version: SemanticVersion = SemanticVersion.new(latest_release_data.tag_name)
	
	if latest_version.is_newer_than(current_version):
		print("Update available.")
		
		update_available.emit(latest_release_data)
		var modal = ModalStack.open_modal("res://interface/modals/update_modal.tscn")
		modal.update_data = latest_release_data

func _get_latest_release_data() -> Dictionary:
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = 5.0
	add_child(req)

	req.request("https://api.github.com/repos/metalloriff/bonfire/releases")
	var response = await req.request_completed

	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		prints("Failed to get latest release data from GitHub:", response[0], response[1])
		return {}
	
	var data: Array = JSON.parse_string(response[3].get_string_from_utf8())
	prints("response data", data)

	if Settings.get_value("system", "include_prereleases"):
		return data[0]
	else:
		for release in data:
			if not "prerelease" in release or release.prerelease == false:
				return release
		return {}

class SemanticVersion:
	var major: int
	var minor: int
	var patch: int
	
	func _init(string: String) -> void:
		var parts: Array = string.split(".")
		
		if len(parts) != 3:
			return
		
		for part in parts:
			var regex: RegEx = RegEx.new()
			regex.compile("\\D")
			part = regex.sub(part, "")
		
		major = int(parts[0])
		minor = int(parts[1])
		patch = int(parts[2])
	
	func is_newer_than(other: SemanticVersion) -> bool:
		if major > other.major:
			return true
		elif major == other.major and minor > other.minor:
			return true
		elif major == other.major and minor == other.minor and patch > other.patch:
			return true
		
		return false
	
	func _to_string() -> String:
		return "%d.%d.%d" % [major, minor, patch]
