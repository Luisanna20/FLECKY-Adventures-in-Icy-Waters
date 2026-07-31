class_name WaterEnvironmentController
extends Node

const OVERLAY_SHADER := preload("res://shaders/underwater_overlay.gdshader")

var water_level := 0.0
var underwater_amount := 0.0
var _environment: Environment
var _overlay_material: ShaderMaterial
var _low_pass: AudioEffectLowPassFilter


func configure(environment: Environment, surface_height: float) -> void:
	_environment = environment
	water_level = surface_height
	_build_overlay()
	_setup_audio_filter()


func _process(delta: float) -> void:
	if not is_instance_valid(_environment):
		return
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return

	var target := 1.0 if camera.global_position.y < water_level - 0.10 else 0.0
	underwater_amount = move_toward(underwater_amount, target, delta * 1.85)
	_overlay_material.set_shader_parameter("underwater_amount", underwater_amount)

	_environment.background_color = Color(0.12, 0.31, 0.43).lerp(
		Color(0.025, 0.31, 0.39),
		underwater_amount
	)
	_environment.ambient_light_color = Color(0.48, 0.67, 0.76).lerp(
		Color(0.30, 0.63, 0.70),
		underwater_amount
	)
	_environment.ambient_light_energy = lerpf(0.72, 0.90, underwater_amount)
	_environment.fog_light_color = Color(0.34, 0.55, 0.64).lerp(
		Color(0.14, 0.49, 0.56),
		underwater_amount
	)
	_environment.fog_density = lerpf(0.004, 0.0095, underwater_amount)
	_environment.fog_height_density = lerpf(0.018, 0.008, underwater_amount)

	if is_instance_valid(_low_pass):
		_low_pass.cutoff_hz = lerpf(20500.0, 1450.0, underwater_amount)


func _build_overlay() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "UnderwaterPostProcess"
	overlay_layer.layer = 5
	add_child(overlay_layer)

	var overlay := ColorRect.new()
	overlay.name = "ColdWaterOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = OVERLAY_SHADER
	_overlay_material.set_shader_parameter("underwater_amount", 0.0)
	overlay.material = _overlay_material
	overlay_layer.add_child(overlay)


func _setup_audio_filter() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return
	_low_pass = AudioEffectLowPassFilter.new()
	_low_pass.cutoff_hz = 20500.0
	_low_pass.resonance = 0.55
	AudioServer.add_bus_effect(master_bus, _low_pass)
