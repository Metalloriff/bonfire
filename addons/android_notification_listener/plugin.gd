@tool
extends EditorPlugin

var export_plugin: AndroidNotificationListenerExportPlugin

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	export_plugin = AndroidNotificationListenerExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null

class AndroidNotificationListenerExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME: String = "NotificationListener"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid
	
	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["res://addons/android_notification_listener/lib.aar"])
	
	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([])
	
	func _get_name() -> String:
		return PLUGIN_NAME
