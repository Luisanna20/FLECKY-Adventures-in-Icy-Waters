extends Node3D
## Original, continuous arm meshes; suckers share each arm's deformation shader.
const SKIN := preload("res://shaders/octopus_skin.gdshader")

func _init() -> void:
	name = "OriginalColdWaterOctopus"
	var skin := _material(Color(0.60,0.36,0.40))
	_ellipsoid("Mantle",Vector3(0,0.39,-0.13),Vector3(0.59,0.83,0.64),skin)
	_ellipsoid("Head",Vector3(0,-0.12,0.22),Vector3(0.51,0.34,0.51),skin)
	for side in [-1.0,1.0]:
		var eye_position := Vector3(side*0.43,0.02,0.41)
		_ellipsoid("EyeSocket",eye_position,Vector3(0.15,0.14,0.16),skin)
		var eye := StandardMaterial3D.new()
		eye.albedo_color=Color(0.62,0.46,0.22); eye.roughness=0.27
		_ellipsoid("AmberEye",eye_position+Vector3(side*0.05,0.015,0.12),Vector3(0.09,0.09,0.065),eye)
		var pupil := StandardMaterial3D.new()
		pupil.albedo_color=Color(0.018,0.012,0.02); pupil.roughness=0.19
		_ellipsoid("HorizontalPupil",eye_position+Vector3(side*0.05,0.015,0.178),Vector3(0.065,0.018,0.016),pupil)
	for index in 8:
		_build_arm(index)

func _material(color: Color,phase: float=0.0,arm: bool=false,sucker: bool=false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader=SKIN
	material.set_shader_parameter("skin_color",color)
	material.set_shader_parameter("arm_phase",phase)
	material.set_shader_parameter("animate_arm",arm)
	material.set_shader_parameter("sucker",sucker)
	return material

func _ellipsoid(label: String,center: Vector3,size: Vector3,material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name=label; instance.position=center; instance.scale=size
	var sphere := SphereMesh.new()
	sphere.radius=1.0; sphere.height=2.0
	sphere.radial_segments=40; sphere.rings=24
	instance.mesh=sphere; instance.material_override=material
	add_child(instance)

func _center(t: float,index: int) -> Vector3:
	var length := 1.40+sin(float(index)*1.83)*0.20
	return Vector3(sin(t*PI)*0.15+pow(t,3)*sin(float(index)*2.1)*0.37,
		-sin(t*PI*0.84)*0.44+pow(t,5)*(0.12+sin(float(index)*2.2)*0.30),
		0.18+t*length-smoothstep(0.76,1.0,t)*0.15)

func _build_arm(index: int) -> void:
	var arm := MeshInstance3D.new()
	arm.name="Arm%d" % (index+1)
	arm.position.y=-0.25
	arm.rotation.y=TAU*float(index)/8.0+0.18
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 36
	var sides := 12
	for row in rings+1:
		var t := float(row)/rings
		var center := _center(t,index)
		var tangent := (_center(minf(t+0.005,1.0),index)-_center(maxf(t-0.005,0.0),index)).normalized()
		var across := Vector3.UP.cross(tangent).normalized()
		var up := tangent.cross(across).normalized()
		var radius := 0.235*pow(1.0-t,1.15)+0.008
		for col in sides:
			var angle := TAU*float(col)/sides
			var normal := across*cos(angle)+up*sin(angle)
			surface.set_normal(normal)
			surface.set_uv(Vector2(float(col)/sides,t))
			surface.add_vertex(center+normal*radius)
	for row in rings:
		for col in sides:
			var a := row*sides+col
			var b := row*sides+(col+1)%sides
			for vertex in [a,a+sides,b,b,a+sides,b+sides]: surface.add_index(vertex)
	surface.commit(mesh)
	mesh.surface_set_material(0,_material(Color(0.60,0.36,0.40),float(index)*1.7,true))
	var cups := SurfaceTool.new()
	cups.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two staggered rows of small fleshy cups, tapering with the arms.
	for row in 12:
		var t := 0.12+float(row)*0.064
		var radius := 0.235*pow(1.0-t,1.15)+0.008
		for side in [-1.0,1.0]:
			var center := _center(t,index)+Vector3(side*radius*0.46,-radius*0.88,0)
			var cup := TorusMesh.new()
			cup.inner_radius=radius*0.13; cup.outer_radius=radius*0.38
			cup.rings=12; cup.ring_segments=6
			cups.append_from(cup,0,Transform3D(Basis.IDENTITY,center))
	cups.commit(mesh)
	mesh.surface_set_material(1,_material(Color(0.64,0.43,0.43),float(index)*1.7,true,true))
	arm.mesh=mesh
	add_child(arm)
