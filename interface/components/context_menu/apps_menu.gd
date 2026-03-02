extends ContextMenu

func _ready() -> void:
	Tooltip.attach(%VoiceMessage, "Voice Message")
	Tooltip.attach(%QRCode, "Generate QR Code")
	Tooltip.attach(%CryptoAddress, "Crypto Request")

func _on_qr_code_pressed() -> void:
	var menu: ContextMenu = ContextMenu.create_menu(preload("res://interface/components/context_menu/qr_code_generator.tscn"))
	_position_menu(menu, %QRCode)

func _position_menu(menu: ContextMenu, button: Control) -> void:
	menu.global_position = button.global_position
	menu.global_position.x += button.size.x / 2.0
	menu.global_position.x -= menu.get_node("PanelContainer").size.x / 2.0
	menu.global_position.y -= menu.get_node("PanelContainer").size.y + 15.0

func _on_crypto_address_pressed() -> void:
	var menu: ContextMenu = ContextMenu.create_menu(preload("res://interface/components/context_menu/crypto_payment_generator.tscn"))
	_position_menu(menu, %CryptoAddress)
