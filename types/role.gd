class_name Role extends Resource

@export var id: String = Lib.create_uid(32)
@export var name: String = "Invalid Role"
@export var permissions: Permissions = Permissions.new()
@export var color: Color = Color.TRANSPARENT
