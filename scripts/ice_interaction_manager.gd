class_name IceInteractionManager
extends Node

signal prompt_changed(text: String)

var player: FlakiController
var _nearby_zone: IceExitZone
var _current_floe_zone: IceExitZone
var _active_marker_zone: IceExitZone
var _last_prompt := ""


func configure(target_player: FlakiController) -> void:
	player = target_player


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	if player.is_transitioning():
		_set_active_marker(null)
		_set_prompt("")
		return

	if player.is_on_ice():
		_set_active_marker(null)
		if (
			not is_instance_valid(_current_floe_zone)
			or _current_floe_zone.get_landing_position().distance_to(
				player.global_position
			) > 6.0
		):
			_current_floe_zone = _find_nearest_landing_zone()
		_set_prompt("PROMPT_RETURN_WATER")
		if Input.is_action_just_pressed("climb_ice") and is_instance_valid(_current_floe_zone):
			player.enter_water(_current_floe_zone.get_water_position())
		return

	_nearby_zone = _find_nearby_zone()
	_set_active_marker(_nearby_zone if _camera_is_above_water() else null)
	if is_instance_valid(_nearby_zone):
		_set_prompt("PROMPT_CLIMB_ICE")
		if Input.is_action_just_pressed("climb_ice"):
			_current_floe_zone = _nearby_zone
			player.climb_onto_ice(
				_nearby_zone.get_landing_position(),
				_nearby_zone
			)
	else:
		_set_prompt("")


func _find_nearby_zone() -> IceExitZone:
	var nearest: IceExitZone
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("ice_exit_zone"):
		var zone := node as IceExitZone
		if not is_instance_valid(zone) or not zone.is_player_inside(player):
			continue
		var distance := player.global_position.distance_to(zone.global_position)
		if distance < nearest_distance:
			nearest = zone
			nearest_distance = distance
	return nearest


func _find_nearest_landing_zone() -> IceExitZone:
	var nearest: IceExitZone
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("ice_exit_zone"):
		var zone := node as IceExitZone
		if not is_instance_valid(zone):
			continue
		var distance := zone.get_landing_position().distance_to(player.global_position)
		if distance < nearest_distance:
			nearest = zone
			nearest_distance = distance
	return nearest


func _camera_is_above_water() -> bool:
	var camera := get_viewport().get_camera_3d()
	return is_instance_valid(camera) and camera.global_position.y > 0.08


func _set_active_marker(zone: IceExitZone) -> void:
	if _active_marker_zone == zone:
		return
	if is_instance_valid(_active_marker_zone):
		_active_marker_zone.set_marker_active(false)
	_active_marker_zone = zone
	if is_instance_valid(_active_marker_zone):
		_active_marker_zone.set_marker_active(true)


func _set_prompt(text: String) -> void:
	if text == _last_prompt:
		return
	_last_prompt = text
	prompt_changed.emit(text)
