extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene=stage
	for species in 3:
		var fish := BayFish.new()
		stage.add_child(fish)
		fish.configure(Vector3.ZERO,null,10+species,Color.WHITE,species)
		fish.set_physics_process(false)
		var original: Node3D=BayFish.FISH_SCENES[species].instantiate()
		var source_instance: MeshInstance3D=original.find_children("*","MeshInstance3D",true,false)[0]
		var actual_instance: MeshInstance3D=fish.find_children("*","MeshInstance3D",true,false)[0]
		var source := source_instance.mesh
		var actual := actual_instance.mesh
		assert(source.get_surface_count()==actual.get_surface_count())
		assert(source_instance.skin.get_bind_count()==actual_instance.skin.get_bind_count())
		for bind in source_instance.skin.get_bind_count():
			assert(source_instance.skin.get_bind_pose(bind)==actual_instance.skin.get_bind_pose(bind))
		for surface in source.get_surface_count():
			var before := source.surface_get_arrays(surface)
			var after := actual.surface_get_arrays(surface)
			for field in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
				assert(before[field]==after[field],"Skinning or topology changed")
			assert(after[Mesh.ARRAY_TEX_UV].size()==after[Mesh.ARRAY_VERTEX].size())
			assert(actual.surface_get_material(surface) is ShaderMaterial)
		var skeleton: Skeleton3D=fish.find_children("*","Skeleton3D",true,false)[0]
		for clip in [BayFish.SWIM_NORMAL,BayFish.SWIM_FAST,BayFish.OUT_OF_WATER]:
			fish._animation_player.play(clip)
			fish._animation_player.seek(0.0,true)
			var poses: Array[Quaternion]=[]
			for bone in skeleton.get_bone_count(): poses.append(skeleton.get_bone_pose_rotation(bone))
			fish._animation_player.seek(0.19,true)
			var moved := false
			for bone in skeleton.get_bone_count():
				if not poses[bone].is_equal_approx(skeleton.get_bone_pose_rotation(bone)): moved=true
			assert(moved,"Animation does not move bones: %s" % clip)
		var second := BayFish.new()
		stage.add_child(second)
		second.configure(Vector3.ZERO,null,23,Color.WHITE,species)
		var second_mesh: MeshInstance3D=second.find_children("*","MeshInstance3D",true,false)[0]
		assert(second_mesh.mesh==actual,"Prepared meshes are not shared")
		original.free()
	print("FISH_APPEARANCE_PASS three_species topology_weights_bind_poses=UNCHANGED animated_clips=9 mesh_sharing=PASS")
	quit()
