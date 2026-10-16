class_name BayFish
extends CharacterBody3D

const TUNA_SCENE := preload("res://assets/models/quaternius/tuna.glb")
const RED_SNAPPER_SCENE := preload("res://assets/models/quaternius/red_snapper.glb")
const CARDINAL_FISH_SCENE := preload("res://assets/models/quaternius/cardinal_fish.glb")
const APPEARANCE := preload("res://scripts/fish_appearance.gd")
const FISH_SCENES := [TUNA_SCENE, RED_SNAPPER_SCENE, CARDINAL_FISH_SCENE]
const FISH_MODEL_NAMES := ["Tuna", "RedSnapper", "CardinalFish"]
const SWIM_NORMAL := &"Fish_Armature|Swimming_Normal"
const SWIM_FAST := &"Fish_Armature|Swimming_Fast"
const OUT_OF_WATER := &"Fish_Armature|Out_Of_Water"
const MAX_SWIM_HEIGHT := -0.92
const MIN_SWIM_DEPTH := -12.35
const COLLISION_RADIUS := 0.42
const OBSTACLE_LOOKAHEAD := 2.8

var school_center := Vector3.ZERO
var roam_radius := 11.0
var player: FlakiController
var cruise_speed := 1.7
var flee_speed := 5.7
var flee_distance := 7.0
var species_index := 0

var _swim_velocity := Vector3.ZERO
var _wander_direction := Vector3.FORWARD
var _wander_timer := 0.0
var _random := RandomNumberGenerator.new()
var _visual_root: Node3D
var _tail_left: MeshInstance3D
var _tail_right: MeshInstance3D
var _animation_player: AnimationPlayer
var _caught := false


func configure(
	center: Vector3,
	target_player: FlakiController,
	seed_value: int,
	tint: Color,
	selected_species: int = 0
) -> void:
	school_center = center
	player = target_player
	_random.seed = seed_value
	species_index = posmod(selected_species, FISH_SCENES.size())
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin = 0.06
	_build_collision()
	_build_fish(tint, species_index)
	_choose_wander_direction()
	_swim_velocity = _wander_direction * cruise_speed
	add_to_group("catchable_fish")


func _physics_process(delta: float) -> void:
	if _caught or not is_instance_valid(player):
		return

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_choose_wander_direction()

	var desired_velocity := _wander_direction * cruise_speed
	var from_player := global_position - player.global_position
	var player_distance := from_player.length()
	if player_distance < flee_distance:
		var panic := 1.0 - player_distance / flee_distance
		var escape_direction := from_player.normalized()
		escape_direction.y += _random.randf_range(-0.22, 0.22)
		desired_velocity = escape_direction.normalized() * lerpf(
			cruise_speed * 1.8,
			flee_speed,
			panic
		)

	var from_center := global_position - school_center
	if from_center.length() > roam_radius:
		desired_velocity += -from_center.normalized() * cruise_speed * 2.2

	if global_position.y > -1.15:
		desired_velocity.y -= 1.8
	elif global_position.y < -11.8:
		desired_velocity.y += 1.8
	desired_velocity = _avoid_environment(desired_velocity)

	var turn_response := 1.0 - exp(-4.2 * delta)
	_swim_velocity = _swim_velocity.lerp(desired_velocity, turn_response)
	velocity = _swim_velocity
	move_and_slide()
	_swim_velocity = velocity
	_react_to_collisions()
	_clamp_to_water_volume()

	if _swim_velocity.length_squared() > 0.01:
		var look_direction := _swim_velocity.normalized()
		var look_up := (
			Vector3.FORWARD
			if absf(look_direction.dot(Vector3.UP)) > 0.96
			else Vector3.UP
		)
		look_at(global_position + look_direction, look_up)
	_animate_tail()


func has_environment_collision() -> bool:
	return (
		collision_layer == 0
		and collision_mask == 1
		and is_instance_valid(find_child("FishCollision", false, false))
	)


func is_inside_water_volume() -> bool:
	return (
		global_position.y <= MAX_SWIM_HEIGHT + 0.05
		and global_position.y >= MIN_SWIM_DEPTH - 0.05
	)


func debug_force_swim(direction: Vector3) -> void:
	if direction.length_squared() < 0.01:
		return
	_wander_direction = direction.normalized()
	_swim_velocity = _wander_direction * cruise_speed
	_wander_timer = 10.0


func catch() -> void:
	if _caught:
		return
	_caught = true
	remove_from_group("catchable_fish")
	set_physics_process(false)
	if is_instance_valid(_animation_player):
		_animation_player.play(OUT_OF_WATER, 0.08)
	_make_catch_burst()

	var catch_tween := create_tween()
	catch_tween.set_parallel(true)
	catch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	catch_tween.tween_property(self, "scale", Vector3(0.04, 0.04, 0.04), 0.26)
	catch_tween.tween_property(self, "rotation:y", rotation.y + TAU, 0.26)
	catch_tween.chain().tween_interval(0.38)
	catch_tween.tween_callback(queue_free)


func _choose_wander_direction() -> void:
	_wander_timer = _random.randf_range(1.4, 3.8)
	_wander_direction = Vector3(
		_random.randf_range(-1.0, 1.0),
		_random.randf_range(-0.22, 0.22),
		_random.randf_range(-1.0, 1.0)
	).normalized()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "FishCollision"
	var shape := SphereShape3D.new()
	shape.radius = COLLISION_RADIUS
	collision.shape = shape
	add_child(collision)


func _avoid_environment(desired_velocity: Vector3) -> Vector3:
	if desired_velocity.length_squared() < 0.01 or not is_inside_tree():
		return desired_velocity
	var direction := desired_velocity.normalized()
	var query := PhysicsRayQueryParameters3D.new()
	query.from = global_position
	query.to = global_position + direction * OBSTACLE_LOOKAHEAD
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	if is_instance_valid(player):
		query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_velocity
	var normal: Vector3 = hit["normal"]
	var wanted_speed := maxf(desired_velocity.length(), cruise_speed)
	var avoidance_direction := (direction + normal * 2.4).normalized()
	_wander_timer = minf(_wander_timer, 0.42)
	return avoidance_direction * wanted_speed


func _react_to_collisions() -> void:
	if get_slide_collision_count() == 0:
		return
	var avoidance := Vector3.ZERO
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		avoidance += collision.get_normal()
	if avoidance.length_squared() > 0.01:
		avoidance = avoidance.normalized()
		_wander_direction = (_wander_direction + avoidance * 1.8).normalized()
		_swim_velocity = (
			_swim_velocity.slide(avoidance)
			+ avoidance * cruise_speed * 0.45
		)
		velocity = _swim_velocity
		_wander_timer = _random.randf_range(0.35, 0.85)


func _clamp_to_water_volume() -> void:
	if global_position.y > MAX_SWIM_HEIGHT:
		global_position.y = MAX_SWIM_HEIGHT
		_swim_velocity.y = minf(_swim_velocity.y, -0.35)
	if global_position.y < MIN_SWIM_DEPTH:
		global_position.y = MIN_SWIM_DEPTH
		_swim_velocity.y = maxf(_swim_velocity.y, 0.35)
	velocity = _swim_velocity


func _animate_tail() -> void:
	var speed_ratio := clampf(_swim_velocity.length() / flee_speed, 0.0, 1.0)
	var time := Time.get_ticks_msec() * 0.001
	_visual_root.rotation.z = sin(time * 2.3) * 0.035
	if is_instance_valid(_animation_player):
		var wanted_animation := SWIM_FAST if speed_ratio > 0.54 else SWIM_NORMAL
		if _animation_player.current_animation != wanted_animation:
			_animation_player.play(wanted_animation, 0.18)
		_animation_player.speed_scale = lerpf(0.86, 1.34, speed_ratio)
	elif is_instance_valid(_tail_left):
		var stroke := sin(time * lerpf(7.0, 16.0, speed_ratio))
		_tail_left.rotation.y = -0.30 + stroke * 0.48
		_tail_right.rotation.y = 0.30 + stroke * 0.48


func _build_fish(_tint: Color, selected_species: int) -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "FishVisual"
	add_child(_visual_root)

	var model_scene := FISH_SCENES[selected_species] as PackedScene
	var imported_model := model_scene.instantiate() as Node3D
	imported_model.name = "Quaternius%s" % FISH_MODEL_NAMES[selected_species]
	imported_model.scale = Vector3.ONE * 0.19
	imported_model.rotation_degrees.y = 180.0
	_visual_root.add_child(imported_model)
	_animation_player = imported_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	APPEARANCE.apply(imported_model, selected_species)
	if is_instance_valid(_animation_player):
		for animation_name in [SWIM_NORMAL, SWIM_FAST]:
			var animation := _animation_player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
		_animation_player.play(SWIM_NORMAL)


func _make_fin(
	node_name: String,
	node_position: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var fin := MeshInstance3D.new()
	fin.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.30, 0.045, 0.27)
	fin.mesh = mesh
	fin.material_override = material
	fin.position = node_position
	return fin


func _make_catch_burst() -> void:
	var burst := GPUParticles3D.new()
	burst.name = "CatchSparkles"
	burst.one_shot = true
	burst.amount = 18
	burst.lifetime = 0.58
	burst.explosiveness = 0.92
	burst.local_coords = false
	burst.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.18
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.gravity = Vector3(0.0, 0.18, 0.0)
	process_material.initial_velocity_min = 0.45
	process_material.initial_velocity_max = 1.45
	process_material.scale_min = 0.45
	process_material.scale_max = 1.15
	process_material.color = Color(0.72, 0.96, 1.0, 0.82)
	burst.process_material = process_material

	var sparkle := SphereMesh.new()
	sparkle.radius = 0.035
	sparkle.height = 0.07
	sparkle.radial_segments = 6
	sparkle.rings = 3
	sparkle.material = _material(Color(0.72, 0.96, 1.0, 0.86), 0.22)
	burst.draw_pass_1 = sparkle
	add_child(burst)
	burst.emitting = true


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if color.get_luminance() > 0.12:
		material.emission_enabled = true
		material.emission = color.darkened(0.18)
		material.emission_energy_multiplier = 0.74
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
