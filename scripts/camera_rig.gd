class_name FlakiCameraRig
extends Node3D

@export var target: Node3D
@export_range(0.01, 1.0) var follow_smoothing := 0.12
@export_range(0.001, 0.02) var mouse_sensitivity := 0.003
@export var camera_distance := 6.5

const MENU_SHOT_DURATION := 7.5

var _yaw := 0.0
var _pitch := deg_to_rad(-14.0)
var _pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _victory_mode := false
var _menu_cinematic_active := false
var _menu_elapsed := 0.0
var _menu_shots: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.name = "CameraPivot"
	add_child(_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "CameraCollisionArm"
	_spring_arm.spring_length = camera_distance
	_spring_arm.margin = 0.2
	_spring_arm.collision_mask = 1
	_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.current = true
	_camera.fov = 68.0
	_camera.near = 0.08
	_spring_arm.add_child(_camera)


func _unhandled_input(event: InputEvent) -> void:
	if _victory_mode or _menu_cinematic_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(-65.0), _maximum_pitch())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if _menu_cinematic_active:
		_process_menu_cinematic(delta)
		return
	if not is_instance_valid(target):
		return

	if _victory_mode:
		_yaw += delta * 0.16
		_pitch = lerpf(_pitch, deg_to_rad(-24.0), delta * 1.8)
		_spring_arm.spring_length = lerpf(_spring_arm.spring_length, 5.8, delta * 1.7)
	else:
		_spring_arm.spring_length = lerpf(
			_spring_arm.spring_length,
			camera_distance,
			delta * 2.4
		)
		_pitch = minf(_pitch, _maximum_pitch())
	var wanted_position := target.global_position + Vector3.UP * 0.45
	global_position = global_position.lerp(wanted_position, follow_smoothing)
	rotation.y = _yaw
	_pivot.rotation.x = _pitch


func set_victory_mode(enabled: bool) -> void:
	_victory_mode = enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func configure_menu_cinematic(shots: Array[Dictionary]) -> void:
	_menu_shots = shots.duplicate(true)


func set_menu_cinematic(enabled: bool) -> void:
	_menu_cinematic_active = enabled and _menu_shots.size() >= 2
	if _menu_cinematic_active:
		_menu_elapsed = 0.0
		_apply_menu_cinematic_frame(0.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_pitch = deg_to_rad(-14.0)
		if is_instance_valid(_camera):
			_camera.fov = 68.0


func is_menu_cinematic_active() -> bool:
	return _menu_cinematic_active


func get_menu_shot_count() -> int:
	return _menu_shots.size()


func _process_menu_cinematic(delta: float) -> void:
	_menu_elapsed += delta
	_apply_menu_cinematic_frame(_menu_elapsed)


func _apply_menu_cinematic_frame(elapsed: float) -> void:
	if _menu_shots.size() < 2 or not is_instance_valid(_spring_arm):
		return
	var shot_progress: float = elapsed / MENU_SHOT_DURATION
	var shot_index: int = posmod(int(floor(shot_progress)), _menu_shots.size())
	var next_index: int = (shot_index + 1) % _menu_shots.size()
	var local_progress: float = shot_progress - floorf(shot_progress)
	var blend: float = 0.5 - cos(local_progress * PI) * 0.5
	var current_shot: Dictionary = _menu_shots[shot_index]
	var next_shot: Dictionary = _menu_shots[next_index]
	global_position = (
		current_shot["focus"] as Vector3
	).lerp(next_shot["focus"] as Vector3, blend)
	_yaw = lerp_angle(
		deg_to_rad(float(current_shot["yaw"])),
		deg_to_rad(float(next_shot["yaw"])),
		blend
	)
	_pitch = lerp_angle(
		deg_to_rad(float(current_shot["pitch"])),
		deg_to_rad(float(next_shot["pitch"])),
		blend
	)
	_spring_arm.spring_length = lerpf(
		float(current_shot["distance"]),
		float(next_shot["distance"]),
		blend
	)
	if is_instance_valid(_camera):
		_camera.fov = lerpf(
			float(current_shot["fov"]),
			float(next_shot["fov"]),
			blend
		)
	rotation.y = _yaw
	_pivot.rotation.x = _pitch


func is_victory_mode() -> bool:
	return _victory_mode


func set_preview_angles(yaw_degrees: float, pitch_degrees: float) -> void:
	_yaw = deg_to_rad(yaw_degrees)
	_pitch = deg_to_rad(pitch_degrees)


func _maximum_pitch() -> float:
	if target is FlakiController and (target as FlakiController).is_on_ice():
		return deg_to_rad(4.0)
	return deg_to_rad(45.0)


func set_sky_preview_mode() -> void:
	target = null
	global_position = Vector3(0.0, 4.0, 0.0)
	_yaw = deg_to_rad(-20.0)
	_pitch = deg_to_rad(25.0)
	rotation.y = _yaw
	_pivot.rotation.x = _pitch
	_spring_arm.spring_length = 0.5
