class_name DemoFlowManager
extends Node

signal victory_ready
signal victory_pose_started

var player: FlakiController
var shark_manager: SharkManager
var camera_rig: FlakiCameraRig
var _victory_started := false
var _victory_complete := false
var _pose_started := false
var _victory_fish: BayFish


func configure(
	target_player: FlakiController,
	target_shark_manager: SharkManager,
	target_camera: FlakiCameraRig
) -> void:
	player = target_player
	shark_manager = target_shark_manager
	camera_rig = target_camera


func start_victory() -> void:
	if _victory_started:
		return
	_victory_started = true
	shark_manager.end_demo()
	camera_rig.set_victory_mode(true)

	var victory_zone := _find_nearest_ice_zone()
	await get_tree().create_timer(0.85).timeout
	if not is_instance_valid(victory_zone):
		player.respawn_on_ice(player.global_position, null)
		_finish_victory()
		return

	player.victory_pose_ready.connect(_finish_victory, CONNECT_ONE_SHOT)
	player.start_victory_sequence(
		victory_zone.get_water_position(),
		victory_zone.get_landing_position(),
		victory_zone
	)


func is_complete() -> bool:
	return _victory_complete


func has_victory_fish() -> bool:
	return is_instance_valid(_victory_fish)


func enter_free_roam() -> void:
	camera_rig.set_victory_mode(false)
	player.leave_victory_pose()
	if is_instance_valid(_victory_fish):
		_victory_fish.queue_free()
		_victory_fish = null


func _finish_victory() -> void:
	if _pose_started:
		return
	_pose_started = true
	_spawn_victory_fish()
	victory_pose_started.emit()
	await get_tree().create_timer(4.8).timeout
	_victory_complete = true
	victory_ready.emit()


func _find_nearest_ice_zone() -> IceExitZone:
	var nearest: IceExitZone
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("ice_exit_zone"):
		var zone := node as IceExitZone
		if not is_instance_valid(zone):
			continue
		var distance := zone.get_landing_position().distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = zone
	return nearest


func _spawn_victory_fish() -> void:
	_victory_fish = BayFish.new()
	_victory_fish.name = "VictoryBigFish"
	add_child(_victory_fish)
	var screen_right := player.global_basis.x
	var view_forward := -player.global_basis.z
	var active_camera := player.get_viewport().get_camera_3d()
	if is_instance_valid(active_camera):
		screen_right = active_camera.global_basis.x
		view_forward = -active_camera.global_basis.z
	screen_right.y = 0.0
	view_forward.y = 0.0
	screen_right = screen_right.normalized()
	view_forward = view_forward.normalized()
	_victory_fish.global_position = (
		player.global_position
		+ screen_right * 2.15
		+ view_forward * 0.25
		+ Vector3.UP * 0.08
	)
	_victory_fish.configure(
		_victory_fish.global_position,
		player,
		777001,
		Color(0.96, 0.67, 0.20)
	)
	_victory_fish.remove_from_group("catchable_fish")
	_victory_fish.set_physics_process(false)
	_victory_fish.scale = Vector3(1.75, 1.75, 1.75)
	_victory_fish.rotation.y = player.rotation.y + 0.22
