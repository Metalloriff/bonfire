extends ContextMenu

var server: Server

func _ready() -> void:
	%ReOrderMode.button_pressed = ChannelList.instance.re_order_mode

func _on_create_channel_button_pressed() -> void:
	ModalStack.open_modal("res://interface/modals/create_channel_modal.tscn")
	fade_free()

func _on_re_order_mode_toggled(toggled_on: bool) -> void:
	ChannelList.instance.re_order_mode = toggled_on
	ChannelList.instance.queue_redraw()
