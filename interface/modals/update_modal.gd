extends Control

var update_data: Dictionary

@onready var update_downloader: HTTPRequest = $UpdateDownloader

func _ready() -> void:
	await Lib.frame

	%InstalledVersion.text = "installed: %s" % ProjectSettings.get_setting("application/config/version")
	%LatestVersion.text = "latest: %s" % update_data.tag_name
	%Body.text = update_data.body

func _on_install_pressed() -> void:
	if OS.get_name() == "Android":
		NotificationDaemon.show_toast("Android in-app updates are not yet supported.")
		return
	
	for asset in update_data.assets:
		if OS.get_name().to_lower() in asset.name.to_lower():
			_install_asset(asset)

func _install_asset(asset: Dictionary) -> void:
	%UpdateContainer.show()
	%ButtonContainer.hide()

	%ProgressBar.max_value = asset.size

	var url: String = asset.browser_download_url
	update_downloader.download_file = "user://%s" % url.get_file()

	update_downloader.request(url)
	var response = await update_downloader.request_completed

	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		NotificationDaemon.show_toast("Failed to download update.")
		return
	
	var pck_file: String = ""

	for file in DirAccess.get_files_at(OS.get_executable_path().get_base_dir()):
		if file.get_extension() == "pck":
			pck_file = file
			break
	
	if not pck_file or OS.has_feature("editor"):
		NotificationDaemon.show_toast("Failed to find PCK file.")
		return
	
	DirAccess.remove_absolute(pck_file)
	var zreader: ZIPReader = ZIPReader.new()
	zreader.open(update_downloader.download_file)

	var root_dir: String = OS.get_executable_path().get_base_dir()
	for fp in zreader.get_files():
		if fp.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(root_dir.path_join(fp))
			continue
		
		DirAccess.make_dir_absolute(root_dir.path_join(fp.get_base_dir()))
		var file: FileAccess = FileAccess.open(root_dir.path_join(fp), FileAccess.WRITE)
		if file:
			file.store_buffer(zreader.read_file(fp))
			file.close()
		else:
			push_error("Failed to open file '%s' for writing. This is likely normal if it is the executable or a DLL file." % fp)
	zreader.close()
	
	OS.create_process(OS.get_executable_path(), [])
	await Lib.frame
	get_tree().quit()

func _on_skip_update_pressed() -> void:
	FS.set_pref("skipped_version", update_data.tag_name)
	ModalStack.fade_free_modal(self )

func _on_close_pressed() -> void:
	ModalStack.fade_free_modal(self )

func _on_cancel_update_button_pressed() -> void:
	%UpdateContainer.hide()
	%ButtonContainer.show()

	update_downloader.cancel_request()

func _process(_delta: float) -> void:
	if %UpdateContainer.visible:
		%ProgressBar.value = update_downloader.get_downloaded_bytes()
