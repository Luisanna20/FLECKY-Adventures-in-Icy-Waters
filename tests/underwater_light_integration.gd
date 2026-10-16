extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	seed(742198)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	var watchdog := Timer.new()
	watchdog.wait_time=45.0
	watchdog.one_shot=true
	game.add_child(watchdog)
	watchdog.timeout.connect(func(): push_error("Light integration timeout"); quit(1))
	watchdog.start()
	for frame in 45: await physics_frame
	var sunlight = game.get_node("WaterEnvironmentController/UnderwaterSunlight")
	assert(sunlight._material.get_shader_parameter("blockers_ready"))
	var map: Image=sunlight._material.get_shader_parameter("blocker_map").get_image()
	assert(map.get_width()==128 and map.get_height()==128)
	var sun: Vector3=game.get_node("ColdSun").global_basis.z.normalized()
	for index in 5:
		var floe = game.get_node("ExpandedIcyBay/IceFloe_%02d" % index)
		var point: Vector3=floe.global_position+Vector3.DOWN*3.0
		assert(blocker_height(map,point,sun)>point.y+0.5,"Sunlight leaks through a floe")
	var cave = get_first_node_in_group("octopus_cave")
	for z in [3.0,5.0,7.0]:
		var point: Vector3=cave.to_global(Vector3(0,-9.2,z))
		assert(blocker_height(map,point,sun)>point.y+0.5,"Sunlight leaks through cave roof")
	var open := Vector3(0,-5,0)
	assert(blocker_height(map,open,sun)<open.y-0.5,"Open water incorrectly blocked")
	var camera = root.get_camera_3d()
	game._camera_rig.set_process(false)
	game._camera_rig.set_physics_process(false)
	camera.reparent(game)
	camera.global_position=Vector3(0,-7,5)
	for frame in 45: await physics_frame
	assert(sunlight.visible and sunlight._amount>0.95)
	camera.global_position=Vector3(0,3,5)
	for frame in 45: await physics_frame
	assert(not sunlight.visible and sunlight._amount<0.01)
	print("UNDERWATER_LIGHT_PASS ice_shadows=5 cave_roof=3 open_water=1 dive_resurface=PASS")
	quit()

func blocker_height(map: Image,point: Vector3,sun: Vector3) -> float:
	var surface := Vector2(point.x,point.z)-point.y*Vector2(sun.x,sun.z)/sun.y
	var uv := surface/200.0+Vector2(0.5,0.5)
	return map.get_pixel(clampi(int(uv.x*128),0,127),clampi(int(uv.y*128),0,127)).r*50.0-22.0
