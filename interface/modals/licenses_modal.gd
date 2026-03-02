extends Control

var licenses: Array[Array]

func _ready() -> void:
	await Lib.frame

	licenses.append(["bonfire", "res://LICENSE.md"])

	for file: String in FS.get_files_recursive("res://", false):
		if file.get_extension() == "md" and "license" in file.to_lower():
			var folder: String = file.get_base_dir().get_file()
			if not folder:
				continue
			
			licenses.append([folder, file])
	
	for license in licenses:
		var folder: String = license[0]
		var file: String = license[1]
		var data: String = FileAccess.get_file_as_string(file)

		var foldable: FoldableContainer = FoldableContainer.new()
		foldable.title = "%s: %s" % [folder.to_camel_case().replace("_", " ").capitalize(), file.get_file()]
		foldable.folded = true

		var margin_container: MarginContainer = MarginContainer.new()
		foldable.add_child(margin_container)

		var label: Label = Label.new()
		label.text = data
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		margin_container.add_child(label)

		foldable.add_child(margin_container)
		%VBoxContainer.add_child(foldable)
