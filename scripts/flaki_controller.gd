class_name FlakiController
extends CharacterBody3D

signal state_changed(title: String)
signal victory_pose_ready
signal breach_started(position: Vector3, speed: float)
signal splash_landed(position: Vector3, speed: float)
signal voice_played(position: Vector3)

const FLAKI_VOICE := preload("res://flaky-talk.mp3")

enum MovementMode {
	SWIMMING,
	BREACHING,
	TRANSITION,
	ON_ICE,
	VICTORY,
}

@export var water_level := 0.0
@export var minimum_depth := -13.2
@export var swim_speed := 5.0
@export var vertical_speed := 3.4
@export var boost_multiplier := 1.75
@export var acceleration := 4.8
@export var turning_speed := 5.5
@export var maximum_swim_radius := 60.5

const SURFACE_BODY_OFFSET := 0.48
const BREACH_MIN_SPEED := 3.8
const BREACH_CHARGE_TIME := 0.22
const BREACH_UP_SPEED := 4.65
const BREACH_GRAVITY := 8.9
const SEAL_MODEL = preload("res://scripts/flaki_model.gd")
const LEFT_FLIPPER_SWIM_POSITION := Vector3(-0.48, -0.07, -0.18)
const RIGHT_FLIPPER_SWIM_POSITION := Vector3(0.48, -0.07, -0.18)
const LEFT_FLIPPER_ICE_POSITION := Vector3(-0.46, -0.30, -0.15)
const RIGHT_FLIPPER_ICE_POSITION := Vector3(0.46, -0.30, -0.15)
const ICE_FLIPPER_SWEEP := deg_to_rad(50.0)
const ICE_FLIPPER_ROLL := deg_to_rad(2.0)
const ICE_IDLE_DELAY := 1.75
const ICE_IDLE_MAX_HEAD_YAW := deg_to_rad(12.0)

var _visual_root: Node3D
var _head_root: Node3D
var _left_flipper: Node3D
var _right_flipper: Node3D
var _tail_left: Node3D
var _tail_right: Node3D
var _left_eye: MeshInstance3D
var _right_eye: MeshInstance3D
var _mouth: MeshInstance3D
var _whiskers: Array[MeshInstance3D] = []
var _whisker_base_quaternions: Array[Quaternion] = []
var _current_state := ""
var _movement_strength := 0.0
var _swim_phase := 0.0
var _voice_player: AudioStreamPlayer3D
var _movement_mode := MovementMode.SWIMMING
var _safe_floe: Node3D
var _voice_expression_time := 0.0
var _catch_expression_time := 0.0
var _boosting_visual := false
var _breach_charge := 0.0
var _breach_cooldown := 0.0
var _breach_has_left_water := false
var _breach_peak_height := 0.0
var _completed_breaches := 0
var _ice_idle_time := 0.0
var _ice_idle_amount := 0.0
var _menu_idle_active := false


func _ready() -> void:
	add_to_group("player")
	_build_collision()
	_build_flaki_model()
	_build_voice()
	_set_state("STATE_SURFACE")


func _physics_process(delta: float) -> void:
	if not _menu_idle_active and Input.is_action_just_pressed("flaki_voice"):
		_play_voice()
	_voice_expression_time = maxf(_voice_expression_time - delta, 0.0)
	_catch_expression_time = maxf(_catch_expression_time - delta, 0.0)
	_breach_cooldown = maxf(_breach_cooldown - delta, 0.0)
	if (
		_movement_mode == MovementMode.ON_ICE
		and _voice_expression_time <= 0.0
	):
		_ice_idle_time += delta
	else:
		_ice_idle_time = 0.0
	var idle_target := 1.0 if _ice_idle_time >= ICE_IDLE_DELAY else 0.0
	_ice_idle_amount = move_toward(
		_ice_idle_amount,
		idle_target,
		delta * (1.35 if idle_target > 0.0 else 4.5)
	)

	if _menu_idle_active:
		velocity = Vector3.ZERO
		_movement_strength = 0.0
		_boosting_visual = false
		_animate_ice_pose(delta)
		_animate_face(delta)
		return

	if _movement_mode == MovementMode.BREACHING:
		_physics_process_breach(delta)
		_animate_face(delta)
		return

	if _movement_mode != MovementMode.SWIMMING:
		velocity = Vector3.ZERO
		_movement_strength = 0.0
		_boosting_visual = false
		if is_on_ice():
			_animate_ice_pose(delta)
		else:
			_animate_body(delta, 0.0)
		_animate_face(delta)
		return

	var input_2d := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	var vertical_input := Input.get_axis("dive_down", "swim_up")
	var camera := get_viewport().get_camera_3d()
	var horizontal_direction := Vector3.ZERO

	if camera and input_2d.length_squared() > 0.001:
		var camera_forward := -camera.global_basis.z
		camera_forward.y = 0.0
		camera_forward = camera_forward.normalized()
		var camera_right := camera.global_basis.x
		camera_right.y = 0.0
		camera_right = camera_right.normalized()
		horizontal_direction = (
			camera_right * input_2d.x
			+ camera_forward * -input_2d.y
		).normalized()

	var boosting := Input.is_action_pressed("boost") and horizontal_direction != Vector3.ZERO
	_boosting_visual = boosting
	var current_speed := swim_speed * (boost_multiplier if boosting else 1.0)
	var desired_velocity := horizontal_direction * current_speed
	desired_velocity.y = vertical_input * vertical_speed

	var response := acceleration * delta
	velocity = velocity.move_toward(desired_velocity, response)

	if horizontal_direction != Vector3.ZERO:
		var wanted_yaw := atan2(-horizontal_direction.x, -horizontal_direction.z)
		rotation.y = lerp_angle(rotation.y, wanted_yaw, turning_speed * delta)

	_apply_boundary_current(delta)
	move_and_slide()
	_limit_swimming_volume()
	if _update_breach_charge(delta, vertical_input):
		_animate_breach(delta)
		_animate_face(delta)
		return
	_update_state(boosting, vertical_input, horizontal_direction)
	_movement_strength = clampf(velocity.length() / (swim_speed * boost_multiplier), 0.0, 1.0)
	_animate_body(delta, vertical_input)
	_animate_face(delta)


func is_swimming() -> bool:
	return _movement_mode == MovementMode.SWIMMING


func is_transitioning() -> bool:
	return _movement_mode in [MovementMode.TRANSITION, MovementMode.BREACHING]


func is_breaching() -> bool:
	return _movement_mode == MovementMode.BREACHING


func get_completed_breach_count() -> int:
	return _completed_breaches


func get_breach_peak_height() -> float:
	return _breach_peak_height


func force_breach_for_test() -> bool:
	if _movement_mode != MovementMode.SWIMMING:
		return false
	global_position.y = water_level - SURFACE_BODY_OFFSET
	velocity = -global_basis.z * (swim_speed * 1.08)
	_start_breach()
	return true


func is_on_ice() -> bool:
	return _movement_mode in [MovementMode.ON_ICE, MovementMode.VICTORY]


func is_safe_from_shark() -> bool:
	return is_on_ice() or get_cave_shelter() != null


func get_cave_shelter() -> Node3D:
	for shelter in get_tree().get_nodes_in_group("shark_shelter"):
		if shelter.contains_point(global_position):
			return shelter
	return null


func begin_on_ice(start_position: Vector3, safe_floe: Node3D) -> void:
	_movement_mode = MovementMode.ON_ICE
	_safe_floe = safe_floe
	velocity = Vector3.ZERO
	global_position = start_position
	_ice_idle_time = 0.0
	_ice_idle_amount = 0.0
	_set_state("STATE_RESTING")


func set_menu_idle_active(active: bool) -> void:
	_menu_idle_active = active
	process_mode = (
		Node.PROCESS_MODE_ALWAYS
		if active
		else Node.PROCESS_MODE_INHERIT
	)
	if active:
		velocity = Vector3.ZERO


func is_menu_idle_active() -> bool:
	return _menu_idle_active


func is_ice_pose_relaxed() -> bool:
	return (
		is_on_ice()
		and absf(_visual_root.position.y + 0.10) < 0.035
		and _left_flipper.position.distance_to(LEFT_FLIPPER_ICE_POSITION) < 0.06
		and _right_flipper.position.distance_to(RIGHT_FLIPPER_ICE_POSITION) < 0.06
		and absf(_left_flipper.rotation.y - ICE_FLIPPER_SWEEP) < 0.10
		and absf(_right_flipper.rotation.y + ICE_FLIPPER_SWEEP) < 0.10
		and absf(_left_flipper.rotation.z - ICE_FLIPPER_ROLL) < 0.10
		and absf(_right_flipper.rotation.z + ICE_FLIPPER_ROLL) < 0.10
	)


func force_ice_idle_for_test() -> bool:
	if _movement_mode != MovementMode.ON_ICE:
		return false
	_ice_idle_time = ICE_IDLE_DELAY + 1.40
	_ice_idle_amount = 1.0
	return true


func is_ice_idle_animation_active() -> bool:
	return _movement_mode == MovementMode.ON_ICE and _ice_idle_amount > 0.70


func get_ice_idle_head_turn_degrees() -> float:
	if not is_instance_valid(_head_root):
		return 0.0
	return absf(rad_to_deg(_head_root.rotation.y))


func get_ice_idle_whisker_motion_degrees() -> float:
	var maximum_motion := 0.0
	for whisker_index in mini(_whiskers.size(), _whisker_base_quaternions.size()):
		if not is_instance_valid(_whiskers[whisker_index]):
			continue
		maximum_motion = maxf(
			maximum_motion,
			rad_to_deg(
				_whisker_base_quaternions[whisker_index].angle_to(
					_whiskers[whisker_index].quaternion
				)
			)
		)
	return maximum_motion


func leave_victory_pose() -> void:
	if _movement_mode != MovementMode.VICTORY:
		return
	_movement_mode = MovementMode.ON_ICE
	velocity = Vector3.ZERO
	_set_state("STATE_RESTING")


func respawn_on_ice(respawn_position: Vector3, safe_floe: Node3D) -> void:
	_movement_mode = MovementMode.ON_ICE
	_safe_floe = safe_floe
	velocity = Vector3.ZERO
	global_position = respawn_position
	_set_state("STATE_SAVED")


func start_victory_sequence(
	water_position: Vector3,
	landing_position: Vector3,
	safe_floe: Node3D
) -> void:
	var already_on_ice := is_on_ice()
	_movement_mode = MovementMode.TRANSITION
	_safe_floe = safe_floe
	velocity = Vector3.ZERO
	_set_state("STATE_RETURNING_WITH_CATCH")

	var victory_tween := create_tween()
	victory_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if already_on_ice:
		victory_tween.tween_property(self, "global_position", landing_position, 1.15)
		victory_tween.tween_callback(_finish_victory_pose)
		return
	if global_position.distance_to(landing_position) > 3.0:
		var travel_duration := clampf(
			global_position.distance_to(water_position) / 6.2,
			2.4,
			6.5
		)
		victory_tween.tween_property(self, "global_position", water_position, travel_duration)
	var midpoint := water_position.lerp(landing_position, 0.58)
	midpoint.y = maxf(water_position.y, landing_position.y) + 0.86
	victory_tween.tween_property(self, "global_position", midpoint, 0.72)
	victory_tween.tween_property(self, "global_position", landing_position, 0.62)
	victory_tween.tween_callback(_finish_victory_pose)


func _finish_victory_pose() -> void:
	_movement_mode = MovementMode.VICTORY
	velocity = Vector3.ZERO
	_set_state("STATE_VICTORY")
	victory_pose_ready.emit()


func climb_onto_ice(landing_position: Vector3, safe_floe: Node3D) -> void:
	if not is_swimming():
		return
	_movement_mode = MovementMode.TRANSITION
	_safe_floe = safe_floe
	velocity = Vector3.ZERO
	_set_state("STATE_CLIMBING")

	var midpoint := global_position.lerp(landing_position, 0.54)
	midpoint.y = maxf(global_position.y, landing_position.y) + 0.58
	var landing_hover := landing_position + Vector3.UP * 0.10
	var climb_tween := create_tween()
	climb_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	climb_tween.tween_property(self, "global_position", midpoint, 0.36)
	climb_tween.tween_property(self, "global_position", landing_hover, 0.24)
	climb_tween.tween_property(self, "global_position", landing_position, 0.16)
	climb_tween.tween_callback(_finish_climb)


func enter_water(water_position: Vector3) -> void:
	if _movement_mode != MovementMode.ON_ICE:
		return
	_movement_mode = MovementMode.TRANSITION
	_set_state("STATE_ENTERING_WATER")

	var midpoint := global_position.lerp(water_position, 0.52)
	midpoint.y = maxf(water_position.y + 0.82, global_position.y - 0.18)
	var entry_tween := create_tween()
	entry_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	entry_tween.tween_property(self, "global_position", midpoint, 0.30)
	entry_tween.tween_property(self, "global_position", water_position, 0.34)
	entry_tween.tween_callback(_finish_water_entry)


func _finish_climb() -> void:
	_movement_mode = MovementMode.ON_ICE
	_set_state("STATE_RESTING")


func _finish_water_entry() -> void:
	_movement_mode = MovementMode.SWIMMING
	_safe_floe = null
	global_position.y = water_level - SURFACE_BODY_OFFSET
	_set_state("STATE_SURFACE")


func _update_breach_charge(delta: float, vertical_input: float) -> bool:
	var surface_height := water_level - SURFACE_BODY_OFFSET
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var can_charge := (
		_breach_cooldown <= 0.0
		and vertical_input > 0.65
		and global_position.y >= surface_height - 0.045
		and horizontal_speed >= BREACH_MIN_SPEED
	)
	if not can_charge:
		_breach_charge = 0.0
		return false
	_breach_charge += delta
	if _breach_charge < BREACH_CHARGE_TIME:
		return false
	_start_breach()
	return true


func _start_breach() -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() < 0.01:
		horizontal_velocity = -global_basis.z * swim_speed
	var launch_speed := maxf(horizontal_velocity.length(), swim_speed * 1.04)
	velocity = horizontal_velocity.normalized() * launch_speed
	velocity.y = BREACH_UP_SPEED + clampf(
		(launch_speed - swim_speed) * 0.18,
		0.0,
		0.72
	)
	_movement_mode = MovementMode.BREACHING
	_breach_charge = 0.0
	_breach_has_left_water = false
	_breach_peak_height = global_position.y
	_boosting_visual = true
	_set_state("STATE_BREACH")
	breach_started.emit(global_position, launch_speed)


func _physics_process_breach(delta: float) -> void:
	velocity.y -= BREACH_GRAVITY * delta
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		Vector3.ZERO,
		delta * 0.24
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	move_and_slide()
	_apply_breach_boundary()
	_breach_peak_height = maxf(_breach_peak_height, global_position.y)
	var surface_height := water_level - SURFACE_BODY_OFFSET
	if global_position.y > surface_height + 0.10:
		_breach_has_left_water = true
	_movement_strength = clampf(
		horizontal_velocity.length() / (swim_speed * boost_multiplier),
		0.0,
		1.0
	)
	_animate_breach(delta)
	if (
		_breach_has_left_water
		and global_position.y <= surface_height
		and velocity.y < 0.0
	):
		_finish_breach(horizontal_velocity.length())


func _finish_breach(impact_speed: float) -> void:
	var splash_position := global_position
	splash_position.y = water_level + 0.03
	_movement_mode = MovementMode.SWIMMING
	global_position.y = water_level - SURFACE_BODY_OFFSET - 0.10
	velocity.x *= 0.76
	velocity.z *= 0.76
	velocity.y = -0.95
	_breach_cooldown = 1.25
	_breach_charge = 0.0
	_boosting_visual = false
	_completed_breaches += 1
	_set_state("STATE_SPLASH")
	splash_landed.emit(splash_position, impact_speed)


func _apply_breach_boundary() -> void:
	if maximum_swim_radius <= 0.0:
		return
	var flat_position := Vector2(global_position.x, global_position.z)
	if flat_position.length() <= maximum_swim_radius:
		return
	var inward_edge := flat_position.normalized() * maximum_swim_radius
	global_position.x = inward_edge.x
	global_position.z = inward_edge.y
	var outward_normal := Vector3(flat_position.x, 0.0, flat_position.y).normalized()
	var outward_speed := velocity.dot(outward_normal)
	if outward_speed > 0.0:
		velocity -= outward_normal * outward_speed


func play_voice_for_test() -> bool:
	return _play_voice()


func _play_voice() -> bool:
	if not is_instance_valid(_voice_player) or _voice_player.playing:
		return false
	_voice_player.play()
	_voice_expression_time = 0.68
	voice_played.emit(global_position)
	return true


func play_catch_animation() -> void:
	_catch_expression_time = 0.56


func _limit_swimming_volume() -> void:
	var surface_height := water_level - SURFACE_BODY_OFFSET
	if global_position.y > surface_height:
		global_position.y = surface_height
		velocity.y = minf(velocity.y, 0.0)
	if global_position.y < minimum_depth:
		global_position.y = minimum_depth
		velocity.y = maxf(velocity.y, 0.0)

	if maximum_swim_radius > 0.0:
		var flat_position := Vector2(global_position.x, global_position.z)
		if flat_position.length() > maximum_swim_radius:
			var inward_edge := flat_position.normalized() * maximum_swim_radius
			var outward_normal := Vector3(flat_position.x, 0.0, flat_position.y).normalized()
			global_position.x = inward_edge.x
			global_position.z = inward_edge.y
			var outward_speed := velocity.dot(outward_normal)
			if outward_speed > 0.0:
				velocity -= outward_normal * outward_speed


func _apply_boundary_current(delta: float) -> void:
	if maximum_swim_radius <= 0.0:
		return
	var flat_position := Vector2(global_position.x, global_position.z)
	var current_start := maximum_swim_radius - 4.5
	if flat_position.length() <= current_start:
		return
	var outward_normal := Vector3(flat_position.x, 0.0, flat_position.y).normalized()
	var edge_pressure := clampf(
		(flat_position.length() - current_start) / 4.5,
		0.0,
		1.0
	)
	velocity -= outward_normal * edge_pressure * 7.5 * delta


func _update_state(boosting: bool, vertical_input: float, direction: Vector3) -> void:
	if boosting:
		_set_state("STATE_BOOST")
	elif vertical_input < -0.1 or global_position.y < water_level - 1.35:
		_set_state("STATE_DIVE")
	elif direction == Vector3.ZERO and absf(vertical_input) < 0.1:
		_set_state("STATE_DRIFT")
	else:
		_set_state("STATE_SURFACE")


func _set_state(title: String) -> void:
	if title == _current_state:
		return
	_current_state = title
	state_changed.emit(title)


func _animate_body(delta: float, vertical_input: float) -> void:
	if not is_instance_valid(_visual_root):
		return
	var time := Time.get_ticks_msec() * 0.001
	var stroke_speed := lerpf(2.2, 9.4, _movement_strength)
	if _boosting_visual:
		stroke_speed *= 1.25
	_swim_phase = fmod(_swim_phase + delta * stroke_speed, TAU)
	var stroke := sin(_swim_phase)
	var amplitude := lerpf(0.035, 0.20, _movement_strength)
	if _boosting_visual:
		amplitude *= 1.16
	var pose_weight := minf(delta * 7.0, 1.0)
	_left_flipper.position = _left_flipper.position.lerp(
		LEFT_FLIPPER_SWIM_POSITION,
		pose_weight
	)
	_right_flipper.position = _right_flipper.position.lerp(
		RIGHT_FLIPPER_SWIM_POSITION,
		pose_weight
	)
	_left_flipper.rotation.x = lerpf(_left_flipper.rotation.x, deg_to_rad(7.0), pose_weight)
	_left_flipper.rotation.y = lerpf(_left_flipper.rotation.y, deg_to_rad(-8.0), pose_weight)
	_right_flipper.rotation.x = lerpf(_right_flipper.rotation.x, deg_to_rad(-7.0), pose_weight)
	_right_flipper.rotation.y = lerpf(_right_flipper.rotation.y, deg_to_rad(8.0), pose_weight)
	_left_flipper.rotation.z = -0.34 + stroke * amplitude
	_right_flipper.rotation.z = 0.34 - stroke * amplitude
	_tail_left.rotation.y = -0.18 + stroke * lerpf(0.04, 0.48, _movement_strength)
	_tail_right.rotation.y = 0.18 + stroke * lerpf(0.04, 0.48, _movement_strength)
	_visual_root.position.y = lerpf(
		_visual_root.position.y,
		sin(time * 2.0) * 0.035,
		pose_weight
	)
	_visual_root.rotation.x = lerpf(
		_visual_root.rotation.x,
		clampf(-vertical_input * 0.22, -0.22, 0.22),
		4.0 * delta
	)
	_visual_root.rotation.z = lerpf(
		_visual_root.rotation.z,
		stroke * amplitude * 0.08,
		4.5 * delta
	)


func _animate_breach(delta: float) -> void:
	if not is_instance_valid(_visual_root):
		return
	var pose_weight := minf(delta * 8.5, 1.0)
	var pitch_target := clampf(velocity.y * 0.075, -0.34, 0.34)
	_visual_root.position.y = lerpf(_visual_root.position.y, 0.0, pose_weight)
	_left_flipper.position = _left_flipper.position.lerp(
		LEFT_FLIPPER_SWIM_POSITION,
		pose_weight
	)
	_right_flipper.position = _right_flipper.position.lerp(
		RIGHT_FLIPPER_SWIM_POSITION,
		pose_weight
	)
	_visual_root.rotation.x = lerpf(
		_visual_root.rotation.x,
		pitch_target,
		pose_weight
	)
	_visual_root.rotation.z = lerpf(
		_visual_root.rotation.z,
		sin(Time.get_ticks_msec() * 0.008) * 0.055,
		pose_weight
	)
	_left_flipper.rotation.z = lerpf(
		_left_flipper.rotation.z,
		deg_to_rad(-30.0),
		pose_weight
	)
	_right_flipper.rotation.z = lerpf(
		_right_flipper.rotation.z,
		deg_to_rad(30.0),
		pose_weight
	)
	_tail_left.rotation.y = lerpf(
		_tail_left.rotation.y,
		deg_to_rad(-12.0),
		pose_weight
	)
	_tail_right.rotation.y = lerpf(
		_tail_right.rotation.y,
		deg_to_rad(12.0),
		pose_weight
	)


func _animate_ice_pose(delta: float) -> void:
	if not is_instance_valid(_visual_root):
		return
	var time := Time.get_ticks_msec() * 0.001
	var pose_weight := minf(delta * 7.5, 1.0)
	var breathing_height := -0.10 + sin(time * 1.7) * 0.008
	_visual_root.position.y = lerpf(_visual_root.position.y, breathing_height, pose_weight)
	_visual_root.rotation.x = lerpf(_visual_root.rotation.x, 0.0, pose_weight)
	_visual_root.rotation.z = lerpf(_visual_root.rotation.z, 0.0, pose_weight)
	_left_flipper.position = _left_flipper.position.lerp(
		LEFT_FLIPPER_ICE_POSITION,
		pose_weight
	)
	_right_flipper.position = _right_flipper.position.lerp(
		RIGHT_FLIPPER_ICE_POSITION,
		pose_weight
	)
	_left_flipper.rotation.x = lerpf(
		_left_flipper.rotation.x,
		0.0,
		pose_weight
	)
	_left_flipper.rotation.y = lerpf(
		_left_flipper.rotation.y,
		ICE_FLIPPER_SWEEP,
		pose_weight
	)
	_left_flipper.rotation.z = lerpf(
		_left_flipper.rotation.z,
		ICE_FLIPPER_ROLL,
		pose_weight
	)
	_right_flipper.rotation.x = lerpf(
		_right_flipper.rotation.x,
		0.0,
		pose_weight
	)
	_right_flipper.rotation.y = lerpf(
		_right_flipper.rotation.y,
		-ICE_FLIPPER_SWEEP,
		pose_weight
	)
	_right_flipper.rotation.z = lerpf(
		_right_flipper.rotation.z,
		-ICE_FLIPPER_ROLL,
		pose_weight
	)
	var happy_tail := sin(time * 2.4) * (0.06 if _movement_mode == MovementMode.VICTORY else 0.0)
	_tail_left.rotation.y = lerpf(
		_tail_left.rotation.y,
		deg_to_rad(-28.0) + happy_tail,
		pose_weight
	)
	_tail_right.rotation.y = lerpf(
		_tail_right.rotation.y,
		deg_to_rad(28.0) - happy_tail,
		pose_weight
	)


func _animate_face(delta: float) -> void:
	if not is_instance_valid(_head_root):
		return
	var time := Time.get_ticks_msec() * 0.001
	var voice_amount := clampf(_voice_expression_time / 0.68, 0.0, 1.0)
	var catch_amount := clampf(_catch_expression_time / 0.56, 0.0, 1.0)
	var voice_pulse := sin((1.0 - voice_amount) * PI) if voice_amount > 0.0 else 0.0
	var catch_pulse := sin((1.0 - catch_amount) * PI) if catch_amount > 0.0 else 0.0
	var idle_clock := maxf(_ice_idle_time - ICE_IDLE_DELAY, 0.0)
	var idle_head_yaw := (
		sin(idle_clock * 0.67) * ICE_IDLE_MAX_HEAD_YAW
		+ sin(idle_clock * 0.21 + 0.45) * deg_to_rad(3.0)
	) * _ice_idle_amount
	var idle_head_pitch := (
		sin(idle_clock * 0.48 + 0.80)
		* deg_to_rad(2.8)
		* _ice_idle_amount
	)
	var idle_head_roll := (
		sin(idle_clock * 0.67 + 0.30)
		* deg_to_rad(1.8)
		* _ice_idle_amount
	)
	var target_head_position := Vector3(0.0, 0.12, -0.82)
	target_head_position.y += voice_pulse * 0.08
	target_head_position.z -= catch_pulse * 0.18
	_head_root.position = _head_root.position.lerp(target_head_position, minf(delta * 13.0, 1.0))
	_head_root.rotation.x = lerpf(
		_head_root.rotation.x,
		-voice_pulse * 0.16 + catch_pulse * 0.10 + idle_head_pitch,
		minf(delta * 11.0, 1.0)
	)
	_head_root.rotation.y = lerp_angle(
		_head_root.rotation.y,
		idle_head_yaw,
		minf(delta * 3.2, 1.0)
	)
	_head_root.rotation.z = lerp_angle(
		_head_root.rotation.z,
		idle_head_roll,
		minf(delta * 3.2, 1.0)
	)

	var whisker_twitch_envelope := pow(
		maxf(sin(idle_clock * 1.15), 0.0),
		6.0
	)
	for whisker_index in mini(_whiskers.size(), _whisker_base_quaternions.size()):
		var whisker := _whiskers[whisker_index]
		if not is_instance_valid(whisker):
			continue
		var slow_whisker_motion := sin(
			idle_clock * 1.85 + float(whisker_index) * 0.82
		) * 0.012
		var quick_whisker_twitch := sin(
			idle_clock * 9.2 + float(whisker_index) * 1.31
		) * 0.060 * whisker_twitch_envelope
		var whisker_angle := (
			(slow_whisker_motion + quick_whisker_twitch)
			* _ice_idle_amount
		)
		var target_whisker_quaternion := (
			_whisker_base_quaternions[whisker_index]
			* Quaternion(Vector3.FORWARD, whisker_angle)
		)
		whisker.quaternion = whisker.quaternion.slerp(
			target_whisker_quaternion,
			minf(delta * 9.0, 1.0)
		)

	var blink_phase := fmod(time + 0.37, 4.6)
	var blink_scale := 1.0
	if blink_phase < 0.15:
		blink_scale = lerpf(0.12, 1.0, absf(blink_phase - 0.075) / 0.075)
	if voice_amount > 0.0:
		blink_scale = maxf(blink_scale, 0.72)
	if is_instance_valid(_left_eye):
		_left_eye.scale.y = lerpf(
			_left_eye.scale.y,
			0.118 * blink_scale,
			minf(delta * 24.0, 1.0)
		)
	if is_instance_valid(_right_eye):
		_right_eye.scale.y = lerpf(
			_right_eye.scale.y,
			0.118 * blink_scale,
			minf(delta * 24.0, 1.0)
		)
	if is_instance_valid(_mouth):
		var mouth_open := 0.34 + voice_pulse * 1.65 + catch_pulse * 0.85
		_mouth.scale.y = lerpf(
			_mouth.scale.y,
			0.055 * mouth_open,
			minf(delta * 18.0, 1.0)
		)

	_visual_root.update_pose(_movement_strength if is_swimming() else 0.0, _swim_phase)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.52
	capsule.height = 2.25
	collision.shape = capsule
	collision.rotation_degrees.x = 90.0
	add_child(collision)


func _build_voice() -> void:
	_voice_player = AudioStreamPlayer3D.new()
	_voice_player.name = "FlakiVoice"
	_voice_player.stream = FLAKI_VOICE
	_voice_player.volume_db = -6.0
	_voice_player.max_distance = 55.0
	_voice_player.unit_size = 4.0
	add_child(_voice_player)


func _build_flaki_model() -> void:
	var model := SEAL_MODEL.new()
	_visual_root = model
	add_child(model)
	_head_root = model.head
	_left_flipper = model.left_flipper
	_right_flipper = model.right_flipper
	_tail_left = model.tail_left
	_tail_right = model.tail_right
	_left_eye = model.left_eye
	_right_eye = model.right_eye
	_mouth = model.mouth
	_whiskers = model.whiskers
	for whisker in _whiskers:
		_whisker_base_quaternions.append(whisker.quaternion)
	_left_flipper.position = LEFT_FLIPPER_SWIM_POSITION
	_right_flipper.position = RIGHT_FLIPPER_SWIM_POSITION
