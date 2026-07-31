class_name IceExitZone
extends Area3D

var floe_radius := 4.0
var floe_height := 1.0
var water_level := 0.0
var _exit_direction := Vector3.FORWARD
var _marker: MeshInstance3D


func configure(
	radius: float,
	height: float,
	direction_angle: float,
	surface_height: float
) -> void:
	floe_radius = radius
	floe_height = height
	water_level = surface_height
	_exit_direction = Vector3(cos(direction_angle), 0.0, sin(direction_angle)).normalized()
	name = "ClimbZone"
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	add_to_group("ice_exit_zone")

	position = _exit_direction * (floe_radius + 0.85)
	position.y = water_level - (get_parent() as Node3D).global_position.y - 0.48

	var collision := CollisionShape3D.new()
	collision.name = "ApproachVolume"
	var shape := SphereShape3D.new()
	shape.radius = 2.75
	collision.shape = shape
	add_child(collision)

	_build_marker()


func get_landing_position() -> Vector3:
	var floe := get_parent() as Node3D
	var landing := floe.to_global(
		_exit_direction * floe_radius * 0.68
		+ Vector3.UP * (floe_height * 0.5 + 0.54)
	)
	return landing


func get_water_position() -> Vector3:
	var floe := get_parent() as Node3D
	var water_position := floe.to_global(_exit_direction * (floe_radius + 1.75))
	water_position.y = water_level - 0.48
	return water_position


func _build_marker() -> void:
	var floe := get_parent() as Node3D
	_marker = MeshInstance3D.new()
	_marker.name = "%sMarker" % name
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.72
	marker_mesh.bottom_radius = 0.82
	marker_mesh.height = 0.055
	marker_mesh.radial_segments = 18
	_marker.mesh = marker_mesh

	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.52, 0.97, 1.0, 0.78)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.20, 0.80, 0.92)
	marker_material.emission_energy_multiplier = 0.68
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.roughness = 0.26
	_marker.material_override = marker_material
	_marker.position = (
		_exit_direction * floe_radius * 0.68
		+ Vector3.UP * (floe_height * 0.5 + 0.075)
	)
	_marker.visible = false
	floe.add_child(_marker)


func set_marker_active(active: bool) -> void:
	if is_instance_valid(_marker):
		_marker.visible = active


func is_marker_visible() -> bool:
	return is_instance_valid(_marker) and _marker.visible


func is_player_inside(player: FlakiController) -> bool:
	return overlaps_body(player)
