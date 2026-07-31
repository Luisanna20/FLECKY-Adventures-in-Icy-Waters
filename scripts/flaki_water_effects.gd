class_name FlakiWaterEffects
extends Node3D

const RIPPLE_POOL_SIZE := 18
const TRAIL_RIPPLE_SPACING := 1.25
const SPLASH_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/water/splash_01.ogg"),
	preload("res://assets/audio/sfx/water/splash_04.ogg"),
	preload("res://assets/audio/sfx/water/splash_07.ogg"),
	preload("res://assets/audio/sfx/water/splash_11.ogg"),
]

var swimmer: FlakiController
var water_level := 0.0
var _water_material: ShaderMaterial
var _bubbles: GPUParticles3D
var _wake: GPUParticles3D
var _splash: GPUParticles3D
var _splash_audio: AudioStreamPlayer3D
var _ripples: Array[Dictionary] = []
var _next_ripple := 0
var _last_splash_stream := -1
var _last_surface_position := Vector3.ZERO
var _trail_distance := 0.0
var _trail_initialized := false
var _trail_ripple_count := 0
var _splash_count := 0
var _audio_random := RandomNumberGenerator.new()


func configure(
	target: FlakiController,
	surface_height: float,
	interactive_water_material: ShaderMaterial = null
) -> void:
	swimmer = target
	water_level = surface_height
	_water_material = interactive_water_material
	_build_bubbles()
	_build_wake()
	_build_splash()
	_build_splash_audio()
	_build_ripple_pool()
	_audio_random.randomize()
	if not swimmer.breach_started.is_connected(_on_breach_started):
		swimmer.breach_started.connect(_on_breach_started)
	if not swimmer.splash_landed.is_connected(_on_splash_landed):
		swimmer.splash_landed.connect(_on_splash_landed)


func _process(delta: float) -> void:
	if not is_instance_valid(swimmer):
		return
	global_position = swimmer.global_position
	global_rotation = swimmer.global_rotation

	var depth := water_level - swimmer.global_position.y - 0.48
	var horizontal_velocity := Vector3(
		swimmer.velocity.x,
		0.0,
		swimmer.velocity.z
	)
	var horizontal_speed := horizontal_velocity.length()
	var near_surface := depth > -0.22 and depth < 0.38
	var making_wake := (
		swimmer.is_swimming()
		and near_surface
		and horizontal_speed > 1.15
	)
	_bubbles.emitting = (
		depth > 0.65
		and (swimmer.velocity.y < -0.10 or swimmer.velocity.length() > 2.0)
	)
	_wake.emitting = making_wake
	_update_interactive_water(horizontal_velocity, horizontal_speed, making_wake)
	_update_surface_trail(making_wake)
	_update_ripples(delta)


func get_trail_ripple_count() -> int:
	return _trail_ripple_count


func get_splash_count() -> int:
	return _splash_count


func is_interactive_water_ready() -> bool:
	return (
		is_instance_valid(_water_material)
		and _ripples.size() == RIPPLE_POOL_SIZE
		and is_instance_valid(_splash)
		and is_instance_valid(_splash_audio)
		and SPLASH_STREAMS.size() == 4
	)


func _update_interactive_water(
	horizontal_velocity: Vector3,
	horizontal_speed: float,
	making_wake: bool
) -> void:
	if not is_instance_valid(_water_material):
		return
	var forward := Vector2(-swimmer.global_basis.z.x, -swimmer.global_basis.z.z).normalized()
	if horizontal_velocity.length_squared() > 0.01:
		forward = Vector2(horizontal_velocity.x, horizontal_velocity.z).normalized()
	_water_material.set_shader_parameter(
		"swimmer_position",
		Vector2(swimmer.global_position.x, swimmer.global_position.z)
	)
	_water_material.set_shader_parameter("swimmer_forward", forward)
	_water_material.set_shader_parameter(
		"swimmer_speed",
		clampf(horizontal_speed / (swimmer.swim_speed * swimmer.boost_multiplier), 0.0, 1.0)
	)
	_water_material.set_shader_parameter("swimmer_surface", 1.0 if making_wake else 0.0)


func _update_surface_trail(making_wake: bool) -> void:
	var surface_position := swimmer.global_position
	surface_position.y = water_level + 0.045
	if not making_wake:
		_trail_initialized = false
		_trail_distance = 0.0
		return
	if not _trail_initialized:
		_last_surface_position = surface_position
		_trail_initialized = true
		return

	var travelled := Vector2(
		surface_position.x - _last_surface_position.x,
		surface_position.z - _last_surface_position.z
	).length()
	if travelled > 4.0:
		_last_surface_position = surface_position
		_trail_distance = 0.0
		return
	_trail_distance += travelled
	_last_surface_position = surface_position
	if _trail_distance < TRAIL_RIPPLE_SPACING:
		return
	_trail_distance = fmod(_trail_distance, TRAIL_RIPPLE_SPACING)
	var trail_position := surface_position + swimmer.global_basis.z * 0.78
	_spawn_ripple(trail_position, swimmer.global_rotation.y, false)
	_trail_ripple_count += 1


func _build_bubbles() -> void:
	_bubbles = GPUParticles3D.new()
	_bubbles.name = "DiveBubbles"
	_bubbles.amount = 54
	_bubbles.lifetime = 2.4
	_bubbles.randomness = 0.55
	_bubbles.local_coords = false
	_bubbles.position = Vector3(0.0, 0.20, 0.75)
	_bubbles.visibility_aabb = AABB(Vector3(-8.0, -8.0, -8.0), Vector3(16.0, 16.0, 16.0))

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.28
	process_material.direction = Vector3.UP
	process_material.spread = 18.0
	process_material.gravity = Vector3(0.0, 0.62, 0.0)
	process_material.initial_velocity_min = 0.30
	process_material.initial_velocity_max = 0.85
	process_material.scale_min = 0.45
	process_material.scale_max = 1.25
	process_material.color = Color(0.72, 0.94, 1.0, 0.46)
	_bubbles.process_material = process_material

	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.045
	bubble_mesh.height = 0.09
	bubble_mesh.radial_segments = 8
	bubble_mesh.rings = 4
	bubble_mesh.material = _particle_material(Color(0.70, 0.94, 1.0, 0.42))
	_bubbles.draw_pass_1 = bubble_mesh
	add_child(_bubbles)


func _build_wake() -> void:
	_wake = GPUParticles3D.new()
	_wake.name = "SurfaceWakeTrail"
	_wake.amount = 128
	_wake.lifetime = 2.15
	_wake.randomness = 0.62
	_wake.local_coords = false
	_wake.position = Vector3(0.0, 0.50, 1.02)
	_wake.visibility_aabb = AABB(Vector3(-18.0, -3.0, -18.0), Vector3(36.0, 6.0, 36.0))

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.34
	process_material.direction = Vector3(0.0, 0.08, 1.0)
	process_material.spread = 44.0
	process_material.gravity = Vector3(0.0, -0.02, 0.0)
	process_material.initial_velocity_min = 0.10
	process_material.initial_velocity_max = 0.48
	process_material.scale_min = 0.30
	process_material.scale_max = 0.92
	process_material.color = Color(0.74, 0.94, 0.97, 0.40)
	_wake.process_material = process_material

	var foam_mesh := SphereMesh.new()
	foam_mesh.radius = 0.048
	foam_mesh.height = 0.020
	foam_mesh.radial_segments = 8
	foam_mesh.rings = 3
	foam_mesh.material = _particle_material(Color(0.76, 0.95, 0.98, 0.42))
	_wake.draw_pass_1 = foam_mesh
	add_child(_wake)


func _build_splash() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "BreachSplash"
	_splash.amount = 86
	_splash.lifetime = 1.15
	_splash.one_shot = true
	_splash.explosiveness = 1.0
	_splash.randomness = 0.72
	_splash.local_coords = false
	_splash.emitting = false
	_splash.top_level = true
	_splash.visibility_aabb = AABB(Vector3(-9.0, -5.0, -9.0), Vector3(18.0, 10.0, 18.0))

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.48
	process_material.direction = Vector3.UP
	process_material.spread = 67.0
	process_material.gravity = Vector3(0.0, -7.1, 0.0)
	process_material.initial_velocity_min = 2.1
	process_material.initial_velocity_max = 4.7
	process_material.scale_min = 0.55
	process_material.scale_max = 1.45
	process_material.color = Color(0.74, 0.95, 1.0, 0.72)
	_splash.process_material = process_material

	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.042
	droplet_mesh.height = 0.095
	droplet_mesh.radial_segments = 8
	droplet_mesh.rings = 4
	droplet_mesh.material = _particle_material(Color(0.76, 0.96, 1.0, 0.72))
	_splash.draw_pass_1 = droplet_mesh
	add_child(_splash)


func _build_splash_audio() -> void:
	_splash_audio = AudioStreamPlayer3D.new()
	_splash_audio.name = "BreachSplashAudio"
	_splash_audio.volume_db = -4.5
	_splash_audio.max_distance = 48.0
	_splash_audio.unit_size = 3.5
	_splash_audio.top_level = true
	add_child(_splash_audio)


func _build_ripple_pool() -> void:
	var shared_mesh := TorusMesh.new()
	shared_mesh.inner_radius = 0.235
	shared_mesh.outer_radius = 0.270
	shared_mesh.rings = 32
	shared_mesh.ring_segments = 6
	for ripple_index in RIPPLE_POOL_SIZE:
		var ripple := MeshInstance3D.new()
		ripple.name = "WakeRipple_%02d" % ripple_index
		ripple.mesh = shared_mesh
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ripple.visible = false
		var material := _particle_material(Color(0.78, 0.97, 1.0, 0.0))
		material.no_depth_test = false
		ripple.material_override = material
		get_parent().add_child(ripple)
		_ripples.append({
			"node": ripple,
			"material": material,
			"age": 99.0,
			"lifetime": 1.8,
			"strong": false,
		})


func _spawn_ripple(position: Vector3, yaw: float, strong: bool) -> void:
	if _ripples.is_empty():
		return
	var data := _ripples[_next_ripple]
	_next_ripple = (_next_ripple + 1) % _ripples.size()
	var ripple := data["node"] as MeshInstance3D
	ripple.global_position = Vector3(position.x, water_level + 0.052, position.z)
	ripple.global_rotation = Vector3(0.0, yaw, 0.0)
	ripple.scale = Vector3.ONE
	ripple.visible = true
	data["age"] = 0.0
	data["lifetime"] = 1.42 if strong else 1.85
	data["strong"] = strong
	_ripples[_next_ripple - 1 if _next_ripple > 0 else _ripples.size() - 1] = data


func _update_ripples(delta: float) -> void:
	for ripple_index in _ripples.size():
		var data := _ripples[ripple_index]
		var ripple := data["node"] as MeshInstance3D
		if not ripple.visible:
			continue
		var age := float(data["age"]) + delta
		var lifetime := float(data["lifetime"])
		if age >= lifetime:
			ripple.visible = false
			data["age"] = age
			_ripples[ripple_index] = data
			continue
		var progress := age / lifetime
		var strong := bool(data["strong"])
		var expansion := lerpf(0.48, 2.85 if strong else 2.55, progress)
		ripple.scale = Vector3(
			expansion * (1.38 if strong else 1.24),
			0.30,
			expansion * (0.78 if strong else 0.62)
		)
		var fade := pow(1.0 - progress, 1.35)
		var material := data["material"] as StandardMaterial3D
		material.albedo_color = Color(
			0.78,
			0.97,
			1.0,
			fade * (0.27 if strong else 0.16)
		)
		data["age"] = age
		_ripples[ripple_index] = data


func _on_breach_started(position: Vector3, _speed: float) -> void:
	var launch_position := position
	launch_position.y = water_level + 0.045
	_spawn_ripple(launch_position, swimmer.global_rotation.y, true)


func _on_splash_landed(position: Vector3, speed: float) -> void:
	_splash_count += 1
	_splash.global_position = Vector3(position.x, water_level + 0.04, position.z)
	_splash.restart()
	_splash.emitting = true
	_spawn_ripple(position, swimmer.global_rotation.y, true)
	_play_splash_sound(position, speed)


func _play_splash_sound(position: Vector3, speed: float) -> void:
	if not is_instance_valid(_splash_audio) or SPLASH_STREAMS.is_empty():
		return
	var stream_index := _audio_random.randi_range(0, SPLASH_STREAMS.size() - 1)
	if SPLASH_STREAMS.size() > 1 and stream_index == _last_splash_stream:
		stream_index = (stream_index + 1) % SPLASH_STREAMS.size()
	_last_splash_stream = stream_index
	_splash_audio.stream = SPLASH_STREAMS[stream_index]
	_splash_audio.global_position = Vector3(position.x, water_level + 0.06, position.z)
	_splash_audio.pitch_scale = _audio_random.randf_range(0.94, 1.06)
	_splash_audio.volume_db = lerpf(-6.0, -2.8, clampf(speed / 8.0, 0.0, 1.0))
	_splash_audio.play()


func _particle_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
