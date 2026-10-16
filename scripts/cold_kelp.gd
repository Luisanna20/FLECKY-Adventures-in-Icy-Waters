extends RefCounted
## Original ribbon geometry: thin cupped blades, curved stems and tapered tips.

static func build_mesh(kind: int) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 72531+kind*3187
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 26
	var columns := 6
	var blades := 5 if kind == 0 else 7
	for blade in blades:
		var angle := random.randf_range(0,TAU)
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-sin(angle),0,cos(angle))
		var height := random.randf_range(1.30,2.30) if kind == 0 else random.randf_range(0.35,0.85)
		var width := random.randf_range(0.11,0.19) if kind == 0 else random.randf_range(0.07,0.13)
		var lean := random.randf_range(0.25,0.85)
		var phase := random.randf_range(0,TAU)
		var base := direction*random.randf_range(0.02,0.13)
		var start := blade*(rows+1)*(columns+1)
		for row in rows+1:
			var t := float(row)/rows
			var center := base+Vector3.UP*height*(t-0.12*pow(t,6.0))+direction*height*lean*t*t
			center += side*sin(t*4.2+phase)*t*0.10
			var span := maxf(0.006,pow(sin(t*PI),0.72)*width*smoothstep(0.0,0.16,t))
			for col in columns+1:
				var u := float(col)/columns
				var across := (u-0.5)*2.0
				var position := center+side*span*across
				position += direction*(across*across*0.045+sin(t*28.0+phase)*absf(across)*0.025)*sin(t*PI)
				tool.set_uv(Vector2(u,t))
				tool.add_vertex(position)
		for row in rows:
			for col in columns:
				var a := start+row*(columns+1)+col
				for index in [a,a+1,a+columns+2,a,a+columns+2,a+columns+1]:
					tool.add_index(index)
	tool.generate_normals()
	return tool.commit()
