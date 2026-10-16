extends MeshInstance3D
## A short world-space scattering integration with a static sunlight blocker map.
## The map includes cave roofs and floes, and is rebuilt once per new bay.
const SHAFT_SHADER := preload("res://shaders/underwater_sunlight.gdshader")
const MAP_SIZE := 128
const MAP_SPAN := 200.0
var _material: ShaderMaterial
var _amount := 0.0

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size=Vector2(2,2)
	mesh=quad
	extra_cull_margin=16384.0
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material=ShaderMaterial.new()
	_material.shader=SHAFT_SHADER
	_material.render_priority=20
	material_override=_material
	visible=false
	_bake_blockers.call_deferred()

func _bake_blockers() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var started := Time.get_ticks_msec()
	var sun := get_tree().current_scene.get_node("ColdSun") as DirectionalLight3D
	var direction := sun.global_basis.z.normalized()
	_material.set_shader_parameter("sun_direction",direction)
	var image := Image.create(MAP_SIZE,MAP_SIZE,false,Image.FORMAT_RF)
	var excluded: Array[RID]=[]
	for body in get_tree().current_scene.find_children("*","PhysicsBody3D",true,false):
		if not body is StaticBody3D: excluded.append(body.get_rid())
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask=1
	query.exclude=excluded
	var space := get_world_3d().direct_space_state
	for row in MAP_SIZE:
		for col in MAP_SIZE:
			var surface := Vector3((float(col)+0.5)/MAP_SIZE*MAP_SPAN-MAP_SPAN*0.5,0,
				(float(row)+0.5)/MAP_SIZE*MAP_SPAN-MAP_SPAN*0.5)
			query.from=surface+direction*(28.0/direction.y)
			query.to=surface-direction*(22.0/direction.y)
			var hit := space.intersect_ray(query)
			var height: float=hit.position.y if not hit.is_empty() else -22.0
			image.set_pixel(col,row,Color((height+22.0)/50.0,0,0))
	_material.set_shader_parameter("blocker_map",ImageTexture.create_from_image(image))
	_material.set_shader_parameter("blockers_ready",true)
	print("UNDERWATER_SUNLIGHT blockers=",MAP_SIZE*MAP_SIZE," bake_ms=",Time.get_ticks_msec()-started)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return
	_amount=move_toward(_amount,1.0 if camera.global_position.y < -0.15 else 0.0,delta*1.8)
	visible=_amount>0.001
	_material.set_shader_parameter("underwater_amount",_amount)
