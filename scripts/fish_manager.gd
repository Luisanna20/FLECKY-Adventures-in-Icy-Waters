class_name FishManager
extends Node3D

signal fish_count_changed(current: int, target: int)
signal catch_prompt_changed(text: String)
signal objective_completed

const TARGET_FISH := 10
const SCHOOL_SIZE := 5
const CATCH_DISTANCE := 2.65
const CATCH_CONE_DOT := 0.18
const CATCH_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/water/bubble_01.ogg"),
	preload("res://assets/audio/sfx/water/bubble_02.ogg"),
	preload("res://assets/audio/sfx/water/bubble_03.ogg"),
]

var player: FlakiController
var caught_count := 0
var _random := RandomNumberGenerator.new()
var _catch_audio: AudioStreamPlayer3D
var _last_catch_stream := -1
var _school_centers: Array[Vector3] = [
	Vector3(-21.0, -3.4, -11.0),
	Vector3(20.0, -5.8, -19.0),
	Vector3(8.0, -7.8, 26.0),
]
var _prompt_visible := false
var _completed := false
var _free_roam_mode := false
var _feedback_time := 0.0


func configure(target_player: FlakiController) -> void:
	player = target_player
	_random.seed = 9152026
	_build_catch_audio()
	for school_index in _school_centers.size():
		for fish_index in SCHOOL_SIZE:
			_spawn_fish(school_index, fish_index)
	fish_count_changed.emit(caught_count, TARGET_FISH)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or _completed:
		return
	if _feedback_time > 0.0:
		_feedback_time -= delta
		if _feedback_time <= 0.0:
			catch_prompt_changed.emit("")
		return
	var candidate := _find_catch_candidate()
	var has_candidate := is_instance_valid(candidate)
	if has_candidate != _prompt_visible:
		_prompt_visible = has_candidate
		catch_prompt_changed.emit("PROMPT_CATCH_FISH" if has_candidate else "")

	if Input.is_action_just_pressed("catch_fish") and has_candidate:
		attempt_catch()


func get_active_fish_count() -> int:
	return get_tree().get_nodes_in_group("catchable_fish").size()


func get_active_species_count() -> int:
	var species_seen := {}
	for node in get_tree().get_nodes_in_group("catchable_fish"):
		var fish := node as BayFish
		if is_instance_valid(fish):
			species_seen[fish.species_index] = true
	return species_seen.size()


func fish_environment_physics_ready() -> bool:
	for node in get_tree().get_nodes_in_group("catchable_fish"):
		var fish := node as BayFish
		if (
			not is_instance_valid(fish)
			or not fish.has_environment_collision()
			or not fish.is_inside_water_volume()
		):
			return false
	return true


func is_catch_audio_ready() -> bool:
	if not is_instance_valid(_catch_audio) or CATCH_STREAMS.size() != 3:
		return false
	for stream in CATCH_STREAMS:
		if not is_instance_valid(stream) or stream.get_length() <= 0.0:
			return false
	return true


func attempt_catch() -> bool:
	if _free_roam_mode:
		return false
	var candidate := _find_catch_candidate()
	if not is_instance_valid(candidate):
		return false
	_catch_fish(candidate)
	return true


func enter_free_roam() -> void:
	_free_roam_mode = true
	_completed = true
	_prompt_visible = false
	_feedback_time = 0.0
	catch_prompt_changed.emit("")
	for node in get_tree().get_nodes_in_group("catchable_fish"):
		var fish := node as BayFish
		if is_instance_valid(fish):
			fish.remove_from_group("catchable_fish")


func is_free_roam_mode() -> bool:
	return _free_roam_mode


func _find_catch_candidate() -> BayFish:
	var mouth_position := player.global_position - player.global_basis.z * 1.0
	var forward := -player.global_basis.z
	var nearest: BayFish
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("catchable_fish"):
		var fish := node as BayFish
		if not is_instance_valid(fish):
			continue
		var offset := fish.global_position - mouth_position
		var distance := offset.length()
		if distance > CATCH_DISTANCE or distance >= nearest_distance:
			continue
		var direction := offset.normalized()
		if forward.dot(direction) < CATCH_CONE_DOT:
			continue
		nearest = fish
		nearest_distance = distance
	return nearest


func _catch_fish(fish: BayFish) -> void:
	var catch_position := fish.global_position
	fish.catch()
	player.play_catch_animation()
	_play_catch_sound(catch_position)
	caught_count += 1
	fish_count_changed.emit(caught_count, TARGET_FISH)
	catch_prompt_changed.emit("PROMPT_FISH_CAUGHT")
	_prompt_visible = false
	_feedback_time = 0.9

	if caught_count >= TARGET_FISH:
		_completed = true
		objective_completed.emit()
		return

	var respawn_timer := get_tree().create_timer(_random.randf_range(3.8, 6.2))
	respawn_timer.timeout.connect(_respawn_after_catch)


func _build_catch_audio() -> void:
	_catch_audio = AudioStreamPlayer3D.new()
	_catch_audio.name = "FishCatchAudio"
	_catch_audio.volume_db = -5.0
	_catch_audio.max_distance = 38.0
	_catch_audio.unit_size = 3.0
	_catch_audio.top_level = true
	add_child(_catch_audio)


func _play_catch_sound(position: Vector3) -> void:
	if not is_instance_valid(_catch_audio) or CATCH_STREAMS.is_empty():
		return
	var stream_index := _random.randi_range(0, CATCH_STREAMS.size() - 1)
	if CATCH_STREAMS.size() > 1 and stream_index == _last_catch_stream:
		stream_index = (stream_index + 1) % CATCH_STREAMS.size()
	_last_catch_stream = stream_index
	_catch_audio.stream = CATCH_STREAMS[stream_index]
	_catch_audio.global_position = position
	_catch_audio.pitch_scale = _random.randf_range(0.96, 1.08)
	_catch_audio.play()


func _respawn_after_catch() -> void:
	if _completed:
		return
	var school_index := _random.randi_range(0, _school_centers.size() - 1)
	_spawn_fish(school_index, _random.randi_range(100, 9999))


func _spawn_fish(school_index: int, fish_index: int) -> void:
	var center := _school_centers[school_index]
	var fish := BayFish.new()
	fish.name = "Fish_%d_%d" % [school_index, fish_index]
	add_child(fish)
	fish.global_position = center + Vector3(
		_random.randf_range(-5.2, 5.2),
		_random.randf_range(-1.7, 1.7),
		_random.randf_range(-5.2, 5.2)
	)
	var school_colors := [
		Color(0.42, 0.86, 0.95),
		Color(0.55, 0.90, 0.78),
		Color(0.38, 0.72, 0.96),
	]
	fish.configure(
		center,
		player,
		93000 + school_index * 1000 + fish_index,
		school_colors[school_index],
		posmod(school_index + fish_index, 3)
	)
