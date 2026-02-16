extends Control
class_name SettingsUI

signal interface_updated

@onready var tabs: TabContainer = %TabContainer
@onready var settings_page: MarginContainer = _inst(%SettingsPage)
@onready var reset_button: Button = _inst(%ResetButton)
@onready var input_picker_modal: Control = _inst(%InputPickerModal)

@onready var div_item: MarginContainer = _inst(%DivItem)
@onready var bool_item: HBoxContainer = _inst(%BoolItem)
@onready var flt_item: HBoxContainer = _inst(%FltItem)
@onready var int_item: HBoxContainer = _inst(%IntItem)
@onready var enum_item: HBoxContainer = _inst(%EnumItem)
@onready var color_item: HBoxContainer = _inst(%ColorItem)
@onready var str_item: HBoxContainer = _inst(%StrItem)
@onready var file_item: HBoxContainer = _inst(%FileItem)
@onready var avatar_item: HBoxContainer = _inst(%AvatarItem)
@onready var bind_item: HBoxContainer = _inst(%BindItem)
@onready var note_item: RichTextLabel = _inst(%NoteItem)

@onready var settings := get_parent()

var is_open: bool
var is_transitioning: bool

var _collapse_parent: Control

func _inst(node: Node) -> Node:
	var _node := node.duplicate()
	_node.show()
	node.queue_free()
	return _node

func _ready() -> void:
	modulate.a = 0.0
	mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
	hide()

func _input(event: InputEvent) -> void:
	if not is_open: return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()

func open() -> void:
	if is_transitioning: return
	is_transitioning = true
	
	show()
	settings.visible = true
	settings.layer = 64
	mouse_filter = MOUSE_FILTER_STOP
	
	is_open = true
	
	ModalStack._fade_out_modal(App.instance)
	ModalStack._fade_out_modal(self , 0.0)
	await ModalStack._fade_in_modal(self )
	is_transitioning = false

func close() -> void:
	if is_transitioning: return
	is_transitioning = true
	
	is_open = false
	
	ModalStack._fade_in_modal(App.instance)
	await ModalStack._fade_out_modal(self )

	scale = Vector2.ZERO
	is_transitioning = false
	settings.visible = false
	settings.layer = -128
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()

func _create_field(category: Node, item: Node, prop_name: String, setting: Dictionary) -> Node:
	var node := item.duplicate()
	node.name = prop_name
	
	if is_instance_valid(_collapse_parent):
		_collapse_parent.add_child(node)
	else:
		category.get_node("MarginContainer/ScrollContainer/Items").add_child(node)
	
	if "meta" in setting:
		node.tooltip_text = setting.meta
	if "disabled" in setting:
		node.mouse_filter = MOUSE_FILTER_IGNORE
		node.modulate.a = 0.25
	
	if node.has_node("Label"):
		node.get_node("Label").text = " ".join(prop_name.split("_")).capitalize()
	
	settings.setting_init.emit(prop_name, node)
	
	return node

func _handle_value_change(category: String, property: String, new_value: Variant, node: Node) -> void:
	var prop = settings.schema[category][property]
	
	if new_value != prop.default_value:
		if not node.has_node("ResetButton"):
			var button: Button = reset_button.duplicate()
			button.name = "ResetButton"
			node.add_child(button)
			node.move_child(button, 0)
			
			button.pressed.connect(func() -> void:
				settings.set_value(category, property, prop.default_value)
				await get_tree().process_frame
				_build_interface()
			)
			
			button.tooltip_text = "Reset to default"
	elif node.has_node("ResetButton"):
		node.get_node("ResetButton").queue_free()
	
	if settings.get_value(category, property) != new_value:
		settings.set_value(category, property, new_value)

func _build_interface() -> void:
	var previously_selected: int = tabs.current_tab
	
	for child: Node in tabs.get_children():
		child.free()
	
	for category: String in settings.schema:
		var category_node := settings_page.duplicate()
		tabs.add_child(category_node)
		category_node.name = category.capitalize()
		
		for child: Node in category_node.get_node("MarginContainer/ScrollContainer/Items").get_children():
			child.queue_free()
		
		for property: String in settings.schema[category]:
			var setting: Dictionary = settings.schema[category][property]
			var value: Variant = settings.get_value(category, property)
			
			match setting.type:
				"collapse":
					if setting.is_collapse_begin:
						_collapse_parent = _create_field(category_node, VBoxContainer.new(), property, setting)
						
						var collapsible: VBoxContainer = _collapse_parent
						
						collapsible.visible = str(settings.get_value(setting.if_category, setting.if_property)) == setting.if_value
						
						if is_instance_valid(_collapse_parent):
							var callback := func(category_name, property_name, new_value) -> void:
								if category_name == setting.if_category and property_name == setting.if_property:
									collapsible.visible = str(new_value) == setting.if_value
							
							settings.setting_updated.connect(callback)
							collapsible.tree_exiting.connect(func() -> void:
								settings.setting_updated.disconnect(callback)
							)
					else:
						_collapse_parent = null
				"label", "div":
					var label: Label = _create_field(category_node, div_item, property, setting).get_node("Label")
					label.text = settings.schema[category][property].default_value
				"note":
					var item: RichTextLabel = _create_field(category_node, note_item, property, setting)
					item.text = settings.schema[category][property].default_value
				"btn":
					var button: Button = _create_field(category_node, Button.new(), property, setting)
					button.text = settings.schema[category][property].default_value
					button.pressed.connect(func() -> void: settings.button_pressed.emit(category, property))
				"bool":
					var check: CheckButton = _create_field(category_node, bool_item, property, setting).get_node("CheckButton")
					
					check.toggled.connect(func(new_value: bool) -> void: _handle_value_change(category, property, new_value, check.get_parent()))
					check.button_pressed = value
				"flt", "int":
					var node := _create_field(category_node, flt_item, property, setting)
					var slider: HSlider = node.get_node("HSlider")
					var spinbox: SpinBox = node.get_node("SpinBox")
					
					spinbox.min_value = -999999
					spinbox.max_value = 999999
					
					if "range" in setting:
						slider.min_value = setting.range.x
						slider.max_value = setting.range.y
						#spinbox.min_value = setting.range.x
						#spinbox.max_value = setting.range.y
					if setting.type == "int":
						slider.step = 1
						slider.rounded = true
						spinbox.step = 1
						spinbox.rounded = true
					if "step" in setting:
						slider.step = setting.step
						spinbox.step = setting.step
					
					slider.value_changed.connect(func(new_value: float) -> void:
						_handle_value_change(category, property, new_value, node)
						spinbox.set_value_no_signal(new_value)
					)
					
					spinbox.value_changed.connect(func(new_value: float) -> void:
						slider.value = new_value
					)
					
					slider.value = value
					spinbox.set_value_no_signal(value)
				"enum", "audioin", "audioout":
					var option: OptionButton = _create_field(category_node, enum_item, property, setting).get_node("OptionButton")
					var enum_items: PackedStringArray = setting.enum_items if "enum_items" in setting else []

					if setting.type == "audioin":
						enum_items = AudioServer.get_input_device_list()
						if not value:
							value = AudioServer.input_device
					elif setting.type == "audioout":
						enum_items = AudioServer.get_output_device_list()
						if not value:
							value = AudioServer.output_device
					
					for item in enum_items:
						option.add_item(" ".join(item.split("_")).capitalize())
					
					if setting.type in ["audioin", "audioout"]:
						option.item_selected.connect(func(new_value: int) -> void: _handle_value_change(category, property, enum_items[new_value], option.get_parent()))
						option.select(enum_items.find(value))
					else:
						option.item_selected.connect(func(new_value: int) -> void: _handle_value_change(category, property, new_value, option.get_parent()))
						option.select(value)
				"color":
					var picker: ColorPickerButton = _create_field(category_node, color_item, property, setting).get_node("ColorPickerButton")
					
					picker.color_changed.connect(func(new_color: Color) -> void: _handle_value_change(category, property, new_color, picker.get_parent()))
					picker.color = value
				"str":
					var field: LineEdit = _create_field(category_node, str_item, property, setting).get_node("LineEdit")
					
					field.text_changed.connect(func(new_value: String) -> void: _handle_value_change(category, property, new_value, field.get_parent()))
					field.text = value
				"file", "avatar":
					var field := _create_field(category_node, file_item if setting.type == "file" else avatar_item, property, setting)
					var dialog: FileDialog = field.get_node("FileDialog")
					
					if "filter" in setting:
						for filter in setting.filter:
							dialog.add_filter(filter)
					
					field.get_node("Button").pressed.connect(func() -> void: dialog.popup())
					
					dialog.file_selected.connect(func(file: String) -> void:
						_handle_value_change(category, property, file, field)

						if FileAccess.file_exists(file):
							var image: Image = Image.load_from_file(file)
							var texture: ImageTexture = ImageTexture.create_from_image(image)
							field.get_node("TextureRect").texture = texture
					)
					if value: dialog.current_path = value
				"bind":
					var field := _create_field(category_node, bind_item, property, setting)
					var button := _inst(field.get_node("Button"))
					
					if not InputMap.has_action(property):
						field.get_node("Label").text = "INVALID INPUT"
					
					var i := 0
					for event in InputMap.action_get_events(property):
						var btn := button.duplicate()
						
						var icon: InputIconTextureRect = btn.get_child(0)
						icon.action_name = property
						icon.event_index = i
						
						btn.pressed.connect(func() -> void:
							is_transitioning = true
							var modal := input_picker_modal.duplicate()
							add_child(modal)
							
							var ev: InputEvent = await modal.input_event
							
							if ev is InputEventKey:
								if ev.keycode == KEY_ESCAPE:
									get_tree().create_timer(0.1).timeout.connect(func() -> void: is_transitioning = false, CONNECT_ONE_SHOT)
									return
								
								if ev.keycode == KEY_BACKSPACE:
									InputMap.action_erase_event(property, event)
									_build_interface()
									
									settings.set_value(category, property, InputMap.action_get_events(property))
									
									is_transitioning = false
									
									return
							
							var events := InputMap.action_get_events(property)
							
							events[i] = ev
							
							InputMap.action_erase_events(property)
							
							for e in events:
								InputMap.action_add_event(property, e)
							
							event = ev
							settings.set_value(category, property, events)
							
							for ic in Lib.find_child_nodes(self , func(node: Node) -> bool: return node is InputIconTextureRect):
								if ic.action_name:
									ic._update()
							
							is_transitioning = false
						)
						
						field.add_child(btn)
						i += 1
					
					var btn := button.duplicate()
					
					btn.pressed.connect(func() -> void:
						is_transitioning = true
						var modal := input_picker_modal.duplicate()
						add_child(modal)
						
						var ev: InputEvent = await modal.input_event
						
						if ev is InputEventKey and ev.keycode == KEY_ESCAPE:
							get_tree().create_timer(0.1).timeout.connect(func() -> void: is_transitioning = false, CONNECT_ONE_SHOT)
							return
						
						InputMap.action_add_event(property, ev)
						settings.set_value(category, property, InputMap.action_get_events(property))
						
						_build_interface()
						is_transitioning = false
					)
					
					btn.get_child(0).texture = load("res://addons/awesome_input_icons/assets/keyboard and mouse vector/keyboard_plus.svg")
					
					field.add_child(btn)
	tabs.current_tab = previously_selected
	interface_updated.emit()
