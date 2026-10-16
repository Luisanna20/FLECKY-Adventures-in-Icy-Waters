extends RefCounted
## Rest-pose coordinates stay attached during the original skeletal animations.
## Only UVs and body shading normals are added; topology, bones and weights remain.
const SKIN := preload("res://shaders/fish_skin.gdshader")
const PALETTES := [
	[Color(0.13,0.24,0.31),Color(0.58,0.69,0.70),Color(0.83,0.85,0.78),Color(0.36,0.40,0.30)],
	[Color(0.43,0.22,0.20),Color(0.67,0.45,0.38),Color(0.84,0.76,0.65),Color(0.51,0.29,0.23)],
	[Color(0.31,0.24,0.21),Color(0.56,0.43,0.34),Color(0.79,0.73,0.61),Color(0.43,0.32,0.24)]
]
static var _meshes: Dictionary={}

static func apply(node: Node,species: int) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		var source := instance.mesh
		var key := "%s:%d" % [source.get_instance_id(),species]
		if not _meshes.has(key): _meshes[key]=_prepare_mesh(source,species)
		instance.mesh=_meshes[key]
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): apply(child,species)

static func _body_surface(label: String) -> bool:
	return not (label=="Eyes" or label.ends_with("_Fins") or label.ends_with("_Dark"))

static func _prepare_mesh(source: Mesh,species: int) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.resource_name="Natural%s" % ["Tuna","RedSnapper","CardinalFish"][species]
	var normals_by_position: Dictionary={}
	var bounds := source.get_aabb()
	var bottom := INF
	var top := -INF
	for surface in source.get_surface_count():
		var label := source.surface_get_material(surface).resource_name
		if not _body_surface(label): continue
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			var p := vertices[index]
			bottom=minf(bottom,p.z); top=maxf(top,p.z)
			var key := Vector3i((p*1000000.0).round())
			normals_by_position[key]=normals_by_position.get(key,Vector3.ZERO)+normals[index]
	for surface in source.get_surface_count():
		var label := source.surface_get_material(surface).resource_name
		var arrays := source.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv := PackedVector2Array()
		var eye_bounds := AABB(vertices[0],Vector3.ZERO)
		if label=="Eyes":
			for p in vertices: eye_bounds=eye_bounds.expand(p)
		for index in vertices.size():
			var p := vertices[index]
			if label=="Eyes":
				uv.append(Vector2((p.y-eye_bounds.position.y)/eye_bounds.size.y,(p.z-eye_bounds.position.z)/eye_bounds.size.z))
			else:
				uv.append(Vector2((p.y-bounds.position.y)/bounds.size.y,(p.z-bottom)/(top-bottom)))
			if _body_surface(label):
				normals[index]=(normals_by_position[Vector3i((p*1000000.0).round())] as Vector3).normalized()
		arrays[Mesh.ARRAY_TEX_UV]=uv
		arrays[Mesh.ARRAY_NORMAL]=normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material := ShaderMaterial.new()
		material.resource_name=label
		material.shader=SKIN
		for i in 4:
			material.set_shader_parameter(["back_color","flank_color","belly_color","fin_color"][i],PALETTES[species][i])
		material.set_shader_parameter("surface_kind",1 if label=="Eyes" else (2 if not _body_surface(label) else 0))
		material.set_shader_parameter("patch_lightness",1.06 if label.ends_with("_Light") else 1.0)
		material.set_shader_parameter("scale_count",82.0 if species==0 else 66.0)
		material.set_shader_parameter("stripe_strength",0.14 if species==2 else 0.0)
		result.surface_set_material(surface,material)
	return result
