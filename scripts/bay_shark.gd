class_name BayShark
extends Node3D

const SHARK_SCENE := preload("res://assets/models/quaternius/shark.glb")
const SURFACE_WAKE_SHADER := preload("res://shaders/shark_surface_wake.gdshader")
const SWIM_NORMAL := &"SharkArmature|SharkArmature|SharkArmature|Swim|SharkArmature|Swim"
const SWIM_FAST := &"SharkArmature|SharkArmature|SharkArmature|Swim_Fast|SharkArmature|Swim_Fast"
const SWIM_BITE := &"SharkArmature|SharkArmature|SharkArmature|Swim_Bite|SharkArmature|Swim_Bite"

var swim_velocity := Vector3.ZERO
var _visual_root: Node3D
var _tail_left: MeshInstance3D
var _tail_right: MeshInstance3D
var _animation_player: AnimationPlayer
var _bite_animation_until_msec := 0
var _surface_wake: Node3D
var _surface_wake_material: ShaderMaterial
var _wake_particles: GPUParticles3D


func configure() -> void:
	_build_shark()
	visible = false


func swim_towards(target_position: Vector3, speed: float, delta: float) -> void:
	var direction := target_position - global_position
	if direction.length_squared() < 0.01:
		return
	direction = direction.normalized()
	var desired_velocity := direction * speed
	var response := 1.0 - exp(-2.8 * delta)
	swim_velocity = swim_velocity.lerp(desired_velocity, response)
	global_position += swim_velocity * delta
	global_position.y = clampf(global_position.y, -10.8, -0.72)

	if swim_velocity.length_squared() > 0.04:
		look_at(global_position + swim_velocity, Vector3.UP)
	_animate_tail(speed)
	_update_surface_wake(speed)


func stop_swimming() -> void:
	swim_velocity = Vector3.ZERO
	if is_instance_valid(_surface_wake):
		_surface_wake.visible = false
	if is_instance_valid(_wake_particles):
		_wake_particles.emitting = false


func is_surface_wake_ready() -> bool:
	return (
		is_instance_valid(_surface_wake)
		and is_instance_valid(_surface_wake_material)
		and is_instance_valid(_wake_particles)
	)


func play_bite() -> void:
	_bite_animation_until_msec = Time.get_ticks_msec() + 720
	if is_instance_valid(_animation_player):
		_animation_player.play(SWIM_BITE, 0.06)
		_animation_player.speed_scale = 1.18


func _animate_tail(speed: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	_visual_root.rotation.z = sin(time * 2.2) * 0.025
	if is_instance_valid(_animation_player):
		if Time.get_ticks_msec() < _bite_animation_until_msec:
			return
		var speed_ratio := clampf(speed / 8.0, 0.0, 1.0)
		var wanted_animation := SWIM_FAST if speed_ratio > 0.72 else SWIM_NORMAL
		if _animation_player.current_animation != wanted_animation:
			_animation_player.play(wanted_animation, 0.20)
		_animation_player.speed_scale = lerpf(0.86, 1.24, speed_ratio)
	elif is_instance_valid(_tail_left):
		var stroke := sin(time * lerpf(5.5, 10.5, clampf(speed / 8.0, 0.0, 1.0)))
		_tail_left.rotation.y = -0.34 + stroke * 0.52
		_tail_right.rotation.y = 0.34 + stroke * 0.52


func _build_shark() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "SharkVisual"
	add_child(_visual_root)

	var imported_model := SHARK_SCENE.instantiate() as Node3D
	imported_model.name = "QuaterniusShark"
	imported_model.scale = Vector3.ONE * 0.84
	imported_model.rotation_degrees.y = 180.0
	_visual_root.add_child(imported_model)
	_animation_player = imported_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_make_model_readable(imported_model)
	if is_instance_valid(_animation_player):
		for animation_name in [SWIM_NORMAL, SWIM_FAST]:
			var animation := _animation_player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
		_animation_player.play(SWIM_NORMAL)
	_build_surface_wake()


func _build_surface_wake() -> void:
	_surface_wake = Node3D.new()
	_surface_wake.name = "FinSurfaceWake"
	_surface_wake.top_level = true
	_surface_wake.visible = false
	add_child(_surface_wake)

	var wake_mesh_instance := MeshInstance3D.new()
	wake_mesh_instance.name = "VWakeRibbons"
	wake_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wake_mesh_instance.mesh = _make_surface_wake_mesh()
	_surface_wake_material = ShaderMaterial.new()
	_surface_wake_material.shader = SURFACE_WAKE_SHADER
	_surface_wake_material.render_priority = 20
	_surface_wake_material.set_shader_parameter("wake_strength", 0.0)
	wake_mesh_instance.material_override = _surface_wake_material
	_surface_wake.add_child(wake_mesh_instance)

	_wake_particles = GPUParticles3D.new()
	_wake_particles.name = "TrailingFinFoam"
	_wake_particles.amount = 72
	_wake_particles.lifetime = 1.65
	_wake_particles.randomness = 0.66
	_wake_particles.local_coords = false
	_wake_particles.position = Vector3(0.0, 0.01, 0.82)
	_wake_particles.visibility_aabb = AABB(
		Vector3(-10.0, -2.0, -10.0),
		Vector3(20.0, 4.0, 20.0)
	)

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(0.26, 0.01, 0.42)
	process_material.direction = Vector3(0.0, 0.0, 1.0)
	process_material.spread = 24.0
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = 0.28
	process_material.initial_velocity_max = 0.92
	process_material.damping_min = 0.18
	process_material.damping_max = 0.46
	process_material.scale_min = 0.34
	process_material.scale_max = 1.0
	var fade_gradient := Gradient.new()
	fade_gradient.offsets = PackedFloat32Array([0.0, 0.26, 1.0])
	fade_gradient.colors = PackedColorArray([
		Color(0.78, 0.96, 1.0, 0.0),
		Color(0.78, 0.96, 1.0, 0.36),
		Color(0.68, 0.90, 0.96, 0.0),
	])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_gradient
	process_material.color_ramp = fade_texture
	_wake_particles.process_material = process_material

	var foam_mesh := SphereMesh.new()
	foam_mesh.radius = 0.055
	foam_mesh.height = 0.014
	foam_mesh.radial_segments = 8
	foam_mesh.rings = 3
	foam_mesh.material = _foam_particle_material()
	_wake_particles.draw_pass_1 = foam_mesh
	_surface_wake.add_child(_wake_particles)


func _make_surface_wake_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var near_inner := Vector3(0.035 * side, 0.0, 0.18)
		var near_outer := Vector3(0.20 * side, 0.0, 0.22)
		var far_inner := Vector3(0.78 * side, 0.0, 3.72)
		var far_outer := Vector3(1.24 * side, 0.0, 3.54)
		for vertex_data in [
			[near_inner, Vector2(0.0, 0.0)],
			[near_outer, Vector2(1.0, 0.0)],
			[far_inner, Vector2(0.0, 1.0)],
			[near_outer, Vector2(1.0, 0.0)],
			[far_outer, Vector2(1.0, 1.0)],
			[far_inner, Vector2(0.0, 1.0)],
		]:
			surface.set_uv(vertex_data[1])
			surface.add_vertex(vertex_data[0])
	return surface.commit()


func _update_surface_wake(speed: float) -> void:
	if not is_surface_wake_ready():
		return
	var flat_velocity := Vector3(swim_velocity.x, 0.0, swim_velocity.z)
	var near_surface := global_position.y > -1.42 and flat_velocity.length() > 1.0
	_surface_wake.visible = near_surface
	_wake_particles.emitting = near_surface
	var strength := clampf((speed - 2.2) / 5.4, 0.24, 1.0) if near_surface else 0.0
	_surface_wake_material.set_shader_parameter("wake_strength", strength)
	if not near_surface:
		return
	var forward := flat_velocity.normalized()
	_surface_wake.global_position = Vector3(
		global_position.x,
		0.14,
		global_position.z
	)
	_surface_wake.global_rotation = Vector3(
		0.0,
		atan2(-forward.x, -forward.z),
		0.0
	)


func _foam_particle_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.76, 0.95, 0.99, 0.54)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 20
	return material


func _make_model_readable(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface_index in mesh_instance.get_surface_override_material_count():
			var source := mesh_instance.get_active_material(surface_index)
			if source is StandardMaterial3D:
				var material := source.duplicate() as StandardMaterial3D
				if material.albedo_color.get_luminance() > 0.08:
					material.emission_enabled = true
					material.emission = material.albedo_color.darkened(0.34)
					material.emission_texture = material.albedo_texture
					material.emission_energy_multiplier = 0.20
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in node.get_children():
		_make_model_readable(child)


func _make_fin(
	node_name: String,
	node_position: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var fin := MeshInstance3D.new()
	fin.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.90, 0.12, 0.58)
	fin.mesh = mesh
	fin.material_override = material
	fin.position = node_position
	return fin


func _make_tail(
	node_name: String,
	node_position: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var tail := MeshInstance3D.new()
	tail.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.82, 0.15, 0.92)
	tail.mesh = mesh
	tail.material_override = material
	tail.position = node_position
	return tail


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if color.get_luminance() > 0.10:
		material.emission_enabled = true
		material.emission = color.darkened(0.42)
		material.emission_energy_multiplier = 0.26
	return material
