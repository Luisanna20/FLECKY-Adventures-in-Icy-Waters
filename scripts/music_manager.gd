class_name BayMusicManager
extends Node

const BAY_THEME := preload("res://Ice Bay Drift.mp3")
const SURFACE_VOLUME_DB := -15.0
const UNDERWATER_VOLUME_DB := -18.5
const DANGER_VOLUME_DB := -22.0
const PAUSE_VOLUME_DB := -24.0
const MENU_VOLUME_DB := -18.0
const VICTORY_VOLUME_DB := -11.5

var water_level := 0.0
var _player: AudioStreamPlayer
var _danger_active := false
var _pause_active := false
var _menu_active := false
var _victory_active := false
var _underwater_amount := 0.0


func configure(surface_height: float) -> void:
	water_level = surface_height
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "IceBayDrift"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	var looping_stream := BAY_THEME.duplicate() as AudioStreamMP3
	looping_stream.loop = true
	looping_stream.loop_offset = 0.0
	_player.stream = looping_stream
	_player.volume_db = -42.0
	add_child(_player)
	_player.play()


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var camera := get_viewport().get_camera_3d()
	var underwater_target := 0.0
	if is_instance_valid(camera) and camera.global_position.y < water_level - 0.10:
		underwater_target = 1.0
	_underwater_amount = move_toward(_underwater_amount, underwater_target, delta * 1.6)

	var target_volume := lerpf(
		SURFACE_VOLUME_DB,
		UNDERWATER_VOLUME_DB,
		_underwater_amount
	)
	if _menu_active:
		target_volume = MENU_VOLUME_DB
	elif _danger_active:
		target_volume = minf(target_volume, DANGER_VOLUME_DB)
	if _victory_active:
		target_volume = VICTORY_VOLUME_DB
	if _pause_active:
		target_volume = PAUSE_VOLUME_DB
	_player.volume_db = move_toward(_player.volume_db, target_volume, delta * 7.5)


func set_danger_active(active: bool) -> void:
	if _victory_active:
		return
	_danger_active = active


func set_pause_active(active: bool) -> void:
	_pause_active = active


func set_menu_active(active: bool) -> void:
	_menu_active = active


func set_victory_active() -> void:
	_victory_active = true
	_danger_active = false
	_pause_active = false
	_menu_active = false


func set_free_roam_active() -> void:
	_victory_active = false
	_danger_active = false
	_pause_active = false
	_menu_active = false


func is_ready_and_playing() -> bool:
	return (
		is_instance_valid(_player)
		and is_instance_valid(_player.stream)
		and _player.stream.get_length() > 0.0
		and _player.playing
	)


func get_track_length() -> float:
	return _player.stream.get_length() if is_instance_valid(_player) else 0.0
