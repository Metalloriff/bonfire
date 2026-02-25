class_name Permissions extends Resource

const SERVER_PROFILE_MANAGE: StringName = &"server_profile_manage"
const CHANNEL_MANAGE: StringName = &"channel_manage"
const MESSAGE_SEND: StringName = &"message_send"
const MESSAGE_DELETE: StringName = &"message_delete"
const MESSAGE_PURGE: StringName = &"message_purge"
const MEMBER_ROLE_MANAGE: StringName = &"member_role_manage"
const MEMBER_VOICE_MANAGE: StringName = &"member_voice_manage"
const MEMBER_KICK: StringName = &"member_kick"
const MEMBER_BAN: StringName = &"member_ban"

@export_storage var _permission: PackedStringArray = []

func has_permission(permission: StringName) -> bool:
	return permission in _permission or "*" in _permission

func add_permission(permission: StringName) -> void:
	_permission.append(permission)

func remove_permission(permission: StringName) -> void:
	_permission.erase(permission)