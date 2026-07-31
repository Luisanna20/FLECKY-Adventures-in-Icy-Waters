class_name AchievementManager
extends Node

signal achievement_unlocked(achievement_id: String)

const SAVE_PATH := "user://achievements.cfg"
const DEFINITIONS := [
	{
		"id": "treasure_depths",
		"name_key": "ACH_TREASURE_NAME",
		"description_key": "ACH_TREASURE_DESC",
		"icon": "res://assets/ui/achievements/treasure_depths.png",
		"secret": true,
	},
	{
		"id": "crab_dance",
		"name_key": "ACH_CRAB_DANCE_NAME",
		"description_key": "ACH_CRAB_DANCE_DESC",
		"icon": "res://assets/ui/achievements/crab_dance.png",
		"secret": true,
	},
	{
		"id": "flying_seal",
		"name_key": "ACH_FLYING_SEAL_NAME",
		"description_key": "ACH_FLYING_SEAL_DESC",
		"icon": "res://assets/ui/achievements/flying_seal.png",
		"secret": false,
	},
	{
		"id": "untouchable",
		"name_key": "ACH_UNTOUCHABLE_NAME",
		"description_key": "ACH_UNTOUCHABLE_DESC",
		"icon": "res://assets/ui/achievements/untouchable.png",
		"secret": false,
	},
	{
		"id": "fish_day",
		"name_key": "ACH_FISH_DAY_NAME",
		"description_key": "ACH_FISH_DAY_DESC",
		"icon": "res://assets/ui/achievements/fish_day.png",
		"secret": false,
	},
	{
		"id": "vocalist",
		"name_key": "ACH_VOCALIST_NAME",
		"description_key": "ACH_VOCALIST_DESC",
		"icon": "res://assets/ui/achievements/vocalist.png",
		"secret": true,
	},
	{
		"id": "seal_rest",
		"name_key": "ACH_SEAL_REST_NAME",
		"description_key": "ACH_SEAL_REST_DESC",
		"icon": "res://assets/ui/achievements/seal_rest.png",
		"secret": false,
	},
	{
		"id": "free_swimmer",
		"name_key": "ACH_FREE_SWIMMER_NAME",
		"description_key": "ACH_FREE_SWIMMER_DESC",
		"icon": "res://assets/ui/achievements/free_swimmer.png",
		"secret": false,
	},
]

var _unlocked := {}
var _persistence_enabled := true


func configure(persistence_enabled: bool = true) -> void:
	_persistence_enabled = persistence_enabled
	_unlocked.clear()
	if _persistence_enabled:
		_load_progress()


func unlock(achievement_id: String) -> bool:
	if not has_achievement(achievement_id) or is_unlocked(achievement_id):
		return false
	_unlocked[achievement_id] = true
	if _persistence_enabled:
		_save_progress()
	achievement_unlocked.emit(achievement_id)
	return true


func is_unlocked(achievement_id: String) -> bool:
	return bool(_unlocked.get(achievement_id, false))


func has_achievement(achievement_id: String) -> bool:
	return not get_definition(achievement_id).is_empty()


func get_definition(achievement_id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if str(definition.get("id", "")) == achievement_id:
			return definition
	return {}


func get_definitions() -> Array:
	return DEFINITIONS.duplicate(true)


func get_unlocked_count() -> int:
	var count := 0
	for definition in DEFINITIONS:
		if is_unlocked(str(definition.get("id", ""))):
			count += 1
	return count


func get_total_count() -> int:
	return DEFINITIONS.size()


func get_unlocked_ids() -> Array[String]:
	var unlocked_ids: Array[String] = []
	for definition in DEFINITIONS:
		var achievement_id := str(definition.get("id", ""))
		if is_unlocked(achievement_id):
			unlocked_ids.append(achievement_id)
	return unlocked_ids


func debug_unlock(achievement_id: String) -> bool:
	return unlock(achievement_id)


func debug_clear_session_progress() -> void:
	_unlocked.clear()


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for definition in DEFINITIONS:
		var achievement_id := str(definition.get("id", ""))
		if bool(config.get_value("unlocked", achievement_id, false)):
			_unlocked[achievement_id] = true


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	for definition in DEFINITIONS:
		var achievement_id := str(definition.get("id", ""))
		config.set_value("unlocked", achievement_id, is_unlocked(achievement_id))
	var save_result := config.save(SAVE_PATH)
	if save_result != OK:
		push_warning(
			"Could not save achievement progress: %s" % error_string(save_result)
		)
