extends Control

var server: Server

func _on_public_sub_button_pressed() -> void:
	OS.shell_open("ntfy://%s:%d/public?secure=false&display=%s" % [server.address, 26970, ("%s: Public" % server.name).uri_encode()])

func _on_announcements_sub_button_pressed() -> void:
	OS.shell_open("ntfy://%s:%d/announcements?secure=false&display=%s" % [server.address, 26970, ("%s: Announcements" % server.name).uri_encode()])

func _on_private_sub_button_pressed() -> void:
	var auth: Dictionary = AuthPortal.get_auth(server.id)
	var pn_key: String = ("pn_key_" + auth.username + "&" + auth.password_hash).sha256_text()

	OS.shell_open("ntfy://%s:%d/%s?secure=false&display=%s" % [server.address, 26970, pn_key, ("%s: Private" % server.name).uri_encode()])

func _on_get_ntfy_pressed() -> void:
	OS.shell_open("https://f-droid.org/en/packages/io.heckel.ntfy/")

func _on_get_f_droid_pressed() -> void:
	OS.shell_open("https://f-droid.org/")
