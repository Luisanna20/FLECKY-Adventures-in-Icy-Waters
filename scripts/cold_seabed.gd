extends RefCounted
## Deterministic cold-coast terrain. Geometry, planting and ground-following
## creatures share one height function. Large boulders have matching collisions.

const HALF_SIZE := 70.0
const GRID := 140
const SHELVES := [Vector4(-25,-15,16.0,5.3), Vector4(32,10,17.5,4.4), Vector4(-29,27,15.5,3.8)]
const ROCK_PATCHES := [Vector2(-17,-15),Vector2(-33,-21),Vector2(-23,19),Vector2(-35,31),Vector2(23,8),Vector2(36,0),Vector2(12,22),Vector2(4,-29),Vector2(-7,-4),Vector2(25,-29)]
const CRAB_ROUTES := [
	[Vector2(-44,-38),Vector2(-21,-49),Vector2(7,-48),Vector2(30,-38),Vector2(45,-19),Vector2(50,4)],
	[Vector2(-49,8),Vector2(-44,27),Vector2(-28,44),Vector2(-4,50),Vector2(20,46),Vector2(10,56),Vector2(-18,53)]
]
var terrain_noise: FastNoiseLite
var rock_meshes: Array[ArrayMesh] = []
var rock_material: Material
var stats := {"boulders":0,"pebbles":0,"terrain_triangles":0}

func _init() -> void:
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = 613742
	terrain_noise.frequency = 0.055
	terrain_noise.fractal_octaves = 3

func height_at(x: float, z: float) -> float:
	var p := Vector2(x,z)
	var cave_clearance := smoothstep(12.0,22.0,p.distance_to(Vector2(45.5,27.5)))
	var uneven := terrain_noise.get_noise_2d(x,z) * 0.72
	uneven += sin(x*0.15+z*0.10)*0.22 + sin(z*0.27-x*0.11)*0.12
	var rise := smoothstep(51.0,68.0,p.length()) * 4.7
	for shelf in SHELVES:
		var delta := p-Vector2(shelf.x,shelf.y)
		var angle := atan2(delta.y,delta.x)
		var radius: float = shelf.z * (1.0 + sin(angle*3.0+0.8)*0.12 + cos(angle*5.0)*0.06)
		var ramp := 1.0-smoothstep(0.20,1.0,delta.length()/radius)
		rise = maxf(rise,ramp*shelf.w)
	return -14.0 + (uneven+rise)*cave_clearance

func is_reserved(p: Vector2) -> bool:
	return p.distance_to(Vector2(45.5,27.5)) < 14.0 or p.length() > 64.0

func build(parent: Node3D, ground: Material, stone: Material) -> void:
	rock_material = stone
	_build_ground(parent,ground)
	for variant in 10:
		rock_meshes.append(_rock_mesh(variant))
	var root := Node3D.new()
	root.name = "CoastalRockBeds"
	parent.add_child(root)
	var random := RandomNumberGenerator.new()
	random.seed = 216735
	for patch in ROCK_PATCHES:
		for index in 9:
			var a := random.randf_range(0,TAU)
			var r := sqrt(random.randf())*5.3
			var p: Vector2 = patch+Vector2(cos(a),sin(a))*r
			if is_reserved(p): continue
			var size := random.randf_range(0.65,1.9)
			var dimensions := Vector3(size*random.randf_range(1.2,1.9),size*random.randf_range(0.45,0.95),size)
			_boulder(root,p,dimensions,random)
	# Broken bedrock at the base of the ice cliffs, kept off crab routes.
	for index in 76:
		var angle := TAU*float(index)/76.0+random.randf_range(-0.025,0.025)
		var p := Vector2(cos(angle),sin(angle))*random.randf_range(59.0,64.0)
		if is_reserved(p): continue
		_boulder(root,p,Vector3(random.randf_range(1.6,3.7),random.randf_range(1.0,2.3),random.randf_range(1.8,3.3)),random)
	_build_pebbles(root,random)
	print("COLD_SEABED ",stats)

func _build_ground(parent: Node3D, material: Material) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in GRID+1:
		var z := -HALF_SIZE+float(row)
		for column in GRID+1:
			var x := -HALF_SIZE+float(column)
			vertices.append(Vector3(x,height_at(x,z),z))
			normals.append(Vector3(height_at(x-0.2,z)-height_at(x+0.2,z),0.4,height_at(x,z-0.2)-height_at(x,z+0.2)).normalized())
			uv.append(Vector2(x,z)*0.1)
	for row in GRID:
		for column in GRID:
			var a := row*(GRID+1)+column
			# Godot's clockwise front faces point upward.
			indices.append_array(PackedInt32Array([a,a+1,a+GRID+2,a,a+GRID+2,a+GRID+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var body := StaticBody3D.new()
	body.name = "Seabed"
	parent.add_child(body)
	var visual := MeshInstance3D.new()
	visual.name = "SculptedSeabed"
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "SeabedCollision"
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	stats.terrain_triangles = indices.size()/3

func _rock_mesh(variant: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 8157+variant*7919
	noise.frequency = 1.6
	noise.fractal_octaves = 3
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var p := vertices[i]
		var warp := noise.get_noise_3dv(p)*0.24
		p *= 1.0+warp
		p.x += p.y*0.15*sin(float(variant)*2.3)
		p.y = maxf(p.y,-0.68)
		p.y += sin(p.x*3.4+p.z*2.1+variant)*0.055
		vertices[i] = p
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tool := SurfaceTool.new()
	tool.create_from(mesh,0)
	tool.generate_normals()
	return tool.commit()

func _boulder(parent: Node3D, p: Vector2, dimensions: Vector3, random: RandomNumberGenerator) -> void:
	for route in CRAB_ROUTES:
		for index in route.size()-1:
			var nearest := Geometry2D.get_closest_point_to_segment(p,route[index],route[index+1])
			if p.distance_to(nearest) < maxf(dimensions.x,dimensions.z)*1.12+0.9:
				return
	var mesh: ArrayMesh = rock_meshes[random.randi_range(0,rock_meshes.size()-1)]
	var body := StaticBody3D.new()
	body.name = "CoastalBoulder_%03d" % int(stats.boulders)
	body.position = Vector3(p.x,height_at(p.x,p.y)+dimensions.y*0.38,p.y)
	body.rotation.y = random.randf_range(0,TAU)
	body.scale = dimensions
	parent.add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = rock_material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_convex_shape(true,true)
	body.add_child(collision)
	stats.boulders += 1

func _build_pebbles(parent: Node3D, random: RandomNumberGenerator) -> void:
	# Small stones are visual detail; batch per spatial cell for cheap culling.
	var batches := {}
	for index in 2300:
		var p := Vector2(random.randf_range(-63,63),random.randf_range(-63,63))
		if is_reserved(p): continue
		var near_patch := 100.0
		for patch in ROCK_PATCHES:
			near_patch = minf(near_patch,p.distance_to(patch))
		if near_patch > 9.0 and random.randf() > 0.20: continue
		var key := Vector3i(floori(p.x/16.0),floori(p.y/16.0),index%3)
		if not batches.has(key): batches[key] = []
		var size := random.randf_range(0.08,0.35)
		var scale := Vector3(size*random.randf_range(1.1,1.8),size*random.randf_range(0.35,0.72),size)
		var basis := Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(scale)
		var origin := Vector3(p.x,height_at(p.x,p.y)+scale.y*0.35,p.y)
		batches[key].append(Transform3D(basis,origin))
		stats.pebbles += 1
	for key in batches:
		var cell_origin := Vector3(key.x*16.0+8.0,0.0,key.y*16.0+8.0)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = rock_meshes[key.z]
		multimesh.instance_count = batches[key].size()
		for index in batches[key].size():
			var transform: Transform3D = batches[key][index]
			transform.origin -= cell_origin
			multimesh.set_instance_transform(index,transform)
		var node := MultiMeshInstance3D.new()
		node.name = "PebblePatch_%s" % key
		node.multimesh = multimesh
		node.position = cell_origin
		node.material_override = rock_material
		node.visibility_range_end = 44.0
		node.visibility_range_end_margin = 4.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
