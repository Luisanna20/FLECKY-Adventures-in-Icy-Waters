extends Node3D
## Continuous, original procedural seal mesh. Dimensions match the existing
## gameplay capsule; only the presentation and its articulation live here.

const FUR_SHADER = preload("res://shaders/flaki_fur.gdshader")
const HEAD_ORIGIN := Vector3(0.0, 0.12, -0.82)
var head: Node3D
var left_flipper: Node3D
var right_flipper: Node3D
var tail_left: Node3D
var tail_right: Node3D
var left_eye: MeshInstance3D
var right_eye: MeshInstance3D
var mouth: MeshInstance3D
var whiskers: Array[MeshInstance3D] = []
var body_material: ShaderMaterial


func _init() -> void:
	name = "FlakiModel"
	body_material = _fur(Color(0.84, 0.83, 0.79), true)
	var coat := _fur(Color(0.84, 0.83, 0.79))
	var fin_coat := _fur(Color(0.70, 0.72, 0.70))
	var black := _solid(Color(0.012, 0.018, 0.020), 0.22)
	var nose_mat := _solid(Color(0.045, 0.052, 0.051), 0.48)
	var whisker_mat := _solid(Color(0.38, 0.37, 0.33), 0.72)
	# z, half-width, half-height, vertical center. The skull, neck, shoulders,
	# abdomen and tapered pelvis are a single smooth surface, with no ball seam.
	var sections: Array[Vector4] = [
		Vector4(-1.385, 0.012, 0.018, 0.045),
		Vector4(-1.34, 0.16, 0.125, 0.080),
		Vector4(-1.23, 0.265, 0.225, 0.145),
		Vector4(-1.08, 0.343, 0.300, 0.165),
		Vector4(-0.88, 0.370, 0.320, 0.145),
		Vector4(-0.66, 0.370, 0.315, 0.080),
		Vector4(-0.43, 0.444, 0.357, 0.015),
		Vector4(-0.12, 0.530, 0.399, -0.005),
		Vector4(0.24, 0.540, 0.390, -0.015),
		Vector4(0.55, 0.445, 0.335, -0.020),
		Vector4(0.81, 0.315, 0.256, -0.080),
		Vector4(1.02, 0.188, 0.157, -0.165),
		Vector4(1.19, 0.105, 0.087, -0.235),
		Vector4(1.29, 0.015, 0.020, -0.250),
	]
	var body := _loft("Body", sections, body_material, 7, 64)
	# Shader displacement can extend beyond the undeformed mesh bounds.
	body.extra_cull_margin = 0.4
	add_child(body)
	head = Node3D.new()
	head.name = "Head"
	head.position = HEAD_ORIGIN
	add_child(head)
	for side in [-1.0, 1.0]:
		# Small muzzle pads merge into the snout instead of forming two balls.
		head.add_child(_ellipsoid("MuzzlePad", Vector3(side * 0.105, -0.095, -0.478), Vector3(0.27, 0.185, 0.19), coat))
		var eye := _ellipsoid("EyeLeft" if side < 0.0 else "EyeRight", Vector3(side * 0.259, 0.147, -0.329), Vector3(0.111, 0.118, 0.062), black)
		eye.rotation.y = -side * 0.40
		head.add_child(eye)
		if side < 0.0:
			left_eye = eye
		else:
			right_eye = eye
		# Glints inherit the eye's blink, avoiding detached white dots.
		var glint := _ellipsoid("Catchlight", Vector3(-0.15, 0.20, -0.45), Vector3(0.16, 0.15, 0.08), _solid(Color(0.92, 0.96, 0.98), 0.15))
		eye.add_child(glint)
		# Pinna-free head: only a tiny recessed ear opening behind each eye.
		head.add_child(_ellipsoid("EarOpening", Vector3(side * 0.351, 0.09, -0.005), Vector3(0.012, 0.032, 0.024), nose_mat))
		for index in 7:
			var root := Vector3(side * (0.115 + 0.012 * (index % 3)), -0.070 - float(index % 3) * 0.026, -0.565 + float(index % 2) * 0.012)
			var length := 0.27 + 0.025 * float(index % 4)
			var end := Vector3(side * length, (float(index) - 3.0) * 0.028, 0.018 + float(index % 3) * 0.018)
			var whisker := _curve("Whisker_%s_%d" % [side, index], [Vector3.ZERO, end * 0.42 + Vector3(0, 0.009, -0.025), end], 0.0024, whisker_mat)
			whisker.position = root
			head.add_child(whisker)
			whiskers.append(whisker)
			var follicle := _ellipsoid("WhiskerFollicle", root + Vector3(0, 0, 0.014), Vector3(0.010, 0.008, 0.007), nose_mat)
			head.add_child(follicle)
	# Two slanted nostrils on a compact, broad nose.
	head.add_child(_ellipsoid("Nose", Vector3(0, -0.025, -0.555), Vector3(0.155, 0.094, 0.082), nose_mat))
	for side in [-1.0, 1.0]:
		var nostril := _ellipsoid("Nostril", Vector3(side * 0.037, -0.018, -0.594), Vector3(0.028, 0.042, 0.009), black)
		nostril.rotation.z = side * -0.35
		head.add_child(nostril)
	mouth = _ellipsoid("Mouth", Vector3(0, -0.153, -0.548), Vector3(0.105, 0.019, 0.022), black)
	head.add_child(mouth)
	head.add_child(_curve("Philtrum", [Vector3(0, -0.066, -0.589), Vector3(0, -0.102, -0.581), Vector3(0, -0.132, -0.565)], 0.0025, nose_mat))
	for side in [-1.0, 1.0]:
		head.add_child(_curve("Lip", [Vector3(0, -0.142, -0.557), Vector3(side * 0.066, -0.151, -0.551), Vector3(side * 0.131, -0.128, -0.536)], 0.002, nose_mat))
	left_flipper = _fore_flipper(-1.0, fin_coat)
	right_flipper = _fore_flipper(1.0, fin_coat)
	tail_left = _hind_flipper(-1.0, fin_coat)
	tail_right = _hind_flipper(1.0, fin_coat)
	for part in [left_flipper, right_flipper, tail_left, tail_right]:
		add_child(part)


func update_pose(movement: float, phase: float) -> void:
	body_material.set_shader_parameter("head_pose", head.transform)
	body_material.set_shader_parameter("swim_amount", movement)
	body_material.set_shader_parameter("swim_phase", phase)
	var rear_sway := sin(phase - 1.16 * 1.3) * smoothstep(0.1, 1.2, 1.16) * 0.065 * movement
	tail_left.position.x = -0.065 + rear_sway
	tail_right.position.x = 0.065 + rear_sway


func _fore_flipper(side: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "LeftFlipper" if side < 0.0 else "RightFlipper"
	var shape := _loft("ForeFlipper", [
		Vector4(-0.11, 0.035, 0.025, 0), Vector4(0.0, 0.125, 0.072, 0),
		Vector4(0.17, 0.139, 0.045, -0.008), Vector4(0.36, 0.102, 0.026, -0.018),
		Vector4(0.50, 0.057, 0.016, -0.023), Vector4(0.55, 0.008, 0.005, -0.023)
	], material, 6, 32)
	shape.rotation.y = side * PI * 0.5
	pivot.add_child(shape)
	return pivot


func _hind_flipper(side: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "TailLeft" if side < 0.0 else "TailRight"
	pivot.position = Vector3(side * 0.065, -0.235, 1.16)
	# Each hind foot opens into its own webbed fan, with five soft scallops.
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3] = []
	var rows := 18
	var columns := 30
	for layer in 2:
		for row in rows + 1:
			var t := float(row) / rows
			for column in columns + 1:
				var u := float(column) / columns
				var width := lerpf(0.055, 0.30, sin(t * PI * 0.5))
				var scallop := (0.5 + 0.5 * cos(u * TAU * 4.0)) * 0.028 * pow(t, 5.0)
				var x := side * (0.04 + t * 0.09 + (u - 0.5) * width)
				var z := t * (0.49 + 0.07 * absf(u - 0.5) * 2.0) - scallop
				var thickness := 0.008 + sin(t * PI) * 0.021
				var y := (1.0 if layer == 0 else -1.0) * thickness - t * 0.13 + sin(t * PI) * 0.014
				vertices.append(Vector3(x, y, z))
	for vertex in vertices:
		mesh.add_vertex(vertex)
	var stride := columns + 1
	var layer_size := (rows + 1) * stride
	for layer in 2:
		for row in rows:
			for col in columns:
				var a := layer * layer_size + row * stride + col
				_quad(mesh, a, a + 1, a + stride + 1, a + stride, (side > 0.0) != (layer == 1))
	# Close both side edges and the scalloped tip.
	for row in rows:
		for col in [0, columns]:
			var a: int = row * stride + col
			_quad(mesh, a, a + stride, a + stride + layer_size, a + layer_size, (side > 0.0) != (col == 0))
	for col in columns:
		var a := rows * stride + col
		_quad(mesh, a, a + layer_size, a + layer_size + 1, a + 1, side > 0.0)
	mesh.generate_normals()
	var shape := MeshInstance3D.new()
	shape.name = "WebbedHindFlipper"
	shape.mesh = mesh.commit()
	shape.material_override = material
	pivot.add_child(shape)
	return pivot


func _quad(surface: SurfaceTool, a: int, b: int, c: int, d: int, reverse: bool = false) -> void:
	for index in ([a, b, c, a, c, d] if reverse else [a, c, b, a, d, c]):
		surface.add_index(index)


func _loft(node_name: String, sections: Array[Vector4], material: Material, subdivisions: int, sides: int) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_count := (sections.size() - 1) * subdivisions + 1
	for ring in ring_count:
		var segment := mini(ring / subdivisions, sections.size() - 2)
		var t := float(ring - segment * subdivisions) / subdivisions
		var a := sections[maxi(segment - 1, 0)]
		var b := sections[segment]
		var c := sections[segment + 1]
		var d := sections[mini(segment + 2, sections.size() - 1)]
		var section := (b * 2.0 + (c - a) * t + (a * 2.0 - b * 5.0 + c * 4.0 - d) * t * t + (-a + b * 3.0 - c * 3.0 + d) * t * t * t) * 0.5
		var width := maxf(0.002, section.y)
		var height := maxf(0.002, section.z)
		var center := section.w
		for side in sides:
			var angle := TAU * float(side) / sides
			var y := sin(angle) * height
			# A slightly flattened underside rests naturally on the ice.
			if y < 0.0:
				y *= 0.94
			surface.add_vertex(Vector3(cos(angle) * width, center + y, lerpf(b.x, c.x, t)))
	for ring in ring_count - 1:
		for side in sides:
			var a := ring * sides + side
			var b := ring * sides + (side + 1) % sides
			_quad(surface, a, b, b + sides, a + sides)
	# End caps are tiny but closed, including the nose and pelvic tip.
	for side in range(1, sides - 1):
		surface.add_index(0)
		surface.add_index(side)
		surface.add_index(side + 1)
		var base := (ring_count - 1) * sides
		surface.add_index(base)
		surface.add_index(base + side + 1)
		surface.add_index(base + side)
	surface.generate_normals()
	var result := MeshInstance3D.new()
	result.name = node_name
	result.mesh = surface.commit()
	result.material_override = material
	return result


func _curve(node_name: String, points: Array[Vector3], radius: float, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	var sides := 6
	for step in steps + 1:
		var t := float(step) / steps
		var center := (1.0 - t) * (1.0 - t) * points[0] + 2.0 * (1.0 - t) * t * points[1] + t * t * points[2]
		var direction := (2.0 * (1.0 - t) * (points[1] - points[0]) + 2.0 * t * (points[2] - points[1])).normalized()
		var normal := direction.cross(Vector3.FORWARD).normalized()
		var binormal := direction.cross(normal).normalized()
		for side in sides:
			var angle := TAU * float(side) / sides
			surface.add_vertex(center + (normal * cos(angle) + binormal * sin(angle)) * radius * lerpf(1.0, 0.16, t))
	for step in steps:
		for side in sides:
			var a := step * sides + side
			var b := step * sides + (side + 1) % sides
			_quad(surface, a, b, b + sides, a + sides)
	surface.generate_normals()
	var result := MeshInstance3D.new()
	result.name = node_name
	result.mesh = surface.commit()
	result.material_override = material
	return result


func _ellipsoid(node_name: String, location: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 40
	sphere.rings = 24
	result.mesh = sphere
	result.position = location
	result.scale = dimensions
	result.material_override = material
	return result


func _fur(color: Color, articulated: bool = false) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = FUR_SHADER
	result.set_shader_parameter("fur_color", color)
	result.set_shader_parameter("deform_head", articulated)
	result.set_shader_parameter("head_pose", Transform3D(Basis.IDENTITY, HEAD_ORIGIN))
	return result


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result
