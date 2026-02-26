extends Control

var existing_channel: Channel

@onready var type_dropdown: OptionButton = %Type

func _ready() -> void:
	for channel_type in Channel.CHANNEL_TYPE_TITLES:
		type_dropdown.add_icon_item(Channel.CHANNEL_TYPE_ICONS[channel_type], Channel.CHANNEL_TYPE_TITLES[channel_type], channel_type)

	await Lib.frame

	if is_instance_valid(existing_channel):
		%Title.text = "Edit Channel"
		%CreateButton.text = "Save Changes"
		type_dropdown.selected = existing_channel.type
		%Name.text = existing_channel.name
		type_dropdown.disabled = true

func _on_cancel_button_pressed() -> void:
	ModalStack.fade_free_modal(self )

func _on_create_button_pressed() -> void:
	var name: String = %Name.text.strip_edges().strip_escapes()
	if not name:
		return

	if existing_channel:
		App.selected_server.send_api_message("edit_channel", {
			channel_id = existing_channel.id,
			name = name
		})
	else:
		var channel_type: int = type_dropdown.get_item_id(type_dropdown.selected)

		App.selected_server.send_api_message("create_channel", {
			channel_type = channel_type,
			name = name
		})

	ModalStack.fade_free_modal(self )

func _on_type_item_selected(index: int) -> void:
	var channel_type: int = type_dropdown.get_item_id(index)

	%Description.text = Channel.CHANNEL_TYPE_DESCRIPTIONS[channel_type]
