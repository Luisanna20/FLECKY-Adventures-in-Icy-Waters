extends RefCounted
var radius: float
var height: float
var style: int
var phase: float

func _init(r: float,h: float,index: int) -> void:
	radius=r; height=h; style=index; phase=float(index)*1.73+0.45

func outline(angle: float) -> Vector2:
	var shape := 1.0+sin(angle*3.0+phase)*0.09+cos(angle*5.0-phase)*0.045
	shape += sin(angle*7.0+phase*2.0)*0.025
	var aspect := 1.0+sin(phase)*0.10
	return Vector2(cos(angle)*aspect,sin(angle)/aspect)*radius*shape

func top_height(x: float,z: float) -> float:
	var r := Vector2(x,z).length()/radius
	var snow := (sin(x*0.50+phase)*cos(z*0.43-phase)+sin(z*0.9+x*0.31)*0.3)*0.065
	var ridge := pow(maxf(sin(x*0.38+z*0.18+phase),0.0),3.0)*0.34*(1.0-smoothstep(0.65,1.1,r))
	var edge := (sin(atan2(z,x)*3.0+phase)*0.15+sin(atan2(z,x)*7.0-phase)*0.06)*smoothstep(0.55,1.0,r)
	return height*0.5+0.055+snow+ridge+edge

func build_mesh(snow: Material,ice: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 72
	var rings := 12
	for row in rings+1:
		var t := float(row)/rings
		for col in segments:
			var p := outline(TAU*float(col)/segments)*t
			top.set_uv(p*0.16)
			top.add_vertex(Vector3(p.x,top_height(p.x,p.y),p.y))
	for row in rings:
		for col in segments:
			var a := row*segments+col
			var b := row*segments+(col+1)%segments
			quad(top,a,b,b+segments,a+segments,true)
	top.generate_normals()
	top.generate_tangents()
	top.commit(mesh)
	mesh.surface_set_material(0,snow)
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The lower rings taper into a shallow, uneven submerged keel.
	var scales := [1.0,1.025,0.96,0.78,0.45,0.0]
	for row in scales.size():
		for col in segments:
			var angle := TAU*float(col)/segments
			var erosion := 1.0 if row==0 else 1.0+sin(angle*6.0+phase+float(row)*0.65)*0.022
			var p: Vector2 = outline(angle)*scales[row]*erosion
			var y := top_height(p.x,p.y)
			if row==1: y=-0.10+sin(angle*5.0+phase)*0.08
			elif row==2: y=-0.52+sin(angle*4.0+phase)*0.13
			elif row==3: y=-1.02+sin(angle*3.0-phase)*0.18
			elif row==4: y=-1.48+sin(angle*4.0+phase)*0.12
			elif row==5: y=-1.42+sin(phase)*0.12
			sides.set_uv(Vector2(float(col)/segments,float(row)*0.25))
			sides.add_vertex(Vector3(p.x,y,p.y))
	for row in scales.size()-1:
		for col in segments:
			var a:=row*segments+col
			var b:=row*segments+(col+1)%segments
			quad(sides,a,b,b+segments,a+segments,true)
	sides.generate_normals()
	sides.generate_tangents()
	sides.commit(mesh)
	mesh.surface_set_material(1,ice)
	return mesh

static func quad(surface: SurfaceTool,a: int,b: int,c: int,d: int,reverse: bool) -> void:
	for i in ([a,c,b,a,d,c] if reverse else [a,b,c,a,c,d]): surface.add_index(i)
