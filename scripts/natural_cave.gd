extends RefCounted
## One irregular rock shell, including interior and a closed back wall.
## A triangle collision uses the exact rendered mesh; the entrance stays open.

static func build(parent: Node3D, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var around := 48
	var length_steps := 28
	var ring := around+1
	var layer_size := ring*(length_steps+1)
	var points: Array[Vector3] = []
	var noise := FastNoiseLite.new()
	noise.seed=873615
	noise.frequency=0.72
	noise.fractal_octaves=3
	for layer in 2:
		for row in length_steps+1:
			var t := float(row)/length_steps
			for column in around+1:
				var angle := PI*float(column)/around
				var floor_y := -14.5
				var cx := sin(t*3.8)*0.42
				var width := 3.7+sin(t*4.5)*0.35
				var height := 7.9+sin(t*3.1+0.7)*0.40
				var z := lerpf(-0.9,10.0,t)
				if layer==1:
					width=lerpf(8.9,5.7,t)+sin(t*5.0)*0.7
					height=lerpf(10.4,9.5,t)+sin(t*4.5)*0.65
					z=lerpf(-1.6,11.7,t)
				var p := Vector3(cx+cos(angle)*width,floor_y+sin(angle)*height,z)
				var detail := noise.get_noise_3dv(p)* (0.70 if layer==0 else 1.15)
				var ridge := sin(angle*6.0+t*7.0)*0.16+cos(angle*11.0-t*4.0)*0.09
				p.x += cos(angle)*(detail+ridge)
				p.y += sin(angle)*(detail+ridge)+cos(angle)*sin(angle)*0.55
				# Eroded lip: an irregular opening cut into one mass, not an arch of blocks.
				p.z += (1.0-smoothstep(0.0,0.32,t))*(sin(angle*3.0+0.7)*0.55+cos(angle*7.0)*0.14)
				points.append(p)
	for p in points:
		surface.add_vertex(p)
	for layer in 2:
		for row in length_steps:
			for column in around:
				var a := layer*layer_size+row*ring+column
				_quad(surface,a,a+1,a+ring+1,a+ring,layer==1)
	# Join inside and outside at the irregular mouth and at the sealed back.
	for column in around:
		_quad(surface,column,column+layer_size,column+layer_size+1,column+1,false)
		var a := length_steps*ring+column
		_quad(surface,a,a+1,a+layer_size+1,a+layer_size,false)
	# Back wall: triangulate the entire inner opening, including its lower edge.
	var back_center := points.size()
	surface.add_vertex(Vector3(0.0,-10.7,10.08))
	var start := length_steps*ring
	for column in around:
		for index in [back_center,start+column,start+column+1]: surface.add_index(index)
	for index in [back_center,start+around,start]: surface.add_index(index)
	# Close the feet below the sediment so there are no visible seams.
	for row in length_steps:
		for column in [0,around]:
			var a: int = row*ring+column
			_quad(surface,a,a+ring,a+ring+layer_size,a+layer_size,column==0)
	surface.generate_normals()
	var mesh := surface.commit()
	var body := StaticBody3D.new()
	body.name="NaturalCaveShell"
	parent.add_child(body)
	var visual := MeshInstance3D.new()
	visual.name="ContinuousRock"
	visual.mesh=mesh
	visual.material_override=material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name="RockCollision"
	collision.shape=mesh.create_trimesh_shape()
	body.add_child(collision)

static func _quad(surface: SurfaceTool,a: int,b: int,c: int,d: int,reverse: bool) -> void:
	for index in ([a,c,b,a,d,c] if reverse else [a,b,c,a,c,d]): surface.add_index(index)
