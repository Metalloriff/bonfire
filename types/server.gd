class_name Server extends Resource

@export var id: String
@export var name: String = "Invalid Server"
@export var address: String
@export var port: int

# var channels: Array[Channel] = []

func cache() -> void:
	print("Caching server %s" % id)

	FS.mkdir("user://servers")
	ResourceSaver.save(self , "user://servers/%s.res" % id)