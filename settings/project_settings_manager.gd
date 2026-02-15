extends Node

func initialize() -> void:
	# Audio
	Settings.make_setting_link_method("audio", "master_volume", func(volume_percent: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(volume_percent / 100.0)))
	
	# Video
	Settings.make_setting_link_method("video", "fullscreen", func(fs: bool) -> void: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_MAXIMIZED))
	Settings.make_setting_link("video", "max_framerate", Engine, "max_fps")
	Settings.make_setting_link("video", "render_resolution", get_viewport(), "scaling_3d_scale")
	Settings.make_setting_link_method("video", "vsync_enabled", func(enabled: bool) -> void: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED))
	Settings.make_setting_link("video", "msaa", get_viewport(), "msaa_3d")
