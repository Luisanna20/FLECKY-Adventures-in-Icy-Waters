extends Node3D
## Conservative interior volume, evaluated immediately from world position.
func _init() -> void:
	name="CaveShelter"
	add_to_group("shark_shelter")

func contains_point(world_position: Vector3) -> bool:
	var p := to_local(world_position)
	if p.z<1.2 or p.z>9.1 or p.y < -14.2 or p.y > -6.6:
		return false
	var h := (p.y+14.5)/8.3
	var half_width := minf(2.65,3.35*sqrt(maxf(0.0,1.0-h*h))-0.20)
	return absf(p.x-0.20) < half_width

func waiting_position(phase: float) -> Vector3:
	return to_global(Vector3(sin(phase)*4.2,-8.7,-6.0-cos(phase)*0.8))

func keep_shark_out(shark: Node3D) -> void:
	var p := to_local(shark.global_position)
	if absf(p.x)<10.0 and p.z > -2.8 and p.z<13.0 and p.y< -3.0:
		p.z=-2.8
		shark.global_position=to_global(p)
		shark.swim_velocity=Vector3.ZERO
