class_name AmbientFishSchool
extends Node3D

const DEFAULT_FISH_COUNT := 13

var _multimesh_instance: MultiMeshInstance3D
var _fish_offsets: Array[Vector3] = []
var _fish_scales: Array[float] = []
var _fish_phases: Array[float] = []
var _fish_count := 0
var _school_phase := 0.0
var _school_speed := 0.15
var _orbit_radius := Vector2(5.2, 3.8)
var _elapsed := 0.0
var _current_center := Vector3.ZERO


func configure(
	home_position: Vector3,
	random_seed: int,
	fish_count: int = DEFAULT_FISH_COUNT,
	tint: Color = Color(0.34, 0.78, 0.88)
) -> void:
	position = home_position
	_fish_count = fish_count
	var random := RandomNumberGenerator.new()
	random.seed = random_seed
	_school_phase = random.randf_range(0.0, TAU)
	_school_speed = random.randf_range(0.115, 0.175)
	_orbit_radius = Vector2(
		random.randf_range(4.2, 6.2),
		random.randf_range(2.8, 4.6)
	)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _make_fish_mesh(tint)
	multimesh.instance_count = fish_count

	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "DecorativeFishSilhouettes"
	_multimesh_instance.multimesh = multimesh
	_multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multimesh_instance)

	for index in fish_count:
		_fish_offsets.append(
			Vector3(
				random.randf_range(-2.9, 2.9),
				random.randf_range(-1.15, 1.15),
				random.randf_range(-2.1, 2.1)
			)
		)
		_fish_scales.append(random.randf_range(0.62, 1.05))
		_fish_phases.append(random.randf_range(0.0, TAU))
		var color_variation := random.randf_range(0.82, 1.12)
		multimesh.set_instance_color(
			index,
			Color(
				clampf(tint.r * color_variation, 0.0, 1.0),
				clampf(tint.g * color_variation, 0.0, 1.0),
				clampf(tint.b * color_variation, 0.0, 1.0),
				1.0
			)
		)
	_update_school(0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	_update_school(delta)


func get_fish_count() -> int:
	return _fish_count


func get_school_center_global() -> Vector3:
	return global_position + _current_center


func _update_school(_delta: float) -> void:
	if not is_instance_valid(_multimesh_instance):
		return
	var multimesh := _multimesh_instance.multimesh
	var angle := _school_phase + _elapsed * _school_speed
	_current_center = Vector3(
		cos(angle) * _orbit_radius.x,
		sin(angle * 1.7) * 0.72,
		sin(angle) * _orbit_radius.y
	)
	var school_direction := Vector3(
		-sin(angle) * _orbit_radius.x,
		cos(angle * 1.7) * 0.28,
		cos(angle) * _orbit_radius.y
	).normalized()
	var offset_rotation := Basis(Vector3.UP, angle * 0.23)

	for index in _fish_count:
		var phase := _fish_phases[index]
		var offset := offset_rotation * _fish_offsets[index]
		var individual_wobble := Vector3(
			sin(_elapsed * 1.15 + phase) * 0.18,
			sin(_elapsed * 1.55 + phase) * 0.16,
			cos(_elapsed * 1.08 + phase) * 0.15
		)
		var heading := (
			school_direction
			+ Vector3(
				sin(_elapsed * 0.72 + phase) * 0.08,
				cos(_elapsed * 0.93 + phase) * 0.035,
				cos(_elapsed * 0.61 + phase) * 0.08
			)
		).normalized()
		var fish_basis := Basis.looking_at(heading, Vector3.UP)
		fish_basis = fish_basis.scaled(Vector3.ONE * _fish_scales[index])
		multimesh.set_instance_transform(
			index,
			Transform3D(fish_basis, _current_center + offset + individual_wobble)
		)


func _make_fish_mesh(tint: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nose := Vector3(0.0, 0.0, -0.46)
	var rear := Vector3(0.0, 0.0, 0.25)
	var left := Vector3(-0.135, 0.0, -0.02)
	var right := Vector3(0.135, 0.0, -0.02)
	var top := Vector3(0.0, 0.14, -0.03)
	var bottom := Vector3(0.0, -0.14, -0.03)
	var tail_top := Vector3(0.0, 0.23, 0.51)
	var tail_bottom := Vector3(0.0, -0.23, 0.51)
	var triangles := [
		[nose, left, top],
		[nose, top, right],
		[nose, right, bottom],
		[nose, bottom, left],
		[rear, top, left],
		[rear, right, top],
		[rear, bottom, right],
		[rear, left, bottom],
		[rear, tail_top, tail_bottom],
	]
	for triangle in triangles:
		for vertex in triangle:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := surface.commit()

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.72
	material.emission_enabled = true
	material.emission = tint * 0.24
	material.emission_energy_multiplier = 0.42
	mesh.surface_set_material(0, material)
	return mesh
