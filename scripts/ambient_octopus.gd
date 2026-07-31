class_name AmbientOctopus
extends Node3D

const OCTOPUS_SCENE := preload("res://assets/models/ambient_life/octopus.glb")
const MODEL_SCALE := 0.025
const MODEL_HALF_HEIGHT := 0.72
const TRACKING_RADIUS := 16.0
const MAX_TRACKING_ANGLE := deg_to_rad(68.0)

var _visual: Node3D
var _flaki: Node3D
var _elapsed := 0.0
var _base_rotation := 0.0
var _levitating := false
var _hover_offset := 0.0
var _tracking_amount := 0.0
var _tracking_flaki := false


func configure(
	resting_position: Vector3,
	facing_yaw: float = 0.0,
	levitating: bool = false,
	flaki: Node3D = null
) -> void:
	global_position = resting_position
	_base_rotation = facing_yaw
	_levitating = levitating
	_flaki = flaki
	_visual = OCTOPUS_SCENE.instantiate() as Node3D
	_visual.name = "PolyByGoogleOctopus"
	_visual.scale = Vector3.ONE * MODEL_SCALE
	_visual.rotation.y = facing_yaw
	add_child(_visual)
	_prepare_model(_visual)


func _process(delta: float) -> void:
	if not is_instance_valid(_visual):
		return
	_elapsed += delta
	var pulse := 1.0 + sin(_elapsed * 1.18) * 0.025
	_visual.scale = Vector3(MODEL_SCALE / sqrt(pulse), MODEL_SCALE * pulse, MODEL_SCALE / sqrt(pulse))
	_hover_offset = (
		sin(_elapsed * 0.76) * 0.34
		+ sin(_elapsed * 0.29 + 1.2) * 0.11
		if _levitating
		else 0.0
	)
	_visual.position.y = MODEL_HALF_HEIGHT * (pulse - 1.0) + _hover_offset
	var desired_yaw := _base_rotation + sin(_elapsed * 0.31) * 0.10
	_tracking_flaki = (
		is_instance_valid(_flaki)
		and global_position.distance_to(_flaki.global_position) <= TRACKING_RADIUS
	)
	var target_tracking_amount := 1.0 if _tracking_flaki else 0.0
	_tracking_amount = move_toward(
		_tracking_amount,
		target_tracking_amount,
		delta * (1.75 if _tracking_flaki else 1.05)
	)
	if is_instance_valid(_flaki) and _tracking_amount > 0.0:
		var to_flaki := _flaki.global_position - global_position
		to_flaki.y = 0.0
		if to_flaki.length_squared() > 0.001:
			var raw_target_yaw := atan2(to_flaki.x, to_flaki.z)
			var target_offset := clampf(
				angle_difference(_base_rotation, raw_target_yaw),
				-MAX_TRACKING_ANGLE,
				MAX_TRACKING_ANGLE
			)
			var tracking_yaw := (
				_base_rotation
				+ target_offset
				+ sin(_elapsed * 0.58) * 0.022
			)
			desired_yaw = lerp_angle(
				desired_yaw,
				tracking_yaw,
				_tracking_amount
			)
	_visual.rotation.y = lerp_angle(
		_visual.rotation.y,
		desired_yaw,
		1.0 - exp(-delta * 3.1)
	)
	_visual.rotation.x = sin(_elapsed * 0.43) * (0.035 if _levitating else 0.0)
	_visual.rotation.z = sin(_elapsed * 0.72) * (0.045 if _levitating else 0.018)


func is_idling() -> bool:
	return is_instance_valid(_visual) and _elapsed > 0.1


func is_levitating() -> bool:
	return _levitating and absf(_hover_offset) > 0.02


func is_tracking_flaki() -> bool:
	return _tracking_flaki and _tracking_amount > 0.55


func get_tracking_radius() -> float:
	return TRACKING_RADIUS


func get_facing_error_to_flaki() -> float:
	if not is_instance_valid(_visual) or not is_instance_valid(_flaki):
		return INF
	var to_flaki := _flaki.global_position - global_position
	to_flaki.y = 0.0
	if to_flaki.length_squared() <= 0.001:
		return 0.0
	var wanted_yaw := atan2(to_flaki.x, to_flaki.z)
	return absf(angle_difference(_visual.global_rotation.y, wanted_yaw))


func _prepare_model(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_index)
			if source is StandardMaterial3D:
				var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
				material.albedo_color *= Color(0.72, 0.48, 0.86)
				material.emission_enabled = true
				material.emission = Color(0.31, 0.11, 0.39)
				material.emission_energy_multiplier = 0.64
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in node.get_children():
		_prepare_model(child)
