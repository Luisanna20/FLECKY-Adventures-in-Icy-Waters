class_name SharkManager
extends Node3D

signal hearts_changed(current: int, maximum: int)
signal alert_changed(text: String, active: bool)
signal player_bitten
signal soft_respawned

enum SharkState {
	DORMANT,
	WARNING,
	HUNTING,
	CIRCLING,
	RETREATING,
	COOLDOWN,
}

const MAX_HEARTS := 3
const FIRST_FISH_TRIGGER := 2
const FISHES_BETWEEN_ATTACKS := 3
const DETECTION_DISTANCE := 42.0
const BITE_DISTANCE := 1.65
const BITE_RESET_DISTANCE := 6.0
const INVULNERABILITY_DURATION := 6.0
const WARNING_DURATION := 5.0
const HUNT_DURATION := 18.0
const CIRCLE_DURATION := 6.5
const COOLDOWN_DURATION := 24.0

var player: FlakiController
var hearts := MAX_HEARTS
var _shark: BayShark
var _state := SharkState.DORMANT
var _state_time := 0.0
var _natural_attack_time := 48.0
var _invulnerability_time := 0.0
var _bite_requires_separation := false
var _next_fish_trigger := FIRST_FISH_TRIGGER
var _last_known_position := Vector3.ZERO
var _retreat_target := Vector3.ZERO
var _orbit_angle := 0.0
var _checkpoint_zone: IceExitZone
var _checkpoint_position := Vector3.ZERO
var _random := RandomNumberGenerator.new()
var _fast_test := false
var _demo_finished := false
var _cave_refuge: Node3D


func configure(target_player: FlakiController) -> void:
	player = target_player
	_random.seed = 710026
	_shark = BayShark.new()
	_shark.name = "Shark"
	add_child(_shark)
	_shark.configure()
	_find_initial_checkpoint()
	hearts_changed.emit(hearts, MAX_HEARTS)


func _process(delta: float) -> void:
	if _demo_finished or not is_instance_valid(player) or not is_instance_valid(_shark):
		return
	_update_checkpoint()
	_invulnerability_time = maxf(_invulnerability_time - delta, 0.0)
	if (
		_bite_requires_separation
		and _shark.visible
		and _shark.global_position.distance_to(player.global_position) >= BITE_RESET_DISTANCE
	):
		_bite_requires_separation = false

	match _state:
		SharkState.DORMANT:
			_natural_attack_time -= delta
			if _natural_attack_time <= 0.0:
				_start_warning()
		SharkState.WARNING:
			_update_warning(delta)
		SharkState.HUNTING:
			_update_hunt(delta)
		SharkState.CIRCLING:
			_update_circle(delta)
		SharkState.RETREATING:
			_update_retreat(delta)
		SharkState.COOLDOWN:
			_state_time -= delta
			if _state_time <= 0.0:
				_state = SharkState.DORMANT
				_natural_attack_time = 34.0

	if _shark.visible:
		for refuge in get_tree().get_nodes_in_group("shark_shelter"):
			refuge.keep_shark_out(_shark)


func notify_fish_count(caught_fish: int) -> void:
	if _demo_finished:
		return
	if caught_fish < _next_fish_trigger:
		return
	_next_fish_trigger += FISHES_BETWEEN_ATTACKS
	if _state == SharkState.DORMANT:
		_start_warning()


func force_attack_for_test() -> void:
	_fast_test = true
	_start_warning()
	_state_time = 0.08


func debug_apply_bite() -> void:
	_invulnerability_time = 0.0
	_bite_player()


func debug_attempt_contact_bite() -> bool:
	var hearts_before := hearts
	if _can_bite(BITE_DISTANCE * 0.5):
		_bite_player()
	return hearts < hearts_before


func get_state_name() -> String:
	return SharkState.keys()[_state]


func get_shark() -> BayShark:
	return _shark


func end_demo() -> void:
	_demo_finished = true
	_state = SharkState.COOLDOWN
	_shark.visible = false
	_shark.stop_swimming()
	alert_changed.emit("", false)


func is_disabled_for_victory() -> bool:
	return _demo_finished and not _shark.visible


func _start_warning() -> void:
	if _state not in [SharkState.DORMANT, SharkState.COOLDOWN]:
		return
	_cave_refuge=null
	_state = SharkState.WARNING
	_state_time = WARNING_DURATION
	_orbit_angle = _random.randf_range(0.0, TAU)
	var spawn_direction := Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle))
	var spawn_position := player.global_position + spawn_direction * (3.8 if _fast_test else 30.0)
	var flat_spawn := Vector2(spawn_position.x, spawn_position.z)
	if flat_spawn.length() > 55.0:
		flat_spawn = flat_spawn.normalized() * 55.0
	spawn_position.x = flat_spawn.x
	spawn_position.z = flat_spawn.y
	spawn_position.y = -1.0
	_shark.global_position = spawn_position
	_shark.stop_swimming()
	_shark.visible = true
	_bite_requires_separation = false
	_last_known_position = player.global_position
	alert_changed.emit("SHARK_SHADOW", true)


func _update_warning(delta: float) -> void:
	_state_time -= delta
	_orbit_angle += delta * 0.72
	var warning_radius := 10.0 if _fast_test else 19.0
	var warning_target := player.global_position + Vector3(
		cos(_orbit_angle) * warning_radius,
		-0.45,
		sin(_orbit_angle) * warning_radius
	)
	warning_target.y = -1.0
	_shark.swim_towards(warning_target, 4.7, delta)
	if _state_time <= 0.0:
		_state = SharkState.HUNTING
		_state_time = 7.0 if _fast_test else HUNT_DURATION
		alert_changed.emit("SHARK_HIDE", true)


func _update_hunt(delta: float) -> void:
	_state_time -= delta
	if player.is_safe_from_shark():
		_start_circling()
		return
	if player.is_transitioning():
		_shark.swim_towards(_last_known_position, 5.5, delta)
		return

	var distance_to_player := _shark.global_position.distance_to(player.global_position)
	if distance_to_player <= DETECTION_DISTANCE:
		_last_known_position = player.global_position
		var chase_target := player.global_position
		chase_target.y = minf(chase_target.y, -0.78)
		_shark.swim_towards(chase_target, 7.6, delta)
	else:
		_shark.swim_towards(_last_known_position, 4.8, delta)

	if _can_bite(distance_to_player):
		_bite_player()
	if _state_time <= 0.0:
		_start_retreat()


func _start_circling() -> void:
	_cave_refuge = player.get_cave_shelter()
	_state = SharkState.CIRCLING
	_state_time = 1.2 if _fast_test else CIRCLE_DURATION
	_orbit_angle = atan2(
		_shark.global_position.z - player.global_position.z,
		_shark.global_position.x - player.global_position.x
	)
	alert_changed.emit("SHARK_CAVE_WAIT" if is_instance_valid(_cave_refuge) else "SHARK_CIRCLING", not is_instance_valid(_cave_refuge))


func _update_circle(delta: float) -> void:
	_state_time -= delta
	if player.is_swimming() and not player.is_safe_from_shark():
		_state = SharkState.HUNTING
		_state_time = 8.0
		alert_changed.emit("SHARK_HIDE", true)
		return
	_orbit_angle += delta * 0.82
	var refuge := player.get_cave_shelter()
	if is_instance_valid(refuge):
		_cave_refuge=refuge
		_shark.swim_towards(refuge.waiting_position(_orbit_angle),3.0,delta)
		if _state_time <= 0.0: _start_retreat()
		return
	var circle_target := player.global_position + Vector3(
		cos(_orbit_angle) * 7.5,
		0.0,
		sin(_orbit_angle) * 7.5
	)
	circle_target.y = -1.15
	_shark.swim_towards(circle_target, 5.4, delta)
	if _state_time <= 0.0:
		_start_retreat()


func _start_retreat() -> void:
	_state = SharkState.RETREATING
	var flat_position := Vector2(_shark.global_position.x, _shark.global_position.z)
	var retreat_direction := (
		flat_position.normalized()
		if flat_position.length() > 0.5
		else Vector2(0.0, 1.0)
	)
	if is_instance_valid(_cave_refuge):
		retreat_direction = -Vector2(_cave_refuge.global_position.x,_cave_refuge.global_position.z).normalized()
	_retreat_target = Vector3(retreat_direction.x * 76.0, -4.0, retreat_direction.y * 76.0)
	alert_changed.emit("SHARK_LEAVING", false)


func _update_retreat(delta: float) -> void:
	_shark.swim_towards(_retreat_target, 8.7, delta)
	var flat_position := Vector2(_shark.global_position.x, _shark.global_position.z)
	if flat_position.length() >= 68.0:
		_shark.visible = false
		_shark.stop_swimming()
		_state = SharkState.COOLDOWN
		_state_time = 1.0 if _fast_test else COOLDOWN_DURATION
		_fast_test = false


func _bite_player() -> void:
	if player.is_safe_from_shark():
		return
	_shark.play_bite()
	hearts -= 1
	_invulnerability_time = INVULNERABILITY_DURATION
	_bite_requires_separation = true
	hearts_changed.emit(hearts, MAX_HEARTS)
	player_bitten.emit()
	_shark.swim_velocity *= -0.28

	if hearts > 0:
		return

	hearts = MAX_HEARTS
	hearts_changed.emit(hearts, MAX_HEARTS)
	if is_instance_valid(_checkpoint_zone):
		player.respawn_on_ice(_checkpoint_position, _checkpoint_zone)
	soft_respawned.emit()
	_start_retreat()


func _can_bite(distance_to_player: float) -> bool:
	return (
		distance_to_player <= BITE_DISTANCE
		and _invulnerability_time <= 0.0
		and not _bite_requires_separation
		and not player.is_safe_from_shark()
	)


func _find_initial_checkpoint() -> void:
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("ice_exit_zone"):
		var zone := node as IceExitZone
		if not is_instance_valid(zone):
			continue
		var landing := zone.get_landing_position()
		var distance := landing.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			_checkpoint_zone = zone
			_checkpoint_position = landing


func _update_checkpoint() -> void:
	if not player.is_on_ice():
		return
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("ice_exit_zone"):
		var zone := node as IceExitZone
		if not is_instance_valid(zone):
			continue
		var landing := zone.get_landing_position()
		var distance := landing.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			_checkpoint_zone = zone
			_checkpoint_position = landing
