extends RefCounted
## Original crab shell, skinned to the retained Quaternius rig and animation clips.
const SHADER := preload("res://shaders/crab_shell.gdshader")
var _tool: SurfaceTool
var _binds: Dictionary
var _bones := PackedInt32Array([0,0,0,0])
var _weights := PackedFloat32Array([1,0,0,0])
var _kind := 0.0
var _leg_phase := 0.0
var _leg_flex := 0.0

func apply(root: Node3D) -> ShaderMaterial:
	var original: MeshInstance3D=root.find_children("*","MeshInstance3D",true,false)[0]
	var skeleton: Skeleton3D=root.find_children("*","Skeleton3D",true,false)[0]
	for bind in original.skin.get_bind_count():
		var label := String(original.skin.get_bind_name(bind))
		if label.is_empty(): label=skeleton.get_bone_name(original.skin.get_bind_bone(bind))
		_binds[label]=bind
	_tool=SurfaceTool.new()
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_skin("Head","Body",0.88)
	_ellipsoid(Vector3(0,0.03,0.55),Vector3(0.77,0.55,0.23),36,18)
	# Lower apron, slightly exposed beneath the carapace.
	_kind=1.0
	_skin("Head","Body",0.88)
	_ellipsoid(Vector3(0,0.02,0.41),Vector3(0.62,0.43,0.13),24,12)
	_kind=0.0
	# Shallow scallops along the lateral rim, rather than a smooth plastic oval.
	_skin("Head","Body",0.88)
	for side in [-1.0,1.0]:
		for i in 6:
			var angle := -0.85+float(i)*0.31
			var root_point := Vector3(side*cos(angle)*0.70,sin(angle)*0.51+0.03,0.54)
			_tube([root_point,root_point+Vector3(side*0.10,sin(angle)*0.04,0.005)],[0.045,0.006],8)
	# Four walking legs on each side. Root skinning follows the shell; tips follow
	# the original body motion. Small alternating steps are applied by the shader.
	for side in [-1.0,1.0]:
		for leg in 4:
			var spread := float(leg)/3.0
			var root_point := Vector3(side*0.56,lerpf(-0.26,0.38,spread),0.46)
			var knee := Vector3(side*(1.02+sin(spread*PI)*0.13),lerpf(-0.58,0.70,spread),0.40)
			var ankle := Vector3(side*(1.18+sin(spread*PI)*0.10),lerpf(-0.65,0.88,spread),0.14)
			var tip := Vector3(side*1.29,lerpf(-0.76,1.02,spread),0.0)
			_leg_phase=fmod(float(leg)*0.5+(0.5 if side<0 else 0.0),1.0)
			_tube([root_point,root_point.lerp(knee,0.55),knee,knee.lerp(ankle,0.55),ankle,ankle.lerp(tip,0.6),tip],
				[0.075,0.065,0.047,0.040,0.026,0.019,0.004],10,
				[0.88,0.70,0.50,0.30,0.16,0.06,0.0],[0.0,0.12,0.28,0.50,0.65,0.85,1.0])
	_leg_flex=0.0
	for side in [-1.0,1.0]:
		_skin("Head","Body",0.85)
		_tube([Vector3(side*0.48,-0.28,0.49),Vector3(side*0.78,-0.61,0.40),Vector3(side*0.74,-0.92,0.49)],[0.095,0.09,0.11],12)
		_ellipsoid(Vector3(side*0.73,-0.96,0.53),Vector3(0.18,0.25,0.14),24,12)
		# Fixed and moving fingers curve inward with a small dark opening between.
		_kind=1.0
		_tube([Vector3(side*0.85,-1.03,0.55),Vector3(side*0.86,-1.23,0.56),Vector3(side*0.74,-1.37,0.55)],[0.085,0.055,0.008],12)
		_skin("Head","Mouth",0.97)
		_tube([Vector3(side*0.61,-1.03,0.54),Vector3(side*0.60,-1.23,0.54),Vector3(side*0.72,-1.34,0.55)],[0.067,0.043,0.008],12)
		_kind=0.0
		_skin("Head", "Eyebrow.L" if side>0 else "Eyebrow.R",0.80)
		_tube([Vector3(side*0.24,-0.43,0.60),Vector3(side*0.29,-0.55,0.78)],[0.036,0.026],10)
		_kind=2.0
		_ellipsoid(Vector3(side*0.29,-0.55,0.79),Vector3(0.045,0.039,0.044),16,8)
		_kind=0.0
	# Small mouthparts retain the bite motion without the old teeth and cartoon grin.
	_skin("Head","Mouth",0.94)
	for side in [-1.0,1.0]:
		_ellipsoid(Vector3(side*0.075,-0.45,0.40),Vector3(0.07,0.09,0.055),12,8)
	_tool.index()
	var mesh := _tool.commit()
	mesh.resource_name="NaturalCrabShell"
	var material := ShaderMaterial.new()
	material.shader=SHADER
	mesh.surface_set_material(0,material)
	original.mesh=mesh
	original.name="NaturalCrab"
	original.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	original.custom_aabb=AABB(Vector3(-0.022,-0.024,-0.020),Vector3(0.044,0.048,0.050))
	return material

func _skin(a: String,b: String,weight: float) -> void:
	_bones=PackedInt32Array([_binds[a],_binds[b],0,0])
	_weights=PackedFloat32Array([weight,1.0-weight,0,0])

func _vertex(p: Vector3,n: Vector3) -> void:
	_tool.set_normal(n)
	_tool.set_uv(Vector2(p.x,p.y))
	_tool.set_uv2(Vector2(p.z,_kind))
	_tool.set_color(Color(_leg_flex,_leg_phase,0,1))
	_tool.set_bones(_bones)
	_tool.set_weights(_weights)
	# The retained mesh transform uses centimetre-scale coordinates, Z up.
	# Its root follows the existing terrain height +0.72 m convention.
	_tool.add_vertex((p-Vector3(0,0,0.95))*0.01)

func _ellipsoid(center: Vector3,size: Vector3,segments: int,rings: int) -> void:
	var sphere := SphereMesh.new()
	sphere.radius=1.0; sphere.height=2.0
	sphere.radial_segments=segments; sphere.rings=rings
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for index in arrays[Mesh.ARRAY_INDEX]:
		_vertex(center+vertices[index]*size,(normals[index]/size).normalized())

func _tube(points: Array,radii: Array,sides: int,head_weights: Array=[],flex: Array=[]) -> void:
	var rings: Array[Array]=[]
	for row in points.size():
		var tangent: Vector3=(points[mini(row+1,points.size()-1)]-points[maxi(row-1,0)]).normalized()
		var across := tangent.cross(Vector3.UP).normalized()
		if across.length_squared()<0.01: across=tangent.cross(Vector3.RIGHT).normalized()
		var up := across.cross(tangent).normalized()
		var ring: Array=[]
		for col in sides:
			var a := TAU*float(col)/sides
			var n := across*cos(a)+up*sin(a)
			ring.append([points[row]+n*radii[row],n])
		rings.append(ring)
	for row in points.size()-1:
		for col in sides:
			var next := (col+1)%sides
			for pair in [[row,col],[row,next],[row+1,col],[row,next],[row+1,next],[row+1,col]]:
				var v: Array=rings[pair[0]][pair[1]]
				if not head_weights.is_empty():
					_skin("Head","Body",head_weights[pair[0]])
					_leg_flex=flex[pair[0]]
				_vertex(v[0],v[1])
