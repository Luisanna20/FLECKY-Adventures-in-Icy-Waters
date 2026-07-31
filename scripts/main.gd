extends Node3D

const FLAKI_SCENE := preload("res://scenes/flaki.tscn")
const CAMERA_RIG_SCENE := preload("res://scenes/camera_rig.tscn")
const WATER_SHADER := preload("res://shaders/icy_water.gdshader")
const UNDERWATER_GROUND_SHADER := preload("res://shaders/underwater_ground.gdshader")
const ARCTIC_DAY_SKY_SHADER := preload("res://shaders/arctic_day_sky.gdshader")
const ARCTIC_DAY_PANORAMA := preload("res://assets/textures/sky/arctic_day_panorama.png")
const UNDERWATER_PLANT_SHADER := preload("res://shaders/underwater_plant.gdshader")
const TREASURE_GOLD_SHADER := preload("res://shaders/treasure_gold.gdshader")
const KELP_SCENE := preload("res://assets/models/underwater_plants/kelp.glb")
const SEAWEED_SCENE := preload("res://assets/models/underwater_plants/seaweed_3.glb")
const TREASURE_CHEST_SCENE := preload("res://assets/models/treasure/chest_with_gold.glb")
const SEABED_DIFFUSE := preload("res://assets/textures/seabed/low_tide_rocks_diff_1k.jpg")
const SEABED_ROUGHNESS := preload("res://assets/textures/seabed/low_tide_rocks_rough_1k.jpg")
const SEABED_DISPLACEMENT := preload("res://assets/textures/seabed/low_tide_rocks_disp_1k.jpg")
const SNOW_DIFFUSE := preload("res://assets/textures/snow_02/snow_02_diff_1k.jpg")
const SNOW_NORMAL := preload("res://assets/textures/snow_02/snow_02_nor_gl_1k.jpg")
const SNOW_ROUGHNESS := preload("res://assets/textures/snow_02/snow_02_rough_1k.jpg")
const WATER_LEVEL := 0.0
const BAY_RADIUS := 67.0
const BAY_FLOOR_DEPTH := -14.0
const OCTOPUS_CAVE_ENTRANCE := Vector3(45.5, 0.0, 27.5)

var _flaki: FlakiController
var _state_label: Label
var _depth_label: Label
var _fish_label: Label
var _objective_label: Label
var _catch_prompt_label: Label
var _shark_alert_panel: PanelContainer
var _shark_alert_label: Label
var _fish_manager: FishManager
var _ice_manager: IceInteractionManager
var _shark_manager: SharkManager
var _demo_flow: DemoFlowManager
var _game_menus: GameMenusController
var _achievement_manager: AchievementManager
var _music_manager: BayMusicManager
var _camera_rig: FlakiCameraRig
var _water_effects: FlakiWaterEffects
var _water_material: ShaderMaterial
var _hearts_label: Label
var _controls_label: Label
var _danger_overlay: ColorRect
var _hud_canvas: CanvasLayer
var _fish_prompt_text := ""
var _ice_prompt_text := ""
var _shark_alert_text := ""
var _caught_fish := 0
var _fish_target := FishManager.TARGET_FISH
var _danger_active := false
var _damage_flash_time := 0.0
var _safety_prompt_time := 0.0
var _victory_finished := false
var _free_roam_active := false
var _gameplay_started := false
var _was_bitten_this_run := false
var _voice_uses_this_run := 0
var _ice_rest_time := 0.0
var _achievement_treasure: Node3D
var _environment: Environment
var _plant_material_cache := {}
var _plant_interaction_position := Vector3(0.0, -1000.0, 0.0)
var _plant_interaction_velocity := Vector3.ZERO
var _plant_interaction_activity := 0.0
var _plant_interaction_initialized := false
var _sun_direction := Vector3(0.073, 0.633, -0.771).normalized()


func _ready() -> void:
	_apply_requested_locale()
	_register_input_actions()
	_build_environment()
	_build_bay()
	_spawn_flaki()
	_build_achievements()
	_build_hud()
	_build_water_environment_controller()
	_build_flaki_water_effects()
	_build_fish()
	_build_ambient_life()
	_build_ice_interactions()
	_build_shark()
	_build_game_menus()
	_build_music()
	_build_demo_flow()
	_maybe_capture_preview.call_deferred()
	_maybe_run_smoke_test.call_deferred()


func _process(delta: float) -> void:
	_update_underwater_plant_interaction(delta)
	_update_achievement_progress(delta)
	if is_instance_valid(_flaki) and is_instance_valid(_depth_label):
		var depth := maxf(WATER_LEVEL - _flaki.global_position.y - 0.48, 0.0)
		_depth_label.text = tr("HUD_DEPTH") % depth
	if is_instance_valid(_danger_overlay):
		_damage_flash_time = maxf(_damage_flash_time - delta, 0.0)
		var danger_alpha := 0.0
		if _damage_flash_time > 0.0:
			danger_alpha = 0.24 * (_damage_flash_time / 0.42)
		elif _danger_active:
			danger_alpha = 0.028 + sin(Time.get_ticks_msec() * 0.008) * 0.014
		_danger_overlay.color = Color(0.55, 0.02, 0.025, maxf(danger_alpha, 0.0))
	if _safety_prompt_time > 0.0:
		_safety_prompt_time = maxf(_safety_prompt_time - delta, 0.0)
		if _safety_prompt_time <= 0.0:
			_clear_safety_prompt()
	if is_instance_valid(_shark_alert_panel) and _shark_alert_panel.visible:
		_shark_alert_panel.modulate.a = 0.91 + sin(Time.get_ticks_msec() * 0.009) * 0.09


func _build_achievements() -> void:
	_achievement_manager = AchievementManager.new()
	_achievement_manager.name = "AchievementManager"
	add_child(_achievement_manager)
	var persistence_enabled := OS.get_cmdline_user_args().is_empty()
	_achievement_manager.configure(persistence_enabled)
	_flaki.splash_landed.connect(_on_breach_landed_for_achievement)
	_flaki.voice_played.connect(_on_flaki_voice_for_achievement)


func _update_achievement_progress(delta: float) -> void:
	if (
		not _gameplay_started
		or not is_instance_valid(_achievement_manager)
		or not is_instance_valid(_flaki)
	):
		return
	if not _achievement_manager.is_unlocked("treasure_depths"):
		if not is_instance_valid(_achievement_treasure):
			_achievement_treasure = (
				get_tree().get_first_node_in_group("octopus_treasure") as Node3D
			)
		if (
			is_instance_valid(_achievement_treasure)
			and _flaki.global_position.distance_to(
				_achievement_treasure.global_position
			) <= 7.0
		):
			_achievement_manager.unlock("treasure_depths")

	if (
		_flaki.is_on_ice()
		and (
			not is_instance_valid(_game_menus)
			or not _game_menus.is_victory_visible()
		)
	):
		_ice_rest_time += delta
		if _ice_rest_time >= 30.0:
			_achievement_manager.unlock("seal_rest")
	else:
		_ice_rest_time = 0.0


func _maybe_capture_preview() -> void:
	var arguments := OS.get_cmdline_user_args()
	var capture_surface := "--capture-preview" in arguments
	var capture_underwater := "--capture-underwater-preview" in arguments
	var capture_fish := "--capture-fish-preview" in arguments
	var capture_plants := "--capture-plants-preview" in arguments
	var capture_ice := "--capture-ice-preview" in arguments
	var capture_face := "--capture-face-preview" in arguments
	var capture_face_side := "--capture-face-side-preview" in arguments
	var capture_body_side := "--capture-body-side-preview" in arguments
	var capture_ice_underwater := "--capture-ice-underwater-preview" in arguments
	var capture_ice_grazing := "--capture-ice-grazing-preview" in arguments
	var capture_breach := "--capture-breach-preview" in arguments
	var capture_splash := "--capture-splash-preview" in arguments
	var capture_wake := "--capture-wake-preview" in arguments
	var capture_cave := "--capture-cave-preview" in arguments
	var capture_cave_side := "--capture-cave-side-preview" in arguments
	var capture_shark := "--capture-shark-preview" in arguments
	var capture_victory := "--capture-victory-preview" in arguments
	var capture_victory_pose := "--capture-victory-pose-preview" in arguments
	var capture_free_roam := "--capture-free-roam-preview" in arguments
	var capture_main_menu := "--capture-main-menu-preview" in arguments
	var capture_credits := "--capture-credits-preview" in arguments
	var capture_settings := "--capture-settings-preview" in arguments
	var capture_pause := "--capture-pause-preview" in arguments
	var capture_achievements := "--capture-achievements-preview" in arguments
	var capture_achievement_unlocked := (
		"--capture-achievement-unlocked-preview" in arguments
	)
	var capture_sky := "--capture-sky-preview" in arguments
	var capture_ambient := "--capture-ambient-preview" in arguments
	var capture_crab := "--capture-crab-preview" in arguments
	if (
		not capture_surface
		and not capture_underwater
		and not capture_fish
		and not capture_plants
		and not capture_ice
		and not capture_face
		and not capture_face_side
		and not capture_body_side
		and not capture_ice_underwater
		and not capture_ice_grazing
		and not capture_breach
		and not capture_splash
		and not capture_wake
		and not capture_cave
		and not capture_cave_side
		and not capture_shark
		and not capture_victory
		and not capture_victory_pose
		and not capture_free_roam
		and not capture_main_menu
		and not capture_credits
		and not capture_settings
		and not capture_pause
		and not capture_achievements
		and not capture_achievement_unlocked
		and not capture_sky
		and not capture_ambient
		and not capture_crab
	):
		return
	if capture_sky:
		_camera_rig.set_sky_preview_mode()
		for frame in 60:
			await get_tree().process_frame
	elif capture_credits:
		_game_menus.show_credits_for_preview()
		for frame in 60:
			await get_tree().process_frame
	elif capture_settings:
		_game_menus.show_settings_for_preview()
		for frame in 60:
			await get_tree().process_frame
	elif capture_pause:
		_game_menus.set_paused(true)
		for frame in 60:
			await get_tree().process_frame
	elif capture_achievements:
		_game_menus.show_achievements_for_preview()
		for frame in 60:
			await get_tree().process_frame
	elif capture_achievement_unlocked:
		_game_menus.show_achievements_for_preview()
		_achievement_manager.debug_unlock("treasure_depths")
		_achievement_manager.debug_unlock("flying_seal")
		for frame in 60:
			await get_tree().process_frame
	elif capture_main_menu:
		for frame in 60:
			await get_tree().process_frame
	elif capture_victory_pose:
		_demo_flow.start_victory()
		for frame in 720:
			await get_tree().process_frame
			if _demo_flow.has_victory_fish():
				break
		for frame in 70:
			await get_tree().process_frame
	elif capture_victory:
		_demo_flow.start_victory()
		for frame in 960:
			await get_tree().process_frame
			if _demo_flow.is_complete():
				break
		for frame in 60:
			await get_tree().process_frame
	elif capture_free_roam:
		_demo_flow.start_victory()
		for frame in 960:
			await get_tree().process_frame
			if _demo_flow.is_complete():
				break
		for frame in 60:
			await get_tree().process_frame
		_game_menus.debug_free_roam_choice()
		for frame in 80:
			await get_tree().process_frame
	elif capture_shark:
		_flaki.global_position = Vector3(0.0, WATER_LEVEL - 0.48, 12.0)
		_camera_rig.set_preview_angles(18.0, -22.0)
		_shark_manager.force_attack_for_test()
		for frame in 38:
			await get_tree().process_frame
		var preview_shark := _shark_manager.get_shark()
		var preview_camera := get_viewport().get_camera_3d()
		if is_instance_valid(preview_shark) and is_instance_valid(preview_camera):
			_camera_rig.target = null
			preview_camera.top_level = true
			preview_camera.global_position = (
				preview_shark.global_position
				+ Vector3(3.8, 6.8, 7.4)
			)
			preview_camera.look_at(
				Vector3(
					preview_shark.global_position.x,
					WATER_LEVEL,
					preview_shark.global_position.z
				),
				Vector3.UP
			)
			for frame in 6:
				await get_tree().process_frame
	elif capture_crab:
		var preview_crab := (
			get_tree().get_first_node_in_group("ambient_crab") as AmbientCrab
		)
		if is_instance_valid(preview_crab):
			_flaki.global_position = (
				preview_crab.global_position + Vector3(0.0, 0.0, 2.35)
			)
			_flaki.rotation.y = 0.0
			_camera_rig.set_preview_angles(20.0, -9.0)
			_flaki.play_voice_for_test()
			for frame in 18:
				await get_tree().process_frame
			var preview_camera := get_viewport().get_camera_3d()
			if is_instance_valid(preview_camera):
				_camera_rig.target = null
				preview_camera.top_level = true
				preview_camera.global_position = (
					preview_crab.global_position + Vector3(0.95, 0.65, 1.60)
				)
				preview_camera.look_at(
					preview_crab.global_position + Vector3(0.0, 0.22, 0.0),
					Vector3.UP
				)
				for frame in 3:
					await get_tree().process_frame
	elif capture_ambient:
		_flaki.global_position = Vector3(-8.0, -8.6, -23.0)
		_flaki.rotation.y = 0.0
		for frame in 80:
			await get_tree().process_frame
	elif capture_plants:
		var preview_plant: Node3D
		for plant_node in get_tree().get_nodes_in_group("underwater_plant"):
			var candidate := plant_node as Node3D
			if (
				is_instance_valid(candidate)
				and Vector2(
					candidate.global_position.x,
					candidate.global_position.z
				).length() < 24.0
				and candidate.global_position.y < -10.0
			):
				preview_plant = candidate
				break
		if is_instance_valid(preview_plant):
			_flaki.global_position = (
				preview_plant.global_position + Vector3(0.0, 1.25, 4.2)
			)
		else:
			_flaki.global_position = Vector3(-8.0, -12.2, -2.8)
		_flaki.rotation.y = 0.0
		_camera_rig.set_preview_angles(18.0, -8.0)
		Input.action_press("move_forward")
		Input.action_press("boost")
		for frame in 38:
			await get_tree().process_frame
		Input.action_release("move_forward")
		Input.action_release("boost")
		for frame in 5:
			await get_tree().process_frame
	elif capture_breach:
		_flaki.global_position = Vector3(0.0, WATER_LEVEL - 0.48, 12.0)
		_flaki.rotation.y = 0.0
		_flaki.force_breach_for_test()
		for frame in 31:
			await get_tree().physics_frame
	elif capture_splash:
		_flaki.global_position = Vector3(0.0, WATER_LEVEL - 0.48, 12.0)
		_flaki.rotation.y = 0.0
		var completed_before := _flaki.get_completed_breach_count()
		_flaki.force_breach_for_test()
		for frame in 100:
			await get_tree().physics_frame
			if _flaki.get_completed_breach_count() > completed_before:
				break
		for frame in 5:
			await get_tree().process_frame
	elif capture_wake:
		_flaki.global_position = Vector3(0.0, WATER_LEVEL - 0.48, 12.0)
		_flaki.rotation.y = 0.0
		Input.action_press("move_forward")
		for frame in 115:
			await get_tree().physics_frame
		Input.action_release("move_forward")
	elif capture_cave or capture_cave_side:
		var cave := get_tree().get_first_node_in_group("octopus_cave") as Node3D
		if is_instance_valid(cave):
			if capture_cave_side:
				_flaki.global_position = cave.to_global(Vector3(2.15, -9.0, 1.25))
			else:
				_flaki.global_position = cave.to_global(Vector3(0.0, -9.15, -5.5))
			_flaki.rotation.y = cave.global_rotation.y + PI
			_camera_rig.set_preview_angles(
				rad_to_deg(cave.global_rotation.y + PI)
					+ (52.0 if capture_cave_side else 0.0),
				-2.0 if capture_cave_side else -4.0
			)
		for frame in 90:
			await get_tree().process_frame
	elif capture_ice_underwater:
		_flaki.global_position = Vector3(3.0, -4.2, 40.0)
		_camera_rig.set_preview_angles(0.0, 31.0)
		for frame in 80:
			await get_tree().process_frame
	elif (
		capture_ice
		or capture_ice_grazing
		or capture_face
		or capture_face_side
		or capture_body_side
	):
		var preview_zone := get_tree().get_first_node_in_group("ice_exit_zone") as IceExitZone
		if is_instance_valid(preview_zone):
			_flaki.global_position = preview_zone.global_position
			for frame in 3:
				await get_tree().physics_frame
			Input.action_press("climb_ice")
			await get_tree().process_frame
			Input.action_release("climb_ice")
			for frame in 60:
				await get_tree().process_frame
			if capture_body_side:
				_camera_rig.camera_distance = 3.35
				_camera_rig.set_preview_angles(90.0, -2.0)
				for frame in 45:
					await get_tree().process_frame
			elif capture_face or capture_face_side:
				_camera_rig.camera_distance = 2.35
				_camera_rig.set_preview_angles(
					155.0 if capture_face_side else 180.0,
					-1.5
				)
				for frame in 25:
					await get_tree().process_frame
				_flaki.force_ice_idle_for_test()
				for frame in 20:
					await get_tree().process_frame
			elif capture_ice_grazing:
				_camera_rig.set_preview_angles(18.0, 44.0)
				for frame in 30:
					await get_tree().process_frame
	else:
		if capture_underwater:
			_flaki.global_position = Vector3(0.0, -5.0, 12.0)
			Input.action_press("dive_down")
		elif capture_fish:
			_flaki.global_position = Vector3(-21.0, -3.4, -4.5)
		Input.action_press("move_forward")
		for frame in 48:
			await get_tree().process_frame
		Input.action_release("move_forward")
		Input.action_release("dive_down")
	var preview := get_viewport().get_texture().get_image()
	var preview_path := "res://prototype_preview.png"
	if capture_sky:
		preview_path = "res://aurora_preview.png"
	elif capture_credits:
		preview_path = "res://credits_preview.png"
	elif capture_settings:
		preview_path = "res://settings_preview.png"
	elif capture_pause:
		preview_path = "res://pause_preview.png"
	elif capture_achievements:
		preview_path = "res://achievements_preview.png"
	elif capture_achievement_unlocked:
		preview_path = "res://achievement_unlocked_preview.png"
	elif capture_main_menu:
		preview_path = "res://main_menu_preview.png"
	elif capture_victory_pose:
		preview_path = "res://victory_pose_preview.png"
	elif capture_victory:
		preview_path = "res://victory_preview.png"
	elif capture_free_roam:
		preview_path = "res://free_roam_preview.png"
	elif capture_shark:
		preview_path = "res://shark_preview.png"
	elif capture_crab:
		preview_path = "res://crab_preview.png"
	elif capture_ambient:
		preview_path = "res://ambient_life_preview.png"
	elif capture_plants:
		preview_path = "res://plants_preview.png"
	elif capture_ice_underwater:
		preview_path = "res://ice_underwater_preview.png"
	elif capture_ice_grazing:
		preview_path = "res://ice_grazing_preview.png"
	elif capture_face:
		preview_path = "res://face_preview.png"
	elif capture_face_side:
		preview_path = "res://face_side_preview.png"
	elif capture_body_side:
		preview_path = "res://body_side_preview.png"
	elif capture_breach:
		preview_path = "res://breach_preview.png"
	elif capture_splash:
		preview_path = "res://splash_preview.png"
	elif capture_wake:
		preview_path = "res://wake_preview.png"
	elif capture_cave:
		preview_path = "res://cave_preview.png"
	elif capture_cave_side:
		preview_path = "res://cave_side_preview.png"
	elif capture_ice:
		preview_path = "res://ice_preview.png"
	elif capture_fish:
		preview_path = "res://fish_preview.png"
	elif capture_underwater:
		preview_path = "res://underwater_preview.png"
	var result := preview.save_png(preview_path)
	print("FLECKY preview capture: ", error_string(result))
	get_tree().quit()


func _maybe_run_smoke_test() -> void:
	if "--smoke-test" not in OS.get_cmdline_user_args():
		return
	var sample_fish := get_tree().get_first_node_in_group("catchable_fish") as BayFish
	var sample_fish_start := sample_fish.global_position if is_instance_valid(sample_fish) else Vector3.ZERO
	var sample_school := (
		get_tree().get_first_node_in_group("ambient_fish_school") as AmbientFishSchool
	)
	var sample_school_start := (
		sample_school.get_school_center_global()
		if is_instance_valid(sample_school)
		else Vector3.ZERO
	)
	var sample_crab := get_tree().get_first_node_in_group("ambient_crab") as AmbientCrab
	var sample_crab_start := (
		sample_crab.global_position if is_instance_valid(sample_crab) else Vector3.ZERO
	)
	var sample_octopus := (
		get_tree().get_first_node_in_group("ambient_octopus") as AmbientOctopus
	)
	var sample_cave := (
		get_tree().get_first_node_in_group("octopus_cave") as Node3D
	)
	var sample_cave_anchor := (
		get_tree().get_first_node_in_group("octopus_cave_anchor") as Node3D
	)
	var sample_treasure := (
		get_tree().get_first_node_in_group("octopus_treasure") as Node3D
	)
	var initial_ice_position := _flaki.global_position
	for frame in 24:
		await get_tree().physics_frame
	var intro_presentation_works := (
		_flaki.is_on_ice()
		and _flaki.is_safe_from_shark()
		and _flaki.is_ice_pose_relaxed()
		and _camera_rig.get_menu_shot_count() == 4
	)
	Input.action_press("climb_ice")
	await get_tree().process_frame
	Input.action_release("climb_ice")
	for frame in 60:
		await get_tree().physics_frame
	var started_from_ice := intro_presentation_works and _flaki.is_swimming()
	var start_position := _flaki.global_position
	Input.action_press("move_forward")
	Input.action_press("dive_down")
	for frame in 90:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("dive_down")
	var dive_position := _flaki.global_position
	_flaki.velocity.x = 0.0
	_flaki.velocity.z = 0.0

	Input.action_press("swim_up")
	for frame in 180:
		await get_tree().physics_frame
	Input.action_release("swim_up")
	for frame in 3:
		await get_tree().physics_frame
	var surfaced_position := _flaki.global_position

	var moved_forward := Vector2(
		dive_position.x - start_position.x,
		dive_position.z - start_position.z
	).length() > 1.0
	var moved_down := dive_position.y < start_position.y - 0.5
	var surface_is_clamped := (
		surfaced_position.y <= WATER_LEVEL - 0.48 + 0.001
		and surfaced_position.y >= WATER_LEVEL - 0.48 - 0.05
	)
	var breach_count_before := _flaki.get_completed_breach_count()
	_flaki.global_position = Vector3(0.0, WATER_LEVEL - 0.48, 12.0)
	_flaki.velocity = Vector3.ZERO
	_flaki.rotation.y = 0.0
	Input.action_press("move_forward")
	Input.action_press("swim_up")
	var breach_started_from_input := false
	for frame in 100:
		await get_tree().physics_frame
		if _flaki.is_breaching():
			breach_started_from_input = true
			break
	Input.action_release("move_forward")
	Input.action_release("swim_up")
	for frame in 120:
		await get_tree().physics_frame
		if _flaki.get_completed_breach_count() > breach_count_before:
			break
	for frame in 8:
		await get_tree().physics_frame
	var breach_works := (
		breach_started_from_input
		and _flaki.get_completed_breach_count() == breach_count_before + 1
		and _flaki.get_breach_peak_height() > WATER_LEVEL + 0.48
		and _flaki.is_swimming()
		and is_instance_valid(_water_effects)
		and _water_effects.get_splash_count() >= 1
	)
	_flaki.global_position = Vector3(0.0, WATER_LEVEL - 0.48, 8.0)
	_flaki.rotation.y = 0.0
	var trail_count_before := (
		_water_effects.get_trail_ripple_count()
		if is_instance_valid(_water_effects)
		else 0
	)
	Input.action_press("move_forward")
	for frame in 95:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var water_interaction_works := (
		is_instance_valid(_water_effects)
		and _water_effects.is_interactive_water_ready()
		and _water_effects.get_trail_ripple_count() > trail_count_before
		and float(_water_material.get_shader_parameter("swimmer_speed")) > 0.25
	)
	var voice_player := _flaki.get_node_or_null("FlakiVoice") as AudioStreamPlayer3D
	var voice_is_ready := (
		is_instance_valid(voice_player)
		and is_instance_valid(voice_player.stream)
		and voice_player.stream.get_length() > 0.0
	)
	var music_is_ready := (
		is_instance_valid(_music_manager)
		and _music_manager.is_ready_and_playing()
		and _music_manager.get_track_length() > 30.0
	)
	var fish_are_active := (
		is_instance_valid(_fish_manager)
		and _fish_manager.get_active_fish_count() >= 12
		and _fish_manager.get_active_species_count() == 3
		and _fish_manager.is_catch_audio_ready()
		and is_instance_valid(sample_fish)
		and sample_fish.global_position.distance_to(sample_fish_start) > 0.25
	)
	var fish_animation := (
		sample_fish.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if is_instance_valid(sample_fish)
		else null
	)
	var imported_fish_animates := (
		is_instance_valid(fish_animation)
		and not fish_animation.current_animation.is_empty()
	)
	var fish_environment_physics_ready := (
		is_instance_valid(_fish_manager)
		and _fish_manager.fish_environment_physics_ready()
	)
	var fish_avoids_seabed_objects := false
	var fish_obstacle_height := -INF
	var fish_obstacle_minimum := INF
	var test_shelf := get_node_or_null(
		"ExpandedIcyBay/UnderwaterShelf_00"
	) as StaticBody3D
	var test_shelf_collision: CollisionShape3D
	if is_instance_valid(test_shelf):
		for child in test_shelf.get_children():
			if child is CollisionShape3D:
				test_shelf_collision = child as CollisionShape3D
				break
	if (
		is_instance_valid(sample_fish)
		and is_instance_valid(test_shelf_collision)
		and test_shelf_collision.shape is CylinderShape3D
	):
		var shelf_shape := test_shelf_collision.shape as CylinderShape3D
		var shelf_top := test_shelf.global_position.y + shelf_shape.height * 0.5
		sample_fish.global_position = Vector3(
			test_shelf.global_position.x,
			shelf_top + BayFish.COLLISION_RADIUS + 0.24,
			test_shelf.global_position.z
		)
		sample_fish.debug_force_swim(Vector3.DOWN)
		for frame in 75:
			await get_tree().physics_frame
		fish_obstacle_height = sample_fish.global_position.y
		fish_obstacle_minimum = shelf_top + BayFish.COLLISION_RADIUS - 0.08
		fish_avoids_seabed_objects = (
			fish_obstacle_height >= fish_obstacle_minimum
		)
	var sample_plant := get_tree().get_first_node_in_group("underwater_plant") as Node3D
	var sample_plant_mesh := (
		sample_plant.find_child("*", true, false) as MeshInstance3D
		if is_instance_valid(sample_plant)
		else null
	)
	var sample_plant_material := (
		sample_plant_mesh.get_active_material(0)
		if is_instance_valid(sample_plant_mesh)
		else null
	)
	var underwater_plants_are_ready := (
		get_tree().get_node_count_in_group("underwater_plant") == 43
		and sample_plant_material is ShaderMaterial
		and (sample_plant_material as ShaderMaterial).shader == UNDERWATER_PLANT_SHADER
		and float(
			(sample_plant_material as ShaderMaterial).get_shader_parameter(
				"interaction_radius"
			)
		) >= 4.5
		and float(
			(sample_plant_material as ShaderMaterial).get_shader_parameter(
				"wake_length"
			)
		) >= 5.0
		and float(
			(sample_plant_material as ShaderMaterial).get_shader_parameter(
				"swimmer_activity"
			)
		) > 0.5
		and float(
			sample_plant_mesh.get_instance_shader_parameter("reaction_flex")
		) > 0.5
	)
	var seabed_body := get_node_or_null("ExpandedIcyBay/Seabed") as StaticBody3D
	var seabed_mesh := (
		seabed_body.find_child("*", false, false) as MeshInstance3D
		if is_instance_valid(seabed_body)
		else null
	)
	var seabed_material := (
		seabed_mesh.get_active_material(0)
		if is_instance_valid(seabed_mesh)
		else null
	)
	var seabed_texture_is_ready := (
		seabed_material is ShaderMaterial
		and (seabed_material as ShaderMaterial).shader == UNDERWATER_GROUND_SHADER
		and is_instance_valid(
			(seabed_material as ShaderMaterial).get_shader_parameter("seabed_diffuse")
		)
	)
	var sample_floe_mesh := get_node_or_null(
		"ExpandedIcyBay/IceFloe_00/IrregularIceBody"
	) as MeshInstance3D
	var sample_snow_material := (
		sample_floe_mesh.get_active_material(0)
		if is_instance_valid(sample_floe_mesh)
		else null
	)
	var sample_ice_side_material := (
		sample_floe_mesh.get_active_material(1)
		if is_instance_valid(sample_floe_mesh)
		else null
	)
	var ice_visuals_are_ready := (
		is_instance_valid(sample_floe_mesh)
		and sample_floe_mesh.mesh.get_surface_count() == 2
		and sample_snow_material is StandardMaterial3D
		and (sample_snow_material as StandardMaterial3D).albedo_texture == SNOW_DIFFUSE
		and (sample_snow_material as StandardMaterial3D).normal_texture == SNOW_NORMAL
		and (sample_snow_material as StandardMaterial3D).cull_mode
			== BaseMaterial3D.CULL_DISABLED
		and sample_ice_side_material is StandardMaterial3D
		and (sample_ice_side_material as StandardMaterial3D).cull_mode
			== BaseMaterial3D.CULL_DISABLED
		and get_tree().get_node_count_in_group("snow_feature") == 0
	)
	var sample_cliff_mesh := get_node_or_null(
		"ExpandedIcyBay/CliffSegment_00/RockSpire_0"
	) as MeshInstance3D
	var sample_cliff_material := (
		sample_cliff_mesh.get_active_material(0)
		if is_instance_valid(sample_cliff_mesh)
		else null
	)
	var icy_cliffs_are_ready := (
		sample_cliff_material is StandardMaterial3D
		and (sample_cliff_material as StandardMaterial3D).albedo_texture == SNOW_DIFFUSE
		and (sample_cliff_material as StandardMaterial3D).normal_texture == SNOW_NORMAL
		and (sample_cliff_material as StandardMaterial3D).uv1_triplanar
	)
	var ambient_fish_total := 0
	for school_node in get_tree().get_nodes_in_group("ambient_fish_school"):
		var school := school_node as AmbientFishSchool
		if is_instance_valid(school):
			ambient_fish_total += school.get_fish_count()
	var second_crab: AmbientCrab
	for crab_node in get_tree().get_nodes_in_group("ambient_crab"):
		var candidate_crab := crab_node as AmbientCrab
		if candidate_crab != sample_crab:
			second_crab = candidate_crab
			break
	var crab_reactions_work := false
	if is_instance_valid(sample_crab) and is_instance_valid(second_crab):
		var flaki_before_crab_test := _flaki.global_position
		_flaki.global_position = sample_crab.global_position + Vector3(2.7, 0.0, 0.0)
		for frame in 3:
			await get_tree().process_frame
		var threat_started := sample_crab.is_threatening()
		var second_dances_before := second_crab.get_dance_count()
		var voice_started := _flaki.play_voice_for_test()
		await get_tree().process_frame
		crab_reactions_work = (
			threat_started
			and voice_started
			and sample_crab.is_dancing()
			and sample_crab.get_dance_count() == 1
			and second_crab.get_dance_count() == second_dances_before
			and sample_crab.get_voice_dance_radius() < 8.0
		)
		sample_crab.debug_resume_route()
		second_crab.debug_resume_route()
		_flaki.global_position = flaki_before_crab_test
	var octopus_tracking_works := false
	if (
		is_instance_valid(sample_octopus)
		and is_instance_valid(sample_cave)
	):
		var flaki_before_octopus_test := _flaki.global_position
		_flaki.global_position = sample_cave.to_global(
			Vector3(2.1, -9.0, 0.8)
		)
		for frame in 42:
			await get_tree().process_frame
		var tracks_when_near := (
			sample_octopus.is_tracking_flaki()
			and sample_octopus.get_facing_error_to_flaki() < 0.30
			and sample_octopus.get_tracking_radius() <= 16.0
		)
		_flaki.global_position = flaki_before_octopus_test
		await get_tree().process_frame
		octopus_tracking_works = (
			tracks_when_near
			and not sample_octopus.is_tracking_flaki()
		)
	var ambient_life_is_ready := (
		get_tree().get_node_count_in_group("ambient_fish_school") == 4
		and ambient_fish_total == 52
		and is_instance_valid(sample_school)
		and sample_school.get_school_center_global().distance_to(sample_school_start) > 0.20
		and not sample_school.is_in_group("catchable_fish")
		and is_instance_valid(sample_crab)
		and get_tree().get_node_count_in_group("ambient_crab") == 2
		and sample_crab.global_position.distance_to(sample_crab_start) > 0.20
		and sample_crab.get_route_length() > 110.0
		and sample_crab.is_walk_animation_playing()
		and crab_reactions_work
		and not sample_crab.is_in_group("catchable_fish")
		and is_instance_valid(sample_octopus)
		and sample_crab_start.distance_to(sample_octopus.global_position) > 60.0
		and sample_octopus.is_idling()
		and sample_octopus.is_levitating()
		and octopus_tracking_works
		and not sample_octopus.is_in_group("catchable_fish")
	)
	var cave_entrance_clear := false
	if is_instance_valid(sample_cave) and is_instance_valid(sample_cave_anchor):
		var cave_ray := PhysicsRayQueryParameters3D.create(
			sample_cave.to_global(Vector3(0.0, -9.15, -4.5)),
			sample_cave_anchor.global_position,
			1
		)
		cave_ray.exclude = [_flaki.get_rid()]
		cave_entrance_clear = (
			get_world_3d().direct_space_state.intersect_ray(cave_ray).is_empty()
		)
	var cave_system_works := (
		is_instance_valid(sample_cave)
		and is_instance_valid(sample_cave_anchor)
		and is_instance_valid(sample_cave.get_node_or_null("CaveGlow"))
		and sample_cave.get_node_or_null("CaveMotes") is GPUParticles3D
		and sample_cave.get_node_or_null("CaveLeftWall") is StaticBody3D
		and sample_cave.get_node_or_null("CaveRightWall") is StaticBody3D
		and sample_cave.get_node_or_null("CaveLeftLining") is MeshInstance3D
		and sample_cave.get_node_or_null("CaveRightLining") is MeshInstance3D
		and sample_cave.get_node_or_null("CaveRoofLining") is MeshInstance3D
		and sample_cave.get_node_or_null("CaveBackLining") is MeshInstance3D
		and is_instance_valid(sample_treasure)
		and sample_treasure.get_node_or_null("ChestWithGold") is Node3D
		and sample_treasure.get_node_or_null("TreasureGlow") is OmniLight3D
		and sample_treasure.get_node_or_null("TreasurePulse") is AnimationPlayer
		and sample_treasure.get_node_or_null("TreasureSparkles") is GPUParticles3D
		and sample_treasure.get_node_or_null("GlowCoin_00") is MeshInstance3D
		and Vector2(
			sample_cave_anchor.global_position.x,
			sample_cave_anchor.global_position.z
		).length() <= _flaki.maximum_swim_radius
		and sample_octopus.global_position.distance_to(
			sample_cave_anchor.global_position
		) < 0.08
		and cave_entrance_clear
	)
	if is_instance_valid(sample_treasure):
		_flaki.global_position = (
			sample_treasure.global_position + Vector3(0.0, 0.8, 2.0)
		)
		for frame in 3:
			await get_tree().process_frame

	var catch_works := false
	if is_instance_valid(sample_fish):
		_flaki.rotation.y = 0.0
		_flaki.global_position = sample_fish.global_position + Vector3(0.0, 0.0, 1.5)
		catch_works = _fish_manager.attempt_catch() and _fish_manager.caught_count == 1

	_flaki.global_position = Vector3(BAY_RADIUS + 8.0, -2.0, 0.0)
	_flaki.velocity = Vector3(7.0, 0.0, 0.0)
	for frame in 2:
		await get_tree().physics_frame
	var boundary_is_sealed := Vector2(
		_flaki.global_position.x,
		_flaki.global_position.z
	).length() <= _flaki.maximum_swim_radius + 0.01
	var ice_transition_works := false
	var ice_idle_animation_works := false
	var ice_marker_visibility_works := false
	var all_ice_sides_are_accessible := (
		get_tree().get_node_count_in_group("ice_exit_zone") == 20
	)
	var test_ice_zone := get_tree().get_first_node_in_group("ice_exit_zone") as IceExitZone
	if is_instance_valid(test_ice_zone):
		_flaki.global_position = test_ice_zone.global_position
		_camera_rig.global_position = _flaki.global_position + Vector3.UP * 0.45
		var landing_position := test_ice_zone.get_landing_position()
		for frame in 4:
			await get_tree().process_frame
		var surface_marker_count := _visible_ice_marker_count()
		Input.action_press("climb_ice")
		await get_tree().process_frame
		Input.action_release("climb_ice")
		for frame in 75:
			await get_tree().physics_frame
		var landed_safely := (
			_flaki.is_on_ice()
			and _flaki.is_safe_from_shark()
			and _flaki.is_ice_pose_relaxed()
			and _flaki.global_position.distance_to(landing_position) < 0.08
		)
		var idle_started := landed_safely and _flaki.force_ice_idle_for_test()
		var maximum_idle_head_turn := 0.0
		var maximum_idle_whisker_motion := 0.0
		for frame in 72:
			await get_tree().physics_frame
			maximum_idle_head_turn = maxf(
				maximum_idle_head_turn,
				_flaki.get_ice_idle_head_turn_degrees()
			)
			maximum_idle_whisker_motion = maxf(
				maximum_idle_whisker_motion,
				_flaki.get_ice_idle_whisker_motion_degrees()
			)
		ice_idle_animation_works = (
			idle_started
			and _flaki.is_ice_idle_animation_active()
			and maximum_idle_head_turn > 4.0
			and maximum_idle_whisker_motion > 0.45
		)
		ice_marker_visibility_works = (
			surface_marker_count == 1
			and _visible_ice_marker_count() == 0
		)
		Input.action_press("climb_ice")
		await get_tree().process_frame
		Input.action_release("climb_ice")
		for frame in 55:
			await get_tree().physics_frame
		ice_transition_works = (
			landed_safely
			and _flaki.is_swimming()
			and not _flaki.is_ice_idle_animation_active()
		)
	var shark_system_works := false
	if is_instance_valid(_shark_manager):
		_shark_manager.force_attack_for_test()
		for frame in 45:
			await get_tree().physics_frame
		var shark_animation := (
			_shark_manager.get_shark().find_child("AnimationPlayer", true, false)
			as AnimationPlayer
		)
		var imported_shark_animates := (
			is_instance_valid(shark_animation)
			and not shark_animation.current_animation.is_empty()
		)
		var shark_state_started := _shark_manager.get_state_name() in [
			"HUNTING",
			"CIRCLING",
			"RETREATING",
		]
		var alert_banner_works := (
			is_instance_valid(_shark_alert_panel)
			and is_instance_valid(_shark_alert_label)
			and _shark_alert_panel.visible
			and not _shark_alert_label.text.is_empty()
		)
		if _shark_manager.hearts == SharkManager.MAX_HEARTS:
			_shark_manager.debug_apply_bite()
		var hearts_after_first_bite := _shark_manager.hearts
		var repeated_bite_was_blocked := (
			not _shark_manager.debug_attempt_contact_bite()
			and _shark_manager.hearts == hearts_after_first_bite
		)
		var remaining_hearts := _shark_manager.hearts
		for hit in remaining_hearts:
			_shark_manager.debug_apply_bite()
		await get_tree().physics_frame
		_fish_prompt_text = "PROMPT_BITTEN"
		_safety_prompt_time = 3.2
		_on_flaki_state_changed("STATE_RESTING")
		var safety_prompt_clears_on_ice := _fish_prompt_text.is_empty()
		shark_system_works = (
			shark_state_started
			and imported_shark_animates
			and _shark_manager.get_shark().is_surface_wake_ready()
			and alert_banner_works
			and repeated_bite_was_blocked
			and _shark_manager.hearts == SharkManager.MAX_HEARTS
			and _flaki.is_on_ice()
			and safety_prompt_clears_on_ice
		)
	var pause_system_works := (
		is_instance_valid(_game_menus)
		and _game_menus.debug_pause_cycle()
	)
	var credits_system_works := (
		is_instance_valid(_game_menus)
		and _game_menus.debug_credits_cycle()
	)
	var settings_system_works := (
		is_instance_valid(_game_menus)
		and _game_menus.debug_settings_cycle()
	)
	var localization_system_works := (
		is_instance_valid(_game_menus)
		and _game_menus.debug_localization_cycle()
	)
	var achievements_menu_works := (
		is_instance_valid(_game_menus)
		and _game_menus.debug_achievements_cycle()
	)
	var victory_system_works := false
	if is_instance_valid(_demo_flow):
		_demo_flow.start_victory()
		for frame in 720:
			await get_tree().physics_frame
			if _demo_flow.is_complete():
				break
		var victory_screen_was_ready := (
			_demo_flow.is_complete()
			and _demo_flow.has_victory_fish()
			and _shark_manager.is_disabled_for_victory()
			and _game_menus.is_victory_visible()
			and _flaki.is_on_ice()
		)
		var free_roam_choice_works := _game_menus.debug_free_roam_choice()
		await get_tree().process_frame
		var free_roam_started_on_ice := _flaki.is_on_ice()
		Input.action_press("climb_ice")
		await get_tree().process_frame
		Input.action_release("climb_ice")
		for frame in 55:
			await get_tree().physics_frame
		victory_system_works = (
			victory_screen_was_ready
			and free_roam_choice_works
			and _free_roam_active
			and _fish_manager.is_free_roam_mode()
			and _fish_manager.get_active_fish_count() == 0
			and _shark_manager.is_disabled_for_victory()
			and not _camera_rig.is_victory_mode()
			and free_roam_started_on_ice
			and _flaki.is_swimming()
			and _hud_canvas.visible
			and not _fish_label.visible
			and not _hearts_label.visible
		)
	var fish_physics_after_long_run := (
		is_instance_valid(_fish_manager)
		and _fish_manager.fish_environment_physics_ready()
	)
	var achievement_icons_are_ready := true
	if is_instance_valid(_achievement_manager):
		for definition in _achievement_manager.get_definitions():
			var icon_path := str(definition.get("icon", ""))
			achievement_icons_are_ready = (
				achievement_icons_are_ready
				and ResourceLoader.exists(icon_path)
				and load(icon_path) is Texture2D
			)
	var achievement_system_works := (
		is_instance_valid(_achievement_manager)
		and _achievement_manager.get_total_count() == 8
		and achievement_icons_are_ready
		and achievements_menu_works
		and _achievement_manager.is_unlocked("flying_seal")
		and _achievement_manager.is_unlocked("crab_dance")
		and _achievement_manager.is_unlocked("treasure_depths")
		and _achievement_manager.is_unlocked("free_swimmer")
		and not _achievement_manager.is_unlocked("vocalist")
		and not _achievement_manager.is_unlocked("seal_rest")
		and not _achievement_manager.is_unlocked("fish_day")
		and not _achievement_manager.is_unlocked("untouchable")
	)

	if (
		started_from_ice
		and moved_forward
		and moved_down
		and surface_is_clamped
		and breach_works
		and water_interaction_works
		and voice_is_ready
		and music_is_ready
		and fish_are_active
		and imported_fish_animates
		and fish_environment_physics_ready
		and fish_avoids_seabed_objects
		and fish_physics_after_long_run
		and underwater_plants_are_ready
		and seabed_texture_is_ready
		and ice_visuals_are_ready
		and icy_cliffs_are_ready
		and ambient_life_is_ready
		and cave_system_works
		and catch_works
		and boundary_is_sealed
		and all_ice_sides_are_accessible
		and ice_marker_visibility_works
		and ice_transition_works
		and ice_idle_animation_works
		and shark_system_works
		and pause_system_works
		and credits_system_works
		and settings_system_works
		and localization_system_works
		and achievement_system_works
		and victory_system_works
	):
		print(
			"FLECKY smoke test: PASS | start=",
			initial_ice_position,
			" water_entry=",
			start_position,
			" dive=",
			dive_position,
			" surfaced=",
			surfaced_position,
			" music_length=",
			_music_manager.get_track_length()
		)
		get_tree().quit()
	else:
		push_error(
			"FLECKY smoke test: FAIL | intro=%s forward=%s down=%s clamp=%s breach=%s water_interaction=%s voice=%s music=%s fish=%s fish_physics=%s fish_obstacle=%s fish_long=%s ice_visuals=%s ambient=%s cave=%s catch=%s boundary=%s ice_sides=%s ice_markers=%s ice=%s ice_idle=%s shark=%s pause=%s settings=%s localization=%s achievements=%s unlocked=%s victory=%s"
			% [
				started_from_ice,
				moved_forward,
				moved_down,
				surface_is_clamped,
				breach_works,
				water_interaction_works,
				voice_is_ready,
				music_is_ready,
				fish_are_active,
				fish_environment_physics_ready,
				fish_avoids_seabed_objects,
				fish_physics_after_long_run,
				ice_visuals_are_ready,
				ambient_life_is_ready,
				cave_system_works,
				catch_works,
				boundary_is_sealed,
				all_ice_sides_are_accessible,
				ice_marker_visibility_works,
				ice_transition_works,
				ice_idle_animation_works,
				shark_system_works,
				pause_system_works,
				settings_system_works,
				localization_system_works,
				achievement_system_works,
				(
					_achievement_manager.get_unlocked_ids()
					if is_instance_valid(_achievement_manager)
					else []
				),
				victory_system_works,
			]
		)
		print(
			"Fish obstacle test: y=",
			fish_obstacle_height,
			" minimum=",
			fish_obstacle_minimum
		)
		get_tree().quit(2)


func _visible_ice_marker_count() -> int:
	var visible_count := 0
	for node in get_tree().get_nodes_in_group("ice_exit_zone"):
		var zone := node as IceExitZone
		if is_instance_valid(zone) and zone.is_marker_visible():
			visible_count += 1
	return visible_count


func _register_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_backward", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("swim_up", KEY_SPACE)
	_add_key_action("dive_down", KEY_CTRL)
	_add_key_action("boost", KEY_SHIFT)
	_add_key_action("catch_fish", KEY_E)
	_add_key_action("climb_ice", KEY_F)
	_add_key_action("flaki_voice", KEY_V)
	_add_key_action("pause", KEY_ESCAPE)


func _apply_requested_locale() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="):
			Localization.set_language(argument.trim_prefix("--locale="), false)
			return


func _add_key_action(action_name: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey and existing_event.physical_keycode == physical_key:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	InputMap.action_add_event(action_name, event)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArcticEnvironment"
	_environment = Environment.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = ARCTIC_DAY_SKY_SHADER
	sky_material.set_shader_parameter("panorama_texture", ARCTIC_DAY_PANORAMA)
	sky_material.set_shader_parameter("sun_direction", _sun_direction)
	var arctic_sky := Sky.new()
	arctic_sky.sky_material = sky_material
	_environment.sky = arctic_sky
	_environment.background_mode = Environment.BG_SKY
	_environment.background_color = Color(0.12, 0.31, 0.43)
	_environment.background_energy_multiplier = 0.95
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.48, 0.67, 0.76)
	_environment.ambient_light_energy = 0.72
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.34, 0.55, 0.64)
	_environment.fog_density = 0.006
	_environment.fog_height = 3.0
	_environment.fog_height_density = 0.018
	_environment.fog_sky_affect = 0.06
	world_environment.environment = _environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "ColdSun"
	sun.light_color = Color(0.80, 0.92, 1.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at(sun.global_position - _sun_direction, Vector3.UP)
	_sun_direction = sun.global_basis.z.normalized()
	sky_material.set_shader_parameter("sun_direction", _sun_direction)


func _build_bay() -> void:
	var bay := Node3D.new()
	bay.name = "ExpandedIcyBay"
	add_child(bay)

	var seabed_material := _underwater_material(Color(0.10, 0.31, 0.34), 0.92, 0.24, 0.78)
	var shelf_material := _underwater_material(Color(0.14, 0.39, 0.41), 0.88, 0.28, 0.64)
	var ice_material := _snow_material()
	var ice_side_material := _material(Color(0.35, 0.62, 0.71), 0.74)
	ice_side_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cliff_material := _ice_cliff_material()
	var rock_material := _underwater_material(Color(0.18, 0.36, 0.39), 0.90, 0.20, 0.34)
	var snow_material := _snow_material()

	_create_cylinder_body(
		bay,
		"Seabed",
		Vector3(0.0, BAY_FLOOR_DEPTH - 0.6, 0.0),
		BAY_RADIUS + 1.0,
		1.2,
		seabed_material
	)

	var random := RandomNumberGenerator.new()
	random.seed = 742198
	for index in 30:
		var angle := TAU * float(index) / 30.0
		var radius := random.randf_range(BAY_RADIUS - 2.2, BAY_RADIUS + 1.8)
		var position := Vector3(cos(angle) * radius, BAY_FLOOR_DEPTH, sin(angle) * radius)
		_create_cliff_segment(
			bay,
			"CliffSegment_%02d" % index,
			position,
			-angle + PI * 0.5,
			random,
			cliff_material,
			snow_material
		)

	var floes := [
		[Vector3(-25.0, 0.20, -15.0), 7.6, 1.08],
		[Vector3(18.0, 0.16, -27.0), 6.8, 0.96],
		[Vector3(32.0, 0.18, 10.0), 8.4, 1.12],
		[Vector3(-29.0, 0.22, 27.0), 7.2, 1.04],
		[Vector3(3.0, 0.14, 34.0), 5.8, 0.88],
	]
	for index in floes.size():
		var data: Array = floes[index]
		_create_ice_floe(
			bay,
			"IceFloe_%02d" % index,
			data[0],
			data[1],
			data[2],
			ice_material,
			ice_side_material,
			float(index) * 1.73 + 0.45,
			index
		)

	var shallows := [
		[Vector3(-25.0, -10.9, -15.0), 12.0, 5.0],
		[Vector3(32.0, -11.5, 10.0), 13.0, 4.4],
		[Vector3(-29.0, -11.8, 27.0), 11.0, 3.8],
	]
	for index in shallows.size():
		var data: Array = shallows[index]
		_create_cylinder_body(
			bay,
			"UnderwaterShelf_%02d" % index,
			data[0],
			data[1],
			data[2],
			shelf_material
		)

	for index in 14:
		var angle := random.randf_range(0.0, TAU)
		var radius := random.randf_range(15.0, 53.0)
		var rock_height := random.randf_range(1.2, 4.2)
		_create_rock_pillar(
			bay,
			"UnderwaterRock_%02d" % index,
			Vector3(
				cos(angle) * radius,
				BAY_FLOOR_DEPTH + rock_height * 0.5,
				sin(angle) * radius
			),
			random.randf_range(0.8, 2.6),
			rock_height,
			rock_material
		)

	_create_octopus_cave(bay)
	_build_underwater_plants(bay, random)
	_create_water_surface(bay)


func _create_octopus_cave(parent: Node3D) -> void:
	var cave := Node3D.new()
	cave.name = "OctopusCave"
	cave.position = OCTOPUS_CAVE_ENTRANCE
	var inward_direction := Vector3(
		-OCTOPUS_CAVE_ENTRANCE.x,
		0.0,
		-OCTOPUS_CAVE_ENTRANCE.z
	).normalized()
	cave.rotation.y = atan2(-inward_direction.x, -inward_direction.z)
	cave.add_to_group("octopus_cave")
	parent.add_child(cave)

	var cave_material := _underwater_material(
		Color(0.075, 0.22, 0.27),
		0.96,
		0.18,
		0.82
	)
	var lining_material := _underwater_material(
		Color(0.035, 0.105, 0.14),
		0.98,
		0.08,
		0.62
	)
	_create_cave_collision_box(
		cave,
		"CaveLeftWall",
		Vector3(-4.35, -9.25, 4.25),
		Vector3(2.75, 8.7, 10.5),
		deg_to_rad(-4.0)
	)
	_create_cave_collision_box(
		cave,
		"CaveRightWall",
		Vector3(4.35, -9.25, 4.25),
		Vector3(2.75, 8.7, 10.5),
		deg_to_rad(4.0)
	)
	_create_cave_collision_box(
		cave,
		"CaveRoof",
		Vector3(0.0, -4.95, 4.20),
		Vector3(10.7, 2.35, 10.7),
		0.0
	)
	_create_cave_collision_box(
		cave,
		"CaveBackWall",
		Vector3(0.0, -9.30, 9.10),
		Vector3(10.3, 8.8, 2.4),
		0.0
	)
	_create_cave_lining_mesh(
		cave,
		"CaveLeftLining",
		Vector3(-4.35, -9.25, 5.05),
		Vector3(2.85, 8.8, 8.8),
		deg_to_rad(-4.0),
		lining_material
	)
	_create_cave_lining_mesh(
		cave,
		"CaveRightLining",
		Vector3(4.35, -9.25, 5.05),
		Vector3(2.85, 8.8, 8.8),
		deg_to_rad(4.0),
		lining_material
	)
	_create_cave_lining_mesh(
		cave,
		"CaveRoofLining",
		Vector3(0.0, -4.95, 5.05),
		Vector3(10.7, 2.35, 8.8),
		0.0,
		lining_material
	)
	_create_cave_lining_mesh(
		cave,
		"CaveBackLining",
		Vector3(0.0, -9.30, 9.05),
		Vector3(10.3, 8.8, 2.3),
		0.0,
		lining_material
	)

	var boulder_data: Array[Array] = [
		[Vector3(-4.20, -11.65, -0.20), Vector3(3.35, 3.25, 2.90), -0.18],
		[Vector3(-4.30, -8.90, -0.35), Vector3(3.25, 3.80, 2.85), 0.16],
		[Vector3(-3.85, -6.45, -0.15), Vector3(3.25, 3.05, 2.75), -0.11],
		[Vector3(4.15, -11.55, -0.15), Vector3(3.25, 3.35, 2.85), 0.21],
		[Vector3(4.30, -8.80, -0.30), Vector3(3.20, 3.75, 2.80), -0.16],
		[Vector3(3.85, -6.35, -0.12), Vector3(3.15, 3.00, 2.75), 0.12],
		[Vector3(-2.60, -5.10, -0.12), Vector3(3.85, 2.55, 3.05), 0.14],
		[Vector3(0.0, -4.62, -0.05), Vector3(4.20, 2.35, 3.10), -0.08],
		[Vector3(2.65, -5.05, -0.10), Vector3(3.80, 2.60, 3.00), 0.18],
		[Vector3(-4.42, -9.10, 3.25), Vector3(3.00, 4.50, 4.15), 0.24],
		[Vector3(4.45, -9.10, 3.35), Vector3(3.05, 4.45, 4.10), -0.20],
		[Vector3(-4.30, -9.05, 7.10), Vector3(3.20, 4.55, 4.00), -0.17],
		[Vector3(4.28, -9.05, 7.15), Vector3(3.15, 4.50, 4.05), 0.19],
		[Vector3(-2.65, -5.03, 3.60), Vector3(4.15, 2.45, 3.95), -0.12],
		[Vector3(2.55, -5.00, 3.70), Vector3(4.05, 2.42, 3.90), 0.13],
		[Vector3(-2.50, -5.02, 7.15), Vector3(4.30, 2.50, 3.85), 0.10],
		[Vector3(2.45, -5.00, 7.20), Vector3(4.20, 2.48, 3.80), -0.11],
		[Vector3(-2.85, -9.20, 9.00), Vector3(4.25, 5.65, 2.90), 0.08],
		[Vector3(2.75, -9.10, 9.00), Vector3(4.30, 5.70, 2.95), -0.09],
	]
	for index in boulder_data.size():
		var data := boulder_data[index]
		_create_cave_boulder(
			cave,
			"CaveBoulder_%02d" % index,
			data[0],
			data[1],
			float(data[2]),
			cave_material
		)

	var anchor := Node3D.new()
	anchor.name = "OctopusHoverAnchor"
	anchor.position = Vector3(0.0, -9.15, 5.85)
	anchor.add_to_group("octopus_cave_anchor")
	cave.add_child(anchor)

	var glow := OmniLight3D.new()
	glow.name = "CaveGlow"
	glow.position = Vector3(0.0, -8.55, 6.15)
	glow.light_color = Color(0.28, 0.78, 0.92)
	glow.light_energy = 2.15
	glow.omni_range = 10.5
	glow.shadow_enabled = false
	cave.add_child(glow)

	var crystal_material := StandardMaterial3D.new()
	crystal_material.albedo_color = Color(0.20, 0.60, 0.76)
	crystal_material.roughness = 0.28
	crystal_material.emission_enabled = true
	crystal_material.emission = Color(0.10, 0.48, 0.70)
	crystal_material.emission_energy_multiplier = 0.92
	for crystal_data in [
		[Vector3(-2.65, -12.98, 6.35), 1.35, 0.28],
		[Vector3(2.45, -12.82, 6.85), 1.70, 0.34],
		[Vector3(0.55, -13.12, 8.05), 1.10, 0.23],
	]:
		var crystal := MeshInstance3D.new()
		crystal.name = "GlowCrystal"
		var crystal_mesh := CylinderMesh.new()
		crystal_mesh.top_radius = 0.0
		crystal_mesh.bottom_radius = float(crystal_data[2])
		crystal_mesh.height = float(crystal_data[1])
		crystal_mesh.radial_segments = 6
		crystal.mesh = crystal_mesh
		crystal.material_override = crystal_material
		crystal.position = crystal_data[0]
		crystal.rotation_degrees.z = randf_range(-9.0, 9.0)
		cave.add_child(crystal)

	var cave_plant_random := RandomNumberGenerator.new()
	cave_plant_random.seed = 915207
	for plant_data in [
		[1, Vector2(-2.85, 5.65), 1.05],
		[1, Vector2(2.95, 5.95), 0.92],
		[0, Vector2(-3.15, 2.55), 0.84],
		[1, Vector2(1.45, 8.05), 0.78],
	]:
		_spawn_underwater_plant(
			cave,
			int(plant_data[0]),
			plant_data[1],
			BAY_FLOOR_DEPTH,
			float(plant_data[2]),
			cave_plant_random
		)

	_create_octopus_treasure(cave)
	_create_cave_motes(cave)


func _create_cave_collision_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	yaw: float
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation.y = yaw
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _create_cave_lining_mesh(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	yaw: float,
	material: Material
) -> void:
	var lining := MeshInstance3D.new()
	lining.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	lining.mesh = mesh
	lining.position = position
	lining.rotation.y = yaw
	lining.material_override = material
	parent.add_child(lining)


func _create_cave_boulder(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	dimensions: Vector3,
	yaw: float,
	material: Material
) -> void:
	var boulder := MeshInstance3D.new()
	boulder.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 14
	mesh.rings = 8
	boulder.mesh = mesh
	boulder.position = position
	boulder.scale = dimensions
	boulder.rotation.y = yaw
	boulder.material_override = material
	parent.add_child(boulder)


func _create_octopus_treasure(parent: Node3D) -> void:
	var treasure := Node3D.new()
	treasure.name = "OctopusTreasure"
	treasure.position = Vector3(1.25, -13.68, 7.25)
	treasure.rotation_degrees.y = 180.0
	treasure.add_to_group("octopus_treasure")
	parent.add_child(treasure)

	var chest := TREASURE_CHEST_SCENE.instantiate() as Node3D
	chest.name = "ChestWithGold"
	chest.scale = Vector3.ONE * 2.05
	treasure.add_child(chest)
	_prepare_treasure_chest_materials(chest)

	var gold_material := ShaderMaterial.new()
	gold_material.shader = TREASURE_GOLD_SHADER
	var coin_positions := [
		Vector3(-0.92, 0.10, -0.78),
		Vector3(-0.62, 0.10, -0.96),
		Vector3(-0.30, 0.10, -0.83),
		Vector3(0.02, 0.10, -1.04),
		Vector3(0.34, 0.10, -0.88),
		Vector3(0.67, 0.10, -1.03),
		Vector3(0.96, 0.10, -0.77),
		Vector3(-0.73, 0.17, -0.64),
		Vector3(-0.38, 0.18, -0.67),
		Vector3(-0.03, 0.18, -0.71),
		Vector3(0.34, 0.18, -0.66),
		Vector3(0.70, 0.18, -0.65),
		Vector3(-0.48, 0.28, -0.52),
		Vector3(-0.12, 0.28, -0.53),
		Vector3(0.24, 0.28, -0.51),
		Vector3(0.54, 0.28, -0.49),
		Vector3(-0.18, 0.38, -0.39),
		Vector3(0.18, 0.38, -0.38),
	]
	for index in coin_positions.size():
		var coin := MeshInstance3D.new()
		coin.name = "GlowCoin_%02d" % index
		var coin_mesh := CylinderMesh.new()
		coin_mesh.top_radius = 0.17
		coin_mesh.bottom_radius = 0.17
		coin_mesh.height = 0.055
		coin_mesh.radial_segments = 14
		coin.mesh = coin_mesh
		coin.material_override = gold_material
		coin.position = coin_positions[index]
		coin.rotation_degrees.y = float(index * 37 % 180)
		coin.rotation_degrees.x = sin(float(index) * 1.7) * 7.0
		treasure.add_child(coin)

	var treasure_glow := OmniLight3D.new()
	treasure_glow.name = "TreasureGlow"
	treasure_glow.position = Vector3(0.0, 1.0, -0.35)
	treasure_glow.light_color = Color(1.0, 0.49, 0.12)
	treasure_glow.light_energy = 2.65
	treasure_glow.omni_range = 7.2
	treasure_glow.shadow_enabled = false
	treasure.add_child(treasure_glow)

	var pulse_player := AnimationPlayer.new()
	pulse_player.name = "TreasurePulse"
	treasure.add_child(pulse_player)
	var pulse_animation := Animation.new()
	pulse_animation.length = 2.8
	pulse_animation.loop_mode = Animation.LOOP_LINEAR
	var energy_track := pulse_animation.add_track(Animation.TYPE_VALUE)
	pulse_animation.track_set_path(
		energy_track,
		NodePath("TreasureGlow:light_energy")
	)
	pulse_animation.track_insert_key(energy_track, 0.0, 2.30)
	pulse_animation.track_insert_key(energy_track, 1.35, 3.15)
	pulse_animation.track_insert_key(energy_track, 2.8, 2.30)
	pulse_animation.track_set_interpolation_type(
		energy_track,
		Animation.INTERPOLATION_CUBIC
	)
	var pulse_library := AnimationLibrary.new()
	pulse_library.add_animation("golden_pulse", pulse_animation)
	pulse_player.add_animation_library("", pulse_library)
	pulse_player.play("golden_pulse")

	_create_treasure_sparkles(treasure)


func _prepare_treasure_chest_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface_index in mesh_instance.get_surface_override_material_count():
			var source_material := mesh_instance.get_active_material(surface_index)
			if source_material is StandardMaterial3D:
				var material := source_material.duplicate() as StandardMaterial3D
				if "gold" in source_material.resource_name.to_lower():
					material.albedo_color = Color(1.0, 0.49, 0.075)
					material.metallic = 0.86
					material.roughness = 0.24
					material.emission_enabled = true
					material.emission = Color(1.0, 0.25, 0.015)
					material.emission_energy_multiplier = 1.45
				else:
					material.albedo_color = material.albedo_color.lightened(0.10)
					material.roughness = maxf(material.roughness, 0.46)
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in node.get_children():
		_prepare_treasure_chest_materials(child)


func _create_treasure_sparkles(parent: Node3D) -> void:
	var sparkles := GPUParticles3D.new()
	sparkles.name = "TreasureSparkles"
	sparkles.amount = 24
	sparkles.lifetime = 2.4
	sparkles.randomness = 0.82
	sparkles.position = Vector3(0.0, 0.75, -0.42)
	sparkles.visibility_aabb = AABB(
		Vector3(-2.6, -1.0, -2.2),
		Vector3(5.2, 4.7, 4.4)
	)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(1.25, 0.65, 0.82)
	process_material.direction = Vector3.UP
	process_material.spread = 42.0
	process_material.gravity = Vector3(0.0, 0.035, 0.0)
	process_material.initial_velocity_min = 0.12
	process_material.initial_velocity_max = 0.38
	process_material.scale_min = 0.35
	process_material.scale_max = 1.0
	process_material.color = Color(1.0, 0.66, 0.16, 0.92)
	sparkles.process_material = process_material
	var sparkle_mesh := QuadMesh.new()
	sparkle_mesh.size = Vector2(0.085, 0.085)
	var sparkle_material := StandardMaterial3D.new()
	sparkle_material.albedo_color = Color(1.0, 0.72, 0.22, 0.92)
	sparkle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sparkle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sparkle_material.emission_enabled = true
	sparkle_material.emission = Color(1.0, 0.38, 0.04)
	sparkle_material.emission_energy_multiplier = 2.35
	sparkle_mesh.material = sparkle_material
	sparkles.draw_pass_1 = sparkle_mesh
	parent.add_child(sparkles)


func _create_cave_motes(parent: Node3D) -> void:
	var motes := GPUParticles3D.new()
	motes.name = "CaveMotes"
	motes.amount = 46
	motes.lifetime = 5.8
	motes.randomness = 0.78
	motes.position = Vector3(0.0, -9.0, 5.0)
	motes.visibility_aabb = AABB(Vector3(-6.0, -5.0, -6.0), Vector3(12.0, 10.0, 12.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(3.35, 2.7, 3.9)
	process_material.direction = Vector3.UP
	process_material.spread = 65.0
	process_material.gravity = Vector3(0.0, 0.025, 0.0)
	process_material.initial_velocity_min = 0.025
	process_material.initial_velocity_max = 0.11
	process_material.scale_min = 0.45
	process_material.scale_max = 1.30
	process_material.color = Color(0.30, 0.84, 0.93, 0.46)
	motes.process_material = process_material
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.026
	mote_mesh.height = 0.052
	mote_mesh.radial_segments = 6
	mote_mesh.rings = 3
	var mote_material := StandardMaterial3D.new()
	mote_material.albedo_color = Color(0.34, 0.88, 0.96, 0.48)
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.emission_enabled = true
	mote_material.emission = Color(0.18, 0.68, 0.85)
	mote_material.emission_energy_multiplier = 0.78
	mote_mesh.material = mote_material
	motes.draw_pass_1 = mote_mesh
	parent.add_child(motes)


func _build_underwater_plants(parent: Node3D, random: RandomNumberGenerator) -> void:
	var plants_root := Node3D.new()
	plants_root.name = "UnderwaterPlantGardens"
	parent.add_child(plants_root)

	var floor_clusters := [
		Vector2(-8.0, -7.0),
		Vector2(18.0, 15.0),
		Vector2(-18.0, 22.0),
		Vector2(30.0, -13.0),
		Vector2(-35.0, -28.0),
		Vector2(7.0, 34.0),
	]
	var plant_index := 0
	for cluster_index in floor_clusters.size():
		var center: Vector2 = floor_clusters[cluster_index]
		for local_index in 4:
			var angle := random.randf_range(0.0, TAU)
			var radius := random.randf_range(1.4, 5.8)
			var plant_position := center + Vector2(cos(angle), sin(angle)) * radius
			var plant_kind := posmod(plant_index + cluster_index, 2)
			var plant_scale := (
				random.randf_range(1.35, 2.10)
				if plant_kind == 0
				else random.randf_range(1.80, 3.00)
			)
			_spawn_underwater_plant(
				plants_root,
				plant_kind,
				plant_position,
				BAY_FLOOR_DEPTH + 0.06,
				plant_scale,
				random
			)
			plant_index += 1

	var shelf_clusters := [
		[Vector2(-25.0, -15.0), -8.35],
		[Vector2(32.0, 10.0), -9.25],
		[Vector2(-29.0, 27.0), -9.85],
	]
	for cluster_index in shelf_clusters.size():
		var cluster: Array = shelf_clusters[cluster_index]
		var center: Vector2 = cluster[0]
		var base_height: float = cluster[1]
		for local_index in 5:
			var angle := random.randf_range(0.0, TAU)
			var radius := random.randf_range(1.2, 4.6)
			var plant_position := center + Vector2(cos(angle), sin(angle)) * radius
			var plant_kind := posmod(plant_index + local_index, 2)
			var plant_scale := (
				random.randf_range(0.82, 1.30)
				if plant_kind == 0
				else random.randf_range(1.25, 2.10)
			)
			_spawn_underwater_plant(
				plants_root,
				plant_kind,
				plant_position,
				base_height,
				plant_scale,
				random
			)
			plant_index += 1


func _spawn_underwater_plant(
	parent: Node3D,
	plant_kind: int,
	horizontal_position: Vector2,
	base_height: float,
	plant_scale: float,
	random: RandomNumberGenerator
) -> void:
	var plant_scene := KELP_SCENE if plant_kind == 0 else SEAWEED_SCENE
	var plant := plant_scene.instantiate() as Node3D
	var base_offset := 1.115 if plant_kind == 0 else 0.340
	plant.name = "%s_%02d" % [
		"Kelp" if plant_kind == 0 else "Seaweed",
		get_tree().get_node_count_in_group("underwater_plant"),
	]
	plant.position = Vector3(
		horizontal_position.x,
		base_height + base_offset * plant_scale,
		horizontal_position.y
	)
	plant.rotation.y = random.randf_range(0.0, TAU)
	plant.scale = Vector3.ONE * plant_scale
	parent.add_child(plant)
	plant.add_to_group("underwater_plant")

	var cold_tint := (
		Color(
			random.randf_range(0.06, 0.11),
			random.randf_range(0.48, 0.61),
			random.randf_range(0.38, 0.52)
		)
		if plant_kind == 0
		else Color(
			random.randf_range(0.08, 0.16),
			random.randf_range(0.54, 0.69),
			random.randf_range(0.43, 0.58)
		)
	)
	_prepare_plant_meshes(
		plant,
		plant_kind,
		random.randf_range(0.0, TAU),
		random.randf_range(0.075, 0.14),
		cold_tint,
		1.0 if plant_kind == 0 else 0.72
	)


func _prepare_plant_meshes(
	node: Node,
	plant_kind: int,
	sway_phase: float,
	sway_strength: float,
	plant_tint: Color,
	reaction_flex: float
) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var source_material: Material = mesh_instance.get_active_material(surface_index)
				mesh_instance.set_surface_override_material(
					surface_index,
					_get_plant_material(source_material, plant_kind, surface_index)
				)
		mesh_instance.set_instance_shader_parameter("sway_phase", sway_phase)
		mesh_instance.set_instance_shader_parameter("sway_strength", sway_strength)
		mesh_instance.set_instance_shader_parameter("plant_tint", plant_tint)
		mesh_instance.set_instance_shader_parameter("reaction_flex", reaction_flex)
	for child in node.get_children():
		_prepare_plant_meshes(
			child,
			plant_kind,
			sway_phase,
			sway_strength,
			plant_tint,
			reaction_flex
		)


func _get_plant_material(
	source_material: Material,
	plant_kind: int,
	surface_index: int
) -> ShaderMaterial:
	var source_name := (
		source_material.resource_name
		if is_instance_valid(source_material) and not source_material.resource_name.is_empty()
		else "surface"
	)
	var cache_key := "%d:%s:%d" % [plant_kind, source_name, surface_index]
	if _plant_material_cache.has(cache_key):
		return _plant_material_cache[cache_key] as ShaderMaterial

	var shader_material := ShaderMaterial.new()
	shader_material.shader = UNDERWATER_PLANT_SHADER
	var base_color := Color(0.16, 0.57, 0.36)
	var albedo_texture: Texture2D
	if source_material is StandardMaterial3D:
		var standard_material := source_material as StandardMaterial3D
		base_color = standard_material.albedo_color
		albedo_texture = standard_material.albedo_texture
	shader_material.set_shader_parameter("base_color", base_color)
	shader_material.set_shader_parameter("has_albedo_texture", is_instance_valid(albedo_texture))
	if is_instance_valid(albedo_texture):
		shader_material.set_shader_parameter("albedo_texture", albedo_texture)
	shader_material.set_shader_parameter("blade_base", -1.115 if plant_kind == 0 else -0.340)
	shader_material.set_shader_parameter("blade_height", 2.30 if plant_kind == 0 else 0.82)
	shader_material.set_shader_parameter("tint_amount", 0.16 if plant_kind == 0 else 0.22)
	shader_material.set_shader_parameter("interaction_radius", 4.6)
	shader_material.set_shader_parameter("wake_length", 5.4)
	_plant_material_cache[cache_key] = shader_material
	return shader_material


func _update_underwater_plant_interaction(delta: float) -> void:
	if not is_instance_valid(_flaki) or _plant_material_cache.is_empty():
		return
	var target_position := _flaki.global_position
	var target_velocity := _flaki.velocity
	var target_activity := (
		1.0
		if _flaki.is_swimming() and _flaki.global_position.y < WATER_LEVEL + 0.25
		else 0.0
	)
	if not _plant_interaction_initialized:
		_plant_interaction_position = target_position
		_plant_interaction_velocity = target_velocity
		_plant_interaction_activity = target_activity
		_plant_interaction_initialized = true
	else:
		var position_weight := 1.0 - exp(-delta * 13.0)
		var velocity_weight := 1.0 - exp(-delta * 7.5)
		_plant_interaction_position = _plant_interaction_position.lerp(
			target_position,
			position_weight
		)
		_plant_interaction_velocity = _plant_interaction_velocity.lerp(
			target_velocity,
			velocity_weight
		)
		_plant_interaction_activity = move_toward(
			_plant_interaction_activity,
			target_activity,
			delta * (4.8 if target_activity > 0.0 else 2.5)
		)
	for cached_material in _plant_material_cache.values():
		var material := cached_material as ShaderMaterial
		if not is_instance_valid(material):
			continue
		material.set_shader_parameter(
			"swimmer_position",
			_plant_interaction_position
		)
		material.set_shader_parameter(
			"swimmer_velocity",
			_plant_interaction_velocity
		)
		material.set_shader_parameter(
			"swimmer_activity",
			_plant_interaction_activity
		)


func _create_water_surface(parent: Node3D) -> void:
	var surface := MeshInstance3D.new()
	surface.name = "WaterSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(BAY_RADIUS * 2.05, BAY_RADIUS * 2.05)
	plane.subdivide_width = 208
	plane.subdivide_depth = 208
	surface.mesh = plane
	surface.position.y = WATER_LEVEL
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER
	_water_material.set_shader_parameter("sun_direction", _sun_direction)
	surface.material_override = _water_material
	parent.add_child(surface)


func _create_cliff_segment(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	yaw: float,
	random: RandomNumberGenerator,
	rock_material: Material,
	snow_material: Material
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation.y = yaw
	parent.add_child(body)

	var collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(16.5, 23.0, 9.0)
	collision.shape = wall_shape
	collision.position.y = 11.5
	body.add_child(collision)

	for spire_index in 3:
		var spire_height := random.randf_range(17.0, 25.0)
		var spire_radius := random.randf_range(3.8, 6.7)
		var spire := MeshInstance3D.new()
		spire.name = "RockSpire_%d" % spire_index
		var spire_mesh := CylinderMesh.new()
		spire_mesh.top_radius = spire_radius * random.randf_range(0.46, 0.72)
		spire_mesh.bottom_radius = spire_radius
		spire_mesh.height = spire_height
		spire_mesh.radial_segments = random.randi_range(6, 9)
		spire.mesh = spire_mesh
		spire.material_override = rock_material
		spire.position = Vector3(
			-5.2 + float(spire_index) * 5.2 + random.randf_range(-1.0, 1.0),
			spire_height * 0.5,
			random.randf_range(-1.8, 1.6)
		)
		spire.rotation_degrees.z = random.randf_range(-4.0, 4.0)
		body.add_child(spire)

		var snow_cap := MeshInstance3D.new()
		snow_cap.name = "SnowCap_%d" % spire_index
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = spire_mesh.top_radius * 1.02
		cap_mesh.bottom_radius = spire_mesh.top_radius * 1.12
		cap_mesh.height = 0.42
		cap_mesh.radial_segments = spire_mesh.radial_segments
		snow_cap.mesh = cap_mesh
		snow_cap.material_override = snow_material
		snow_cap.position = spire.position + Vector3(0.0, spire_height * 0.5 + 0.12, 0.0)
		snow_cap.rotation = spire.rotation
		body.add_child(snow_cap)


func _create_rock_pillar(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	radius: float,
	height: float,
	material: Material
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees = Vector3(
		randf_range(-5.0, 5.0),
		randf_range(0.0, 180.0),
		randf_range(-5.0, 5.0)
	)
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.88
	shape.height = height
	collision.shape = shape
	body.add_child(collision)


func _create_ice_floe(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	radius: float,
	height: float,
	top_material: Material,
	side_material: Material,
	climb_angle: float,
	style_index: int
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation.y = randf_range(-0.35, 0.35)
	parent.add_child(body)

	var outline := _make_floe_outline(radius, style_index)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "IrregularIceBody"
	mesh_instance.mesh = _make_irregular_floe_mesh(
		outline,
		height,
		top_material,
		side_material
	)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.92
	shape.height = height
	collision.shape = shape
	body.add_child(collision)

	for exit_index in 4:
		var exit_zone := IceExitZone.new()
		body.add_child(exit_zone)
		exit_zone.configure(
			radius,
			height,
			climb_angle + float(exit_index) * TAU / 4.0,
			WATER_LEVEL
		)
		exit_zone.name = "ClimbZone_%02d" % exit_index


func _make_floe_outline(radius: float, style_index: int) -> Array[Vector2]:
	var outline: Array[Vector2] = []
	var random := RandomNumberGenerator.new()
	random.seed = 80421 + style_index * 9173
	var point_count := 24
	var phase := float(style_index) * 0.83 + 0.27
	for point_index in point_count:
		var angle := TAU * float(point_index) / float(point_count)
		var irregularity := (
			1.0
			+ sin(angle * 3.0 + phase) * 0.055
			+ sin(angle * 5.0 - phase * 1.4) * 0.035
			+ random.randf_range(-0.022, 0.022)
		)
		var point_radius := radius * irregularity
		outline.append(
			Vector2(cos(angle), sin(angle)) * point_radius
		)
	return outline


func _make_irregular_floe_mesh(
	outline: Array[Vector2],
	height: float,
	top_material: Material,
	side_material: Material
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var top_y := height * 0.5 + 0.055
	var bottom_y := -height * 0.5

	var top_surface := SurfaceTool.new()
	top_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in outline.size():
		var current := outline[index]
		var next := outline[(index + 1) % outline.size()]
		for vertex_data in [
			[Vector3.ZERO + Vector3.UP * top_y, Vector2(0.5, 0.5)],
			[
				Vector3(current.x, top_y, current.y),
				Vector2(0.5 + current.x * 0.055, 0.5 + current.y * 0.055),
			],
			[
				Vector3(next.x, top_y, next.y),
				Vector2(0.5 + next.x * 0.055, 0.5 + next.y * 0.055),
			],
		]:
			top_surface.set_normal(Vector3.UP)
			top_surface.set_uv(vertex_data[1])
			top_surface.add_vertex(vertex_data[0])
	top_surface.commit(mesh)
	mesh.surface_set_material(0, top_material)

	var side_surface := SurfaceTool.new()
	side_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in outline.size():
		var current := outline[index]
		var next := outline[(index + 1) % outline.size()]
		var current_bottom := current * 0.83
		var next_bottom := next * 0.83
		var top_current := Vector3(current.x, top_y, current.y)
		var top_next := Vector3(next.x, top_y, next.y)
		var bottom_current := Vector3(current_bottom.x, bottom_y, current_bottom.y)
		var bottom_next := Vector3(next_bottom.x, bottom_y, next_bottom.y)
		for vertex in [
			top_current,
			top_next,
			bottom_current,
			top_next,
			bottom_next,
			bottom_current,
		]:
			side_surface.add_vertex(vertex)
		for bottom_vertex in [
			Vector3(0.0, bottom_y, 0.0),
			bottom_next,
			bottom_current,
		]:
			side_surface.add_vertex(bottom_vertex)
	side_surface.generate_normals()
	side_surface.commit(mesh)
	mesh.surface_set_material(1, side_material)
	return mesh


func _create_cylinder_body(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	radius: float,
	height: float,
	material: Material
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)


func _create_box_body(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	yaw: float
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation.y = yaw
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _spawn_flaki() -> void:
	_flaki = FLAKI_SCENE.instantiate() as FlakiController
	_flaki.name = "Flaki"
	_flaki.water_level = WATER_LEVEL
	_flaki.minimum_depth = BAY_FLOOR_DEPTH + 0.8
	add_child(_flaki)
	var starting_ice_zone := _find_starting_ice_zone()
	if is_instance_valid(starting_ice_zone):
		_flaki.begin_on_ice(
			starting_ice_zone.get_landing_position(),
			starting_ice_zone
		)
		var direction_to_bay := -_flaki.global_position
		direction_to_bay.y = 0.0
		if direction_to_bay.length_squared() > 0.01:
			direction_to_bay = direction_to_bay.normalized()
			_flaki.rotation.y = atan2(
				-direction_to_bay.x,
				-direction_to_bay.z
			)
	else:
		_flaki.global_position = Vector3(0.0, -0.48, 12.0)

	_camera_rig = CAMERA_RIG_SCENE.instantiate() as FlakiCameraRig
	_camera_rig.name = "CameraRig"
	_camera_rig.target = _flaki
	add_child(_camera_rig)
	_camera_rig.global_position = _flaki.global_position + Vector3.UP * 0.45
	_camera_rig.configure_menu_cinematic(_build_menu_camera_shots())


func _find_starting_ice_zone() -> IceExitZone:
	var fallback_zone := (
		get_tree().get_first_node_in_group("ice_exit_zone") as IceExitZone
	)
	for zone_node in get_tree().get_nodes_in_group("ice_exit_zone"):
		var zone := zone_node as IceExitZone
		if (
			is_instance_valid(zone)
			and is_instance_valid(zone.get_parent())
			and zone.get_parent().name == "IceFloe_00"
			and zone.name == "ClimbZone_00"
		):
			return zone
	return fallback_zone


func _build_menu_camera_shots() -> Array[Dictionary]:
	var subject_position := _flaki.global_position
	return [
		{
			"focus": _menu_subject_focus(subject_position, 150.0, 1.85),
			"yaw": 150.0,
			"pitch": -9.0,
			"distance": 8.2,
			"fov": 58.0,
		},
		{
			"focus": Vector3(-3.0, 1.45, 2.0),
			"yaw": 30.0,
			"pitch": -27.0,
			"distance": 29.0,
			"fov": 68.0,
		},
		{
			"focus": Vector3(11.0, 1.15, -12.0),
			"yaw": -55.0,
			"pitch": -17.0,
			"distance": 20.0,
			"fov": 64.0,
		},
		{
			"focus": _menu_subject_focus(subject_position, 215.0, 1.55),
			"yaw": 215.0,
			"pitch": -6.0,
			"distance": 7.4,
			"fov": 56.0,
		},
	]


func _menu_subject_focus(
	subject_position: Vector3,
	yaw_degrees: float,
	screen_right_offset: float
) -> Vector3:
	var yaw_radians := deg_to_rad(yaw_degrees)
	var camera_right := Vector3(cos(yaw_radians), 0.0, -sin(yaw_radians))
	return (
		subject_position
		- camera_right * screen_right_offset
		+ Vector3.UP * 0.34
	)


func _build_water_environment_controller() -> void:
	var water_controller := WaterEnvironmentController.new()
	water_controller.name = "WaterEnvironmentController"
	add_child(water_controller)
	water_controller.configure(_environment, WATER_LEVEL)


func _build_flaki_water_effects() -> void:
	_water_effects = FlakiWaterEffects.new()
	_water_effects.name = "FlakiWaterEffects"
	add_child(_water_effects)
	_water_effects.configure(_flaki, WATER_LEVEL, _water_material)


func _build_fish() -> void:
	_fish_manager = FishManager.new()
	_fish_manager.name = "FishManager"
	add_child(_fish_manager)
	_fish_manager.fish_count_changed.connect(_on_fish_count_changed)
	_fish_manager.catch_prompt_changed.connect(_on_catch_prompt_changed)
	_fish_manager.objective_completed.connect(_on_fish_objective_completed)
	_fish_manager.configure(_flaki)
	_on_fish_count_changed(0, FishManager.TARGET_FISH)


func _build_ambient_life() -> void:
	var ambient_root := Node3D.new()
	ambient_root.name = "AmbientSeaLife"
	add_child(ambient_root)

	var school_data := [
		[Vector3(-6.0, -6.7, -34.0), 81631, Color(0.34, 0.78, 0.88)],
		[Vector3(20.0, -5.0, 19.0), 27419, Color(0.56, 0.81, 0.72)],
		[Vector3(-12.0, -9.0, 18.0), 63047, Color(0.43, 0.67, 0.86)],
		[Vector3(28.0, -7.2, -15.0), 49211, Color(0.67, 0.75, 0.62)],
	]
	for index in school_data.size():
		var data: Array = school_data[index]
		var school := AmbientFishSchool.new()
		school.name = "DecorativeFishSchool_%02d" % index
		ambient_root.add_child(school)
		school.add_to_group("ambient_fish_school")
		school.configure(data[0], data[1], 13, data[2])

	var crab_routes := [
		[
			Vector3(-44.0, BAY_FLOOR_DEPTH + 0.72, -38.0),
			Vector3(-21.0, BAY_FLOOR_DEPTH + 0.72, -49.0),
			Vector3(7.0, BAY_FLOOR_DEPTH + 0.72, -48.0),
			Vector3(30.0, BAY_FLOOR_DEPTH + 0.72, -38.0),
			Vector3(45.0, BAY_FLOOR_DEPTH + 0.72, -19.0),
			Vector3(50.0, BAY_FLOOR_DEPTH + 0.72, 4.0),
		],
		[
			Vector3(-49.0, BAY_FLOOR_DEPTH + 0.72, 8.0),
			Vector3(-44.0, BAY_FLOOR_DEPTH + 0.72, 27.0),
			Vector3(-28.0, BAY_FLOOR_DEPTH + 0.72, 44.0),
			Vector3(-4.0, BAY_FLOOR_DEPTH + 0.72, 50.0),
			Vector3(20.0, BAY_FLOOR_DEPTH + 0.72, 46.0),
			Vector3(10.0, BAY_FLOOR_DEPTH + 0.72, 56.0),
			Vector3(-18.0, BAY_FLOOR_DEPTH + 0.72, 53.0),
		],
	]
	for index in crab_routes.size():
		var crab := AmbientCrab.new()
		crab.name = "WanderingCrab_%02d" % index
		ambient_root.add_child(crab)
		crab.add_to_group("ambient_crab")
		crab.configure(
			crab_routes[index],
			0.54 + float(index) * 0.06,
			_flaki
		)
		crab.dance_started.connect(_on_crab_danced_for_achievement)
		_flaki.voice_played.connect(crab.on_flaki_voice)

	var octopus := AmbientOctopus.new()
	octopus.name = "ChillingOctopus"
	ambient_root.add_child(octopus)
	octopus.add_to_group("ambient_octopus")
	var cave_anchor := (
		get_tree().get_first_node_in_group("octopus_cave_anchor") as Node3D
	)
	var cave_root := (
		get_tree().get_first_node_in_group("octopus_cave") as Node3D
	)
	octopus.configure(
		cave_anchor.global_position
			if is_instance_valid(cave_anchor)
			else Vector3(48.0, -9.15, 30.0),
		cave_root.global_rotation.y + PI
			if is_instance_valid(cave_root)
			else deg_to_rad(238.0),
		true,
		_flaki
	)


func _build_ice_interactions() -> void:
	_ice_manager = IceInteractionManager.new()
	_ice_manager.name = "IceInteractionManager"
	add_child(_ice_manager)
	_ice_manager.prompt_changed.connect(_on_ice_prompt_changed)
	_ice_manager.configure(_flaki)


func _build_shark() -> void:
	_shark_manager = SharkManager.new()
	_shark_manager.name = "SharkManager"
	add_child(_shark_manager)
	_shark_manager.hearts_changed.connect(_on_hearts_changed)
	_shark_manager.alert_changed.connect(_on_shark_alert_changed)
	_shark_manager.player_bitten.connect(_on_player_bitten)
	_shark_manager.soft_respawned.connect(_on_soft_respawned)
	_shark_manager.configure(_flaki)
	_on_hearts_changed(SharkManager.MAX_HEARTS, SharkManager.MAX_HEARTS)


func _build_game_menus() -> void:
	_game_menus = GameMenusController.new()
	_game_menus.name = "GameMenus"
	add_child(_game_menus)
	var arguments := OS.get_cmdline_user_args()
	var capture_main_menu := "--capture-main-menu-preview" in arguments
	var capture_credits := "--capture-credits-preview" in arguments
	var capture_settings := "--capture-settings-preview" in arguments
	var capture_achievements := "--capture-achievements-preview" in arguments
	var capture_achievement_unlocked := (
		"--capture-achievement-unlocked-preview" in arguments
	)
	var auto_start := bool(get_tree().get_meta("flaki_auto_start", false))
	if get_tree().has_meta("flaki_auto_start"):
		get_tree().remove_meta("flaki_auto_start")
	var show_main_menu := (
		arguments.is_empty()
		or capture_main_menu
		or capture_credits
		or capture_settings
		or capture_achievements
		or capture_achievement_unlocked
	) and not auto_start
	_game_menus.configure(show_main_menu, _achievement_manager)
	_gameplay_started = not show_main_menu
	if show_main_menu:
		_flaki.set_menu_idle_active(true)
		_camera_rig.set_menu_cinematic(true)
	if (
		capture_main_menu
		or capture_credits
		or capture_settings
		or capture_achievements
		or capture_achievement_unlocked
	):
		get_tree().paused = false
	_game_menus.game_started.connect(_on_game_started)
	_game_menus.free_roam_requested.connect(_on_free_roam_requested)
	if show_main_menu and is_instance_valid(_hud_canvas):
		_hud_canvas.visible = false


func _build_music() -> void:
	_music_manager = BayMusicManager.new()
	_music_manager.name = "BayMusicManager"
	add_child(_music_manager)
	_music_manager.configure(WATER_LEVEL)
	_game_menus.pause_changed.connect(_music_manager.set_pause_active)
	_game_menus.pause_changed.connect(_on_pause_changed)
	_game_menus.main_menu_changed.connect(_music_manager.set_menu_active)
	_music_manager.set_menu_active(_game_menus.is_main_menu_visible())


func _build_demo_flow() -> void:
	_demo_flow = DemoFlowManager.new()
	_demo_flow.name = "DemoFlowManager"
	add_child(_demo_flow)
	_demo_flow.victory_pose_started.connect(_on_victory_pose_started)
	_demo_flow.victory_ready.connect(_on_victory_ready)
	_demo_flow.configure(_flaki, _shark_manager, _camera_rig)


func _build_hud() -> void:
	var danger_layer := CanvasLayer.new()
	danger_layer.name = "DangerOverlay"
	danger_layer.layer = 9
	add_child(danger_layer)
	_danger_overlay = ColorRect.new()
	_danger_overlay.name = "DangerTint"
	_danger_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_overlay.color = Color(0.55, 0.02, 0.025, 0.0)
	danger_layer.add_child(_danger_overlay)

	_hud_canvas = CanvasLayer.new()
	_hud_canvas.name = "PrototypeHUD"
	_hud_canvas.layer = 10
	add_child(_hud_canvas)
	var canvas := _hud_canvas

	var title := Label.new()
	title.text = "HUD_TITLE"
	title.position = Vector2(28.0, 22.0)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.87, 0.97, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.12, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(title)

	var controls_panel := PanelContainer.new()
	controls_panel.position = Vector2(28.0, 100.0)
	controls_panel.custom_minimum_size = Vector2(264.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.10, 0.15, 0.78)
	panel_style.border_color = Color(0.48, 0.77, 0.84, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(14.0)
	controls_panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(controls_panel)

	_controls_label = Label.new()
	_controls_label.text = "HUD_CONTROLS"
	_controls_label.add_theme_font_size_override("font_size", 17)
	_controls_label.add_theme_color_override("font_color", Color(0.82, 0.93, 0.96))
	controls_panel.add_child(_controls_label)

	_hearts_label = Label.new()
	_hearts_label.text = "♥  ♥  ♥"
	_hearts_label.position = Vector2(30.0, 62.0)
	_hearts_label.size = Vector2(220.0, 34.0)
	_hearts_label.add_theme_font_size_override("font_size", 26)
	_hearts_label.add_theme_color_override("font_color", Color(0.96, 0.24, 0.30))
	_hearts_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.01, 0.02, 0.9))
	_hearts_label.add_theme_constant_override("shadow_offset_x", 2)
	_hearts_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_hearts_label)

	_state_label = Label.new()
	_state_label.text = "STATE_SURFACE"
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.position = Vector2(430.0, 650.0)
	_state_label.size = Vector2(420.0, 32.0)
	_state_label.add_theme_font_size_override("font_size", 20)
	_state_label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
	canvas.add_child(_state_label)

	_catch_prompt_label = Label.new()
	_catch_prompt_label.text = ""
	_catch_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_catch_prompt_label.position = Vector2(390.0, 598.0)
	_catch_prompt_label.size = Vector2(500.0, 38.0)
	_catch_prompt_label.add_theme_font_size_override("font_size", 24)
	_catch_prompt_label.add_theme_color_override("font_color", Color(0.92, 0.99, 0.72))
	_catch_prompt_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.02, 0.08, 0.10, 0.9)
	)
	_catch_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_catch_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_catch_prompt_label)

	_objective_label = Label.new()
	_objective_label.text = "HUD_OBJECTIVE"
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.position = Vector2(430.0, 27.0)
	_objective_label.size = Vector2(420.0, 30.0)
	_objective_label.add_theme_font_size_override("font_size", 19)
	_objective_label.add_theme_color_override("font_color", Color(0.84, 0.96, 0.98))
	canvas.add_child(_objective_label)

	_shark_alert_panel = PanelContainer.new()
	_shark_alert_panel.name = "SharkAlertPanel"
	_shark_alert_panel.position = Vector2(350.0, 108.0)
	_shark_alert_panel.custom_minimum_size = Vector2(580.0, 58.0)
	var alert_style := StyleBoxFlat.new()
	alert_style.bg_color = Color(0.20, 0.025, 0.035, 0.90)
	alert_style.border_color = Color(1.0, 0.34, 0.30, 0.92)
	alert_style.set_border_width_all(2)
	alert_style.set_corner_radius_all(12)
	alert_style.set_content_margin_all(10.0)
	_shark_alert_panel.add_theme_stylebox_override("panel", alert_style)
	canvas.add_child(_shark_alert_panel)

	_shark_alert_label = Label.new()
	_shark_alert_label.text = "SHARK_HIDE"
	_shark_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shark_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shark_alert_label.add_theme_font_size_override("font_size", 27)
	_shark_alert_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.70))
	_shark_alert_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.05, 0.0, 0.0, 0.95)
	)
	_shark_alert_label.add_theme_constant_override("shadow_offset_x", 2)
	_shark_alert_label.add_theme_constant_override("shadow_offset_y", 2)
	_shark_alert_panel.add_child(_shark_alert_label)
	_shark_alert_panel.visible = false

	_fish_label = Label.new()
	_fish_label.text = tr("HUD_FISH_COUNT") % [0, FishManager.TARGET_FISH]
	_fish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fish_label.position = Vector2(1012.0, 24.0)
	_fish_label.size = Vector2(235.0, 30.0)
	_fish_label.add_theme_font_size_override("font_size", 22)
	_fish_label.add_theme_color_override("font_color", Color(0.94, 0.99, 0.76))
	canvas.add_child(_fish_label)

	_depth_label = Label.new()
	_depth_label.text = tr("HUD_DEPTH") % 0.0
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_depth_label.position = Vector2(1012.0, 57.0)
	_depth_label.size = Vector2(235.0, 30.0)
	_depth_label.add_theme_font_size_override("font_size", 17)
	_depth_label.add_theme_color_override("font_color", Color(0.83, 0.95, 1.0))
	canvas.add_child(_depth_label)

	_flaki.state_changed.connect(_on_flaki_state_changed)
	if not Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.connect(_on_language_changed)


func _on_flaki_state_changed(title_key: String) -> void:
	if is_instance_valid(_state_label):
		_state_label.text = title_key
	if title_key in [
		"STATE_RESTING",
		"STATE_SAVED",
		"STATE_VICTORY",
	]:
		_clear_safety_prompt()


func _on_fish_count_changed(current: int, target: int) -> void:
	_caught_fish = current
	_fish_target = target
	if is_instance_valid(_fish_label):
		_fish_label.text = tr("HUD_FISH_COUNT") % [current, target]
	if is_instance_valid(_shark_manager):
		_shark_manager.notify_fish_count(current)
	if (
		current >= target
		and target > 0
		and is_instance_valid(_achievement_manager)
	):
		_achievement_manager.unlock("fish_day")


func _on_breach_landed_for_achievement(
	_position: Vector3,
	_impact_speed: float
) -> void:
	if _gameplay_started and is_instance_valid(_achievement_manager):
		_achievement_manager.unlock("flying_seal")


func _on_flaki_voice_for_achievement(_voice_position: Vector3) -> void:
	if (
		not _gameplay_started
		or (
			is_instance_valid(_game_menus)
			and _game_menus.is_victory_visible()
		)
	):
		return
	_voice_uses_this_run += 1
	if _voice_uses_this_run >= 5 and is_instance_valid(_achievement_manager):
		_achievement_manager.unlock("vocalist")


func _on_crab_danced_for_achievement() -> void:
	if _gameplay_started and is_instance_valid(_achievement_manager):
		_achievement_manager.unlock("crab_dance")


func _on_catch_prompt_changed(text: String) -> void:
	_fish_prompt_text = text
	_refresh_context_prompt()


func _on_ice_prompt_changed(text: String) -> void:
	_ice_prompt_text = text
	_refresh_context_prompt()


func _refresh_context_prompt() -> void:
	if not is_instance_valid(_catch_prompt_label):
		return
	var prompt_key := (
		_ice_prompt_text
		if not _ice_prompt_text.is_empty()
		else _fish_prompt_text
	)
	_catch_prompt_label.text = prompt_key


func _on_fish_objective_completed() -> void:
	if is_instance_valid(_objective_label):
		_objective_label.text = "HUD_OBJECTIVE_COMPLETE"
		_objective_label.add_theme_color_override("font_color", Color(0.98, 0.91, 0.48))
	_fish_prompt_text = "PROMPT_ALL_FISH"
	_refresh_context_prompt()
	if is_instance_valid(_music_manager):
		_music_manager.set_victory_active()
	if is_instance_valid(_demo_flow):
		_game_menus.begin_cinematic()
		_demo_flow.start_victory()


func _on_hearts_changed(current: int, maximum: int) -> void:
	if not is_instance_valid(_hearts_label):
		return
	var hearts_text := ""
	for index in maximum:
		hearts_text += "♥" if index < current else "♡"
		if index < maximum - 1:
			hearts_text += "  "
	_hearts_label.text = hearts_text


func _on_shark_alert_changed(text_key: String, active: bool) -> void:
	_shark_alert_text = text_key
	_danger_active = active
	if is_instance_valid(_music_manager):
		_music_manager.set_danger_active(active)
	if is_instance_valid(_shark_alert_panel) and is_instance_valid(_shark_alert_label):
		_shark_alert_label.text = text_key
		_shark_alert_panel.visible = active
		_shark_alert_panel.modulate.a = 1.0


func _on_player_bitten() -> void:
	_was_bitten_this_run = true
	_damage_flash_time = 0.42
	_safety_prompt_time = 3.2
	_fish_prompt_text = "PROMPT_BITTEN"
	_refresh_context_prompt()


func _on_soft_respawned() -> void:
	_damage_flash_time = 0.54
	_safety_prompt_time = 2.6
	_fish_prompt_text = "PROMPT_RESPAWNED"
	_refresh_context_prompt()


func _clear_safety_prompt() -> void:
	if _fish_prompt_text in ["PROMPT_BITTEN", "PROMPT_RESPAWNED"]:
		_fish_prompt_text = ""
		_refresh_context_prompt()
	_safety_prompt_time = 0.0


func _on_victory_ready() -> void:
	_victory_finished = true
	_danger_active = false
	_ice_prompt_text = ""
	_fish_prompt_text = ""
	_refresh_context_prompt()
	_game_menus.show_victory()
	if not _was_bitten_this_run and is_instance_valid(_achievement_manager):
		_achievement_manager.unlock("untouchable")


func _on_victory_pose_started() -> void:
	_danger_active = false
	if is_instance_valid(_shark_alert_panel):
		_shark_alert_panel.visible = false
	if is_instance_valid(_hud_canvas):
		_hud_canvas.visible = false


func _on_game_started() -> void:
	_gameplay_started = true
	_was_bitten_this_run = false
	_voice_uses_this_run = 0
	_ice_rest_time = 0.0
	_flaki.set_menu_idle_active(false)
	_camera_rig.set_menu_cinematic(false)
	if is_instance_valid(_hud_canvas):
		_hud_canvas.visible = true


func _on_pause_changed(paused: bool) -> void:
	if not is_instance_valid(_hud_canvas):
		return
	if paused:
		_hud_canvas.visible = false
		return
	_hud_canvas.visible = (
		not _game_menus.is_victory_visible()
		and not _game_menus.is_main_menu_visible()
	)


func _on_free_roam_requested() -> void:
	_free_roam_active = true
	if is_instance_valid(_achievement_manager):
		_achievement_manager.unlock("free_swimmer")
	_danger_active = false
	_damage_flash_time = 0.0
	_safety_prompt_time = 0.0
	_shark_alert_text = ""
	if is_instance_valid(_shark_alert_panel):
		_shark_alert_panel.visible = false
	if is_instance_valid(_demo_flow):
		_demo_flow.enter_free_roam()
	if is_instance_valid(_fish_manager):
		_fish_manager.enter_free_roam()
	if is_instance_valid(_music_manager):
		_music_manager.set_free_roam_active()
	_fish_prompt_text = ""
	_ice_prompt_text = "PROMPT_RETURN_WATER" if _flaki.is_on_ice() else ""
	if is_instance_valid(_hud_canvas):
		_hud_canvas.visible = true
	if is_instance_valid(_hearts_label):
		_hearts_label.visible = false
	if is_instance_valid(_fish_label):
		_fish_label.visible = false
	if is_instance_valid(_controls_label):
		_controls_label.text = "HUD_CONTROLS_FREE"
	if is_instance_valid(_objective_label):
		_objective_label.text = "HUD_FREE_ROAM"
		_objective_label.add_theme_color_override("font_color", Color(0.66, 0.95, 0.88))
	_refresh_context_prompt()


func _on_language_changed(_language_code: String) -> void:
	if is_instance_valid(_fish_label) and not _free_roam_active:
		_fish_label.text = tr("HUD_FISH_COUNT") % [_caught_fish, _fish_target]
	if _free_roam_active:
		if is_instance_valid(_controls_label):
			_controls_label.text = "HUD_CONTROLS_FREE"
		if is_instance_valid(_objective_label):
			_objective_label.text = "HUD_FREE_ROAM"
	if is_instance_valid(_shark_alert_label) and not _shark_alert_text.is_empty():
		_shark_alert_label.text = _shark_alert_text
	_refresh_context_prompt()


func _underwater_material(
	color: Color,
	roughness: float,
	caustic_strength: float,
	texture_strength: float = 0.70
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = UNDERWATER_GROUND_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("caustic_strength", caustic_strength)
	material.set_shader_parameter("seabed_diffuse", SEABED_DIFFUSE)
	material.set_shader_parameter("seabed_roughness", SEABED_ROUGHNESS)
	material.set_shader_parameter("seabed_displacement", SEABED_DISPLACEMENT)
	material.set_shader_parameter("texture_strength", texture_strength)
	return material


func _snow_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.91, 0.97, 1.0)
	material.albedo_texture = SNOW_DIFFUSE
	material.roughness = 0.86
	material.roughness_texture = SNOW_ROUGHNESS
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.normal_enabled = true
	material.normal_texture = SNOW_NORMAL
	material.normal_scale = 0.55
	material.uv1_scale = Vector3(0.32, 0.32, 0.32)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _ice_cliff_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.88, 0.94)
	material.albedo_texture = SNOW_DIFFUSE
	material.roughness = 0.82
	material.roughness_texture = SNOW_ROUGHNESS
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.normal_enabled = true
	material.normal_texture = SNOW_NORMAL
	material.normal_scale = 0.42
	material.uv1_scale = Vector3(0.18, 0.18, 0.18)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return material


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
