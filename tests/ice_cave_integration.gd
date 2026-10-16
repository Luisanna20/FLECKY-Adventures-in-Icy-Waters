extends SceneTree
## Run: Godot --headless --path . --script res://tests/ice_cave_integration.gd -- --integration

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
	watchdog.timeout.connect(func(): push_error("Integration timeout"); quit(1))
	watchdog.start()
	for frame in 30: await physics_frame
	var player = game._flaki
	var manager = game._shark_manager
	player.set_physics_process(false)
	manager.set_process(false)
	var cave = get_first_node_in_group("octopus_cave")
	var refuge = get_first_node_in_group("shark_shelter")
	player._movement_mode=player.MovementMode.SWIMMING
	for point in [Vector3(0,-9,3),Vector3(0,-13.8,5),Vector3(1,-10,8),Vector3(-1,-8.5,4)]:
		player.global_position=cave.to_global(point)
		assert(player.is_safe_from_shark(),"Interior must be safe: %s" % point)
		var hearts_before: int=manager.hearts
		assert(not manager.debug_attempt_contact_bite())
		manager.debug_apply_bite()
		assert(manager.hearts==hearts_before,"Forced bite bypassed cave protection")
	for point in [Vector3(0,-9,-1),Vector3(0,-3,4),Vector3(7,-9,4),Vector3(0,-9,12),Vector3(0,-16,4)]:
		player.global_position=cave.to_global(point)
		assert(not player.is_safe_from_shark(),"Protection leaks outside: %s" % point)
	player.global_position=cave.to_global(Vector3(0,-9.2,3))
	manager.force_attack_for_test()
	for step in 35: manager._process(1.0/60)
	assert(manager.get_state_name()=="CIRCLING")
	game._process(0.0)
	assert(game._catch_prompt_label.text=="PROMPT_CAVE_SAFE")
	assert(not game._shark_alert_panel.visible)
	for step in 120: manager._process(1.0/60)
	assert(manager.get_state_name()=="RETREATING")
	for step in 1300:
		manager._process(1.0/60)
		assert(not refuge.contains_point(manager.get_shark().global_position),"Shark entered shelter")
		if manager.get_state_name()=="COOLDOWN": break
	assert(manager.get_state_name()=="COOLDOWN","Cave retreat did not finish")
	manager.force_attack_for_test()
	for step in 20: manager._process(1.0/60)
	assert(manager.get_state_name()=="CIRCLING")
	player.global_position=cave.to_global(Vector3(0,-9.2,-5))
	manager._process(1.0/60)
	assert(manager.get_state_name()=="HUNTING","Leaving cave must restore hunt")
	manager._invulnerability_time=0
	manager._bite_requires_separation=false
	assert(manager.debug_attempt_contact_bite(),"Leaving cave must restore vulnerability")
	game._process(0.0)
	assert(game._catch_prompt_label.text!="PROMPT_CAVE_SAFE")
	player._movement_mode=player.MovementMode.ON_ICE
	assert(player.is_safe_from_shark() and not manager.debug_attempt_contact_bite())
	print("CAVE_SHELTER_PASS interior=4 exterior=5 retreat_and_exit=PASS ice_safety=PASS")
	for frame in 2: await physics_frame
	var space = game.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius=0.52
	var exits := get_nodes_in_group("ice_exit_zone")
	assert(exits.size()==20)
	for zone in exits:
		var landing: Vector3=zone.get_landing_position()
		var ray := PhysicsRayQueryParameters3D.create(landing+Vector3.UP,landing-Vector3.UP,1)
		ray.exclude=[player.get_rid()]
		var hit: Dictionary=space.intersect_ray(ray)
		assert(not hit.is_empty() and hit.collider==zone.get_parent(),"Landing lacks ice: %s %s hit=%s" % [zone.get_path(),landing,hit])
		assert(absf(landing.y-hit.position.y-0.485)<0.025,"Landing does not match snow surface")
		assert(hit.normal.y>0.9,"Inverted or excessively steep snow surface")
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=sphere
		query.collision_mask=1
		query.exclude=[player.get_rid()]
		query.transform=Transform3D(Basis.IDENTITY,zone.get_water_position())
		assert(space.intersect_shape(query).is_empty(),"Water return intersects ice")
	for index in 5:
		var floe = game.get_node("ExpandedIcyBay/IceFloe_%02d" % index)
		var mesh: ArrayMesh=floe.get_node("IrregularIceBody").mesh
		assert(mesh.get_aabb().position.y+floe.position.y> -1.7,"Keel blocks too much swimming space")
		var center: Vector3=floe.global_position
		var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.DOWN*4,center,1))
		assert(not hit.is_empty() and hit.collider==floe and hit.normal.y< -0.8,"Underside missing or inverted")
	print("SCULPTED_ICE_PASS landing_and_water_exits=20 shallow_keels=5")
	print("ICE_CAVE_INTEGRATION_PASS")
	quit()
