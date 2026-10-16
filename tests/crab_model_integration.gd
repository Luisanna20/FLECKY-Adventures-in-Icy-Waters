extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage); current_scene=stage
	var crab := AmbientCrab.new()
	stage.add_child(crab)
	crab.configure([Vector3.ZERO,Vector3(4,0,0)])
	crab.set_process(false)
	var original: Node3D=AmbientCrab.CRAB_SCENE.instantiate()
	var old_mesh: MeshInstance3D=original.find_children("*","MeshInstance3D",true,false)[0]
	var visual: MeshInstance3D=crab.find_children("*","MeshInstance3D",true,false)[0]
	assert(visual.skin==old_mesh.skin)
	assert(visual.mesh!=old_mesh.mesh and visual.mesh.get_surface_count()==1)
	var arrays := visual.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	for index in vertices.size():
		var sum := 0.0
		for influence in 4:
			sum+=weights[index*4+influence]
			assert(bones[index*4+influence]<visual.skin.get_bind_count())
		assert(absf(sum-1.0)<0.0001)
	var skeleton: Skeleton3D=crab.find_children("*","Skeleton3D",true,false)[0]
	var old_player: AnimationPlayer=original.find_child("AnimationPlayer",true,false)
	for clip in [AmbientCrab.WALK_ANIMATION,AmbientCrab.THREAT_ANIMATION,AmbientCrab.DANCE_ANIMATION]:
		assert(crab._animation_player.get_animation(clip)==old_player.get_animation(clip))
		crab._animation_player.play(clip)
		crab._animation_player.seek(0.0,true)
		var initial := skeleton.get_bone_pose_rotation(skeleton.find_bone("Head"))
		var moved := false
		for step in 10:
			crab._animation_player.seek(float(step)*0.13,true)
			if not initial.is_equal_approx(skeleton.get_bone_pose_rotation(skeleton.find_bone("Head"))): moved=true
		assert(moved,"Preserved clip is not moving the shell")
	crab.debug_resume_route()
	var start := crab.global_position
	crab._process(1.0)
	assert(crab.global_position.distance_to(start)>0.4)
	crab._start_threat()
	assert(crab.is_threatening())
	crab.on_flaki_voice(crab.global_position+Vector3.RIGHT)
	assert(crab.is_dancing() and crab.get_dance_count()==1)
	crab._process(0.1)
	assert(crab._shell_material.get_shader_parameter("walking")==0.0)
	crab._process(3.0)
	assert(crab.is_walk_animation_playing())
	crab._ground_height=func(x: float,z: float) -> float: return x*0.2+z*0.1
	crab.rotation.y=0.7
	crab._align_to_ground(1.0)
	assert(crab._visual.global_basis.y.normalized().dot(Vector3(-0.2,1.0,-0.1).normalized())>0.999)
	original.free()
	print("CRAB_MODEL_PASS original_skin_and_clips=UNCHANGED weights=PASS walk_threat_dance_resume=PASS vertices=",vertices.size())
	quit()
