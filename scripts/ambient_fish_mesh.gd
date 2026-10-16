extends RefCounted
## One low-cost, closed body with solid fins and small eyes, in one mesh surface.
const SKIN := preload("res://shaders/ambient_fish.gdshader")

static func build(tint: Color,variant: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width: float=[0.085,0.105,0.095][variant]
	var height: float=[0.12,0.145,0.13][variant]
	var rings := 16
	var sides := 10
	for row in rings:
		for col in sides:
			var corners := [Vector2(float(row)/rings,TAU*col/sides),
				Vector2(float(row+1)/rings,TAU*col/sides),
				Vector2(float(row)/rings,TAU*(col+1)/sides),
				Vector2(float(row+1)/rings,TAU*(col+1)/sides)]
			for index in [0,1,2,2,1,3]:
				var t: float=corners[index].x
				var angle: float=corners[index].y
				var radius := _radius(t)
				var lo := maxf(t-0.002,0.0)
				var hi := minf(t+0.002,1.0)
				var slope := (_radius(hi)-_radius(lo))/(hi-lo)
				tool.set_normal(Vector3(cos(angle)/width,sin(angle)/height,-slope/0.76).normalized())
				tool.set_uv(Vector2(t,float(col)/sides))
				tool.set_uv2(Vector2.ZERO)
				tool.add_vertex(Vector3(cos(angle)*width*radius,sin(angle)*height*radius,-0.46+t*0.76))
	# A narrow peduncle and two solid tail lobes give a forked silhouette.
	_fin(tool,Vector3(0,0.025,0.23),Vector3(0,0.205,0.53),Vector3(0,0,0.42),0.008)
	_fin(tool,Vector3(0,-0.025,0.23),Vector3(0,0,0.42),Vector3(0,-0.205,0.53),0.008)
	_fin(tool,Vector3(0,height*0.80,-0.16),Vector3(0,height*1.45,0.02),Vector3(0,height*0.55,0.14),0.005)
	_fin(tool,Vector3(0,-height*0.66,0.04),Vector3(0,-height*1.12,0.17),Vector3(0,-height*0.30,0.22),0.005)
	for side in [-1.0,1.0]:
		var sphere := SphereMesh.new()
		sphere.radius=1.0; sphere.height=2.0
		sphere.radial_segments=8; sphere.rings=4
		var arrays := sphere.get_mesh_arrays()
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var eye_z := -0.31
		var eye_y := 0.026
		var r := _radius((eye_z+0.46)/0.76)
		var eye_x := width*r*sqrt(1.0-pow(eye_y/(height*r),2.0))
		for index in indices:
			tool.set_normal((normals[index]/Vector3(0.010,0.017,0.017)).normalized())
			tool.set_uv(Vector2.ZERO)
			tool.set_uv2(Vector2(2,0))
			tool.add_vertex(Vector3(side*eye_x,eye_y,eye_z)+vertices[index]*Vector3(0.010,0.017,0.017))
	tool.index()
	var mesh := tool.commit()
	var material := ShaderMaterial.new()
	material.shader=SKIN
	material.set_shader_parameter("flank_color",Color(0.56,0.65,0.65).lerp(tint,0.20))
	mesh.surface_set_material(0,material)
	return mesh

static func _radius(t: float) -> float:
	return pow(maxf(sin(t*PI),0.0),0.80)*(1.0-t*0.40)

static func _fin(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,thickness: float) -> void:
	var offset := Vector3.RIGHT*thickness
	var p := [a+offset,b+offset,c+offset,a-offset,b-offset,c-offset]
	# Orient every face outward by its position relative to the prism centre.
	var center := (a+b+c)/3.0
	for face in [[0,1,2],[3,5,4],[0,3,1],[1,3,4],[1,4,2],[2,4,5],[2,5,0],[0,5,3]]:
		var x: Vector3=p[face[0]]
		var y: Vector3=p[face[1]]
		var z: Vector3=p[face[2]]
		var normal := (z-x).cross(y-x).normalized()
		if normal.dot((x+y+z)/3.0-center)<0:
			var swap := y; y=z; z=swap
			normal=-normal
		for vertex in [x,y,z]:
			tool.set_normal(normal)
			tool.set_uv(Vector2.ZERO)
			tool.set_uv2(Vector2(1,0))
			tool.add_vertex(vertex)
