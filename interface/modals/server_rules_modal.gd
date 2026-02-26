class_name ServerRulesModal extends Control

static var prompted_servers: Array[String] = []

var server: Server
var viewing: bool

func _ready() -> void:
	await Lib.frame

	if viewing:
		%Buttons/Accept.hide()
		%Buttons/Decline.hide()
		%Buttons/Close.show()

	%Title.text = "Read the rules for %s" % server.name

	for rule in server.rules:
		var item = preload("res://interface/modals/server_rule_item.tscn").instantiate()
		item.get_node("Title").text = rule.title if "title" in rule else "Untitled Rule"
		item.get_node("Description").text = rule.description if "description" in rule else ""
		
		%RulesContainer.add_child(item)

func _on_accept_pressed() -> void:
	server.accepted_rules_hash = JSON.stringify(server.rules).sha256_text()
	server.cache()
	ModalStack.fade_free_modal(self )
	prompted_servers.erase(server.id)

func _on_decline_pressed() -> void:
	server.leave_server(false)
	ModalStack.fade_free_modal(self )
	prompted_servers.erase(server.id)

func _on_close_pressed() -> void:
	ModalStack.fade_free_modal(self )
