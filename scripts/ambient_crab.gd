class_name AmbientCrab
extends Node3D

signal dance_started

const CRAB_SCENE := preload("res://assets/models/ambient_life/crab_enemy.glb")
const WALK_ANIMATION := &"MonsterArmature|Walk"
const THREAT_ANIMATION := &"MonsterArmature|Bite_InPlace"
const DANCE_ANIMATION := &"MonsterArmature|Dance"
const THREAT_RADIUS := 4.6
const VOICE_DANCE_RADIUS := 7.5

enum Reaction {
	NONE,
	THREAT,
	DANCE,
}

var _waypoints: Array[Vector3] = []
var _target_waypoint := 1
var _route_direction := 1
var _elapsed := 0.0
var _travel_speed := 0.46
var _animation_player: AnimationPlayer
var _flaki: Node3D
var _reaction := Reaction.NONE
var _reaction_time := 0.0
var _threat_cooldown := 0.0
var _dance_count := 0
var _threat_count := 0


func configure(
	route_points: Array,
	travel_speed: float = 0.46,
	flaki: Node3D = null
) -> void:
	_waypoints.clear()
	for route_point in route_points:
		if route_point is Vector3:
			_waypoints.append(route_point)
	if _waypoints.size() < 2:
		push_warning("Ambient crab needs at least two route waypoints.")
		return
	_travel_speed = travel_speed
	_flaki = flaki
	_target_waypoint = 1
	_route_direction = 1
	global_position = _waypoints[0]

	var visual := CRAB_SCENE.instantiate() as Node3D
	visual.name = "QuaterniusCrab"
	visual.scale = Vector3.ONE * 0.76
	visual.rotation_degrees.y = 180.0
	add_child(visual)
	_prepare_model(visual)

	_animation_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if is_instance_valid(_animation_player):
		_prepare_looping_animation(WALK_ANIMATION)
		_prepare_looping_animation(THREAT_ANIMATION)
		_prepare_looping_animation(DANCE_ANIMATION)
		_play_walk()


func _process(delta: float) -> void:
	if _waypoints.size() < 2:
		return
	_elapsed += delta
	_threat_cooldown = maxf(_threat_cooldown - delta, 0.0)
	if _reaction != Reaction.NONE:
		_reaction_time = maxf(_reaction_time - delta, 0.0)
		_face_flaki(delta, 7.0)
		global_position.y = (
			_waypoints[_target_waypoint].y
			+ sin(_elapsed * 5.2) * 0.025
		)
		if _reaction_time <= 0.0:
			_finish_reaction()
		return
	if (
		is_instance_valid(_flaki)
		and _threat_cooldown <= 0.0
		and global_position.distance_to(_flaki.global_position) <= THREAT_RADIUS
	):
		_start_threat()
		return
	var remaining_distance := delta * _travel_speed
	var travel_direction := Vector3.ZERO
	while remaining_distance > 0.0001:
		var target := _waypoints[_target_waypoint]
		var offset := target - global_position
		var target_distance := offset.length()
		if target_distance <= 0.001:
			_advance_waypoint()
			continue
		travel_direction = offset / target_distance
		var step_distance := minf(remaining_distance, target_distance)
		global_position += travel_direction * step_distance
		remaining_distance -= step_distance
		if step_distance >= target_distance - 0.001:
			_advance_waypoint()
	global_position.y = _waypoints[_target_waypoint].y + sin(_elapsed * 5.2) * 0.025

	# A crab looks more natural side-stepping instead of marching like a tiny tank.
	var facing_direction := Vector3(-travel_direction.z, 0.0, travel_direction.x)
	var wanted_yaw := atan2(facing_direction.x, facing_direction.z)
	rotation.y = lerp_angle(rotation.y, wanted_yaw, clampf(delta * 4.0, 0.0, 1.0))


func on_flaki_voice(voice_position: Vector3) -> void:
	if global_position.distance_to(voice_position) > VOICE_DANCE_RADIUS:
		return
	_start_dance()


func is_walk_animation_playing() -> bool:
	return (
		is_instance_valid(_animation_player)
		and _animation_player.current_animation == WALK_ANIMATION
		and _animation_player.is_playing()
	)


func is_threatening() -> bool:
	return (
		_reaction == Reaction.THREAT
		and is_instance_valid(_animation_player)
		and _animation_player.current_animation == THREAT_ANIMATION
	)


func is_dancing() -> bool:
	return (
		_reaction == Reaction.DANCE
		and is_instance_valid(_animation_player)
		and _animation_player.current_animation == DANCE_ANIMATION
	)


func get_dance_count() -> int:
	return _dance_count


func get_threat_count() -> int:
	return _threat_count


func get_voice_dance_radius() -> float:
	return VOICE_DANCE_RADIUS


func debug_resume_route() -> void:
	_finish_reaction()


func get_route_length() -> float:
	var length := 0.0
	for index in _waypoints.size() - 1:
		length += _waypoints[index].distance_to(_waypoints[index + 1])
	return length


func _start_threat() -> void:
	if not _play_reaction_animation(THREAT_ANIMATION, 0.86):
		return
	_reaction = Reaction.THREAT
	_reaction_time = 1.62
	_threat_cooldown = 5.8
	_threat_count += 1


func _start_dance() -> void:
	if not _play_reaction_animation(DANCE_ANIMATION, 0.92):
		return
	_reaction = Reaction.DANCE
	_reaction_time = 2.65
	_threat_cooldown = 4.2
	_dance_count += 1
	dance_started.emit()


func _finish_reaction() -> void:
	_reaction = Reaction.NONE
	_reaction_time = 0.0
	_play_walk()


func _play_walk() -> void:
	if not is_instance_valid(_animation_player):
		return
	_animation_player.speed_scale = 0.72
	_animation_player.play(WALK_ANIMATION, 0.16)


func _play_reaction_animation(animation_name: StringName, speed: float) -> bool:
	if (
		not is_instance_valid(_animation_player)
		or _animation_player.get_animation(animation_name) == null
	):
		return false
	_animation_player.speed_scale = speed
	_animation_player.play(animation_name, 0.12)
	return true


func _prepare_looping_animation(animation_name: StringName) -> void:
	if not is_instance_valid(_animation_player):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR


func _face_flaki(delta: float, turn_speed: float) -> void:
	if not is_instance_valid(_flaki):
		return
	var offset := _flaki.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	# The imported crab visual is rotated 180 degrees inside this node.
	# Compensate here so its face, rather than its back, points at Flecky.
	var wanted_yaw := atan2(offset.x, offset.z) + PI
	rotation.y = lerp_angle(
		rotation.y,
		wanted_yaw,
		clampf(delta * turn_speed, 0.0, 1.0)
	)


func _advance_waypoint() -> void:
	if _target_waypoint == _waypoints.size() - 1:
		_route_direction = -1
	elif _target_waypoint == 0:
		_route_direction = 1
	_target_waypoint += _route_direction


func _prepare_model(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_index)
			if source is StandardMaterial3D:
				var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
				material.emission_enabled = true
				if source.resource_name in ["Main", "Main_Dark"]:
					material.albedo_color = material.albedo_color.lerp(
						Color(0.88, 0.30, 0.17),
						0.48
					)
					material.emission = material.albedo_color * 0.82
					material.emission_energy_multiplier = 1.05
				else:
					material.emission = material.albedo_color * 0.38
					material.emission_energy_multiplier = 0.62
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in node.get_children():
		_prepare_model(child)
