@tool
extends EditorExportPlugin

const BLACKLIST: PackedStringArray = [
	"bonfire.console.exe",
	"bonfire.sh"
]

func _export_end() -> void:
	var project_path: String = ProjectSettings.globalize_path("res://")
	var export_path: String = get_export_preset().get_export_path()
	var package_path: String = project_path.path_join(export_path).get_base_dir()
	var final_path: String = package_path.get_base_dir()

	prints("package_path", package_path)
	
	match package_path.get_file():
		"android":
			for file in DirAccess.get_files_at(package_path):
				if file.get_extension() == "apk":
					var apk_path: String = package_path.path_join(file)
					DirAccess.copy_absolute(apk_path, final_path.path_join("bonfire-android.apk"))
		"linux", "windows":
			var zip: ZIPPacker = ZIPPacker.new()
			zip.open(
				final_path.path_join("bonfire-linux.zip" if package_path.get_file() == "linux" \
				else "bonfire-windows.zip")
			)
			
			for file in DirAccess.get_files_at(package_path):
				if file in BLACKLIST:
					continue
				
				zip.start_file(file)
				zip.write_file(FileAccess.get_file_as_bytes(package_path.path_join(file)))
				zip.close_file()
			
			zip.close()
