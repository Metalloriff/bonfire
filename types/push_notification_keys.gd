class_name PushNotificationKeys extends Resource

@export var keys: Dictionary = {}
@export var configs: Dictionary = {}
@export var private_key: String = Lib.create_uid(64)
