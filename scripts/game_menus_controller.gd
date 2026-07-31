class_name GameMenusController
extends CanvasLayer

signal pause_changed(paused: bool)
signal main_menu_changed(active: bool)
signal game_started
signal free_roam_requested

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_WINDOWED_SIZE := Vector2i(1280, 720)
const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var _main_backdrop: ColorRect
var _main_panel: PanelContainer
var _main_content: VBoxContainer
var _controls_content: VBoxContainer
var _credits_panel: PanelContainer
var _credits_content: VBoxContainer
var _achievements_panel: PanelContainer
var _achievement_grid: GridContainer
var _achievement_progress_label: Label
var _achievement_manager: AchievementManager
var _achievement_toast: Panel
var _toast_icon: TextureRect
var _toast_name_label: Label
var _toast_description_label: Label
var _toast_queue: Array[String] = []
var _toast_active := false
var _pause_backdrop: ColorRect
var _settings_backdrop: ColorRect
var _window_mode_option: OptionButton
var _resolution_option: OptionButton
var _language_option: OptionButton
var _victory_backdrop: ColorRect
var _main_menu_active := false
var _victory_active := false
var _cinematic_active := false
var _settings_active := false
var _settings_return_target := "main"
var _fullscreen_enabled := false
var _windowed_size := DEFAULT_WINDOWED_SIZE
var _glass_shimmer_index := 0


func configure(
	show_main_menu: bool = true,
	achievement_manager: AchievementManager = null
) -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_achievement_manager = achievement_manager
	if not Localization.language_changed.is_connected(_on_language_changed):
		Localization.language_changed.connect(_on_language_changed)
	_build_main_menu()
	_build_pause_menu()
	_build_settings_menu()
	_build_victory_menu()
	_build_achievement_toast()
	if (
		is_instance_valid(_achievement_manager)
		and not _achievement_manager.achievement_unlocked.is_connected(
			_on_achievement_unlocked
		)
	):
		_achievement_manager.achievement_unlocked.connect(_on_achievement_unlocked)
	_load_display_settings()
	_main_menu_active = show_main_menu
	_main_backdrop.visible = show_main_menu
	if show_main_menu:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_credits_panel) and _credits_panel.visible:
		if event.is_action_pressed("pause"):
			_on_credits_back_pressed()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_achievements_panel) and _achievements_panel.visible:
		if event.is_action_pressed("pause"):
			_on_achievements_back_pressed()
			get_viewport().set_input_as_handled()
		return
	if _settings_active:
		if event.is_action_pressed("pause"):
			_on_settings_back_pressed()
			get_viewport().set_input_as_handled()
		return
	if _main_menu_active or _victory_active or _cinematic_active:
		return
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	if _main_menu_active or _victory_active:
		return
	get_tree().paused = paused
	_pause_backdrop.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	pause_changed.emit(paused)


func show_victory() -> void:
	_main_menu_active = false
	_main_backdrop.visible = false
	_victory_active = true
	_cinematic_active = false
	_settings_active = false
	_settings_backdrop.visible = false
	get_tree().paused = false
	_pause_backdrop.visible = false
	_victory_backdrop.visible = true
	_victory_backdrop.modulate.a = 0.0
	pause_changed.emit(false)
	var reveal_tween := create_tween()
	reveal_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(_victory_backdrop, "modulate:a", 1.0, 0.85)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func begin_cinematic() -> void:
	_main_menu_active = false
	_main_backdrop.visible = false
	_cinematic_active = true
	_settings_active = false
	_settings_backdrop.visible = false
	if get_tree().paused:
		get_tree().paused = false
	_pause_backdrop.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_victory_visible() -> bool:
	return _victory_backdrop.visible


func is_main_menu_visible() -> bool:
	return _main_menu_active and _main_backdrop.visible


func debug_pause_cycle() -> bool:
	set_paused(true)
	var paused_correctly := get_tree().paused and _pause_backdrop.visible
	set_paused(false)
	return paused_correctly and not get_tree().paused and not _pause_backdrop.visible


func debug_credits_cycle() -> bool:
	_on_credits_pressed()
	var opened_correctly := (
		is_instance_valid(_credits_panel)
		and _credits_panel.visible
		and is_instance_valid(_credits_content)
		and _credits_content.visible
		and not _main_panel.visible
	)
	_on_credits_back_pressed()
	return (
		opened_correctly
		and _main_panel.visible
		and not _credits_panel.visible
	)


func debug_settings_cycle() -> bool:
	set_paused(true)
	_on_pause_settings_pressed()
	var opened_correctly := (
		_settings_active
		and _settings_backdrop.visible
		and not _pause_backdrop.visible
	)
	_on_settings_back_pressed()
	var returned_correctly := (
		not _settings_active
		and not _settings_backdrop.visible
		and _pause_backdrop.visible
		and get_tree().paused
	)
	set_paused(false)
	return opened_correctly and returned_correctly


func debug_achievements_cycle() -> bool:
	if not is_instance_valid(_achievement_manager):
		return false
	_on_achievements_pressed()
	var opened_correctly := (
		is_instance_valid(_achievements_panel)
		and _achievements_panel.visible
		and is_instance_valid(_achievement_grid)
		and _achievement_grid.get_child_count()
			== _achievement_manager.get_total_count()
	)
	_on_achievements_back_pressed()
	return (
		opened_correctly
		and not _achievements_panel.visible
		and _main_panel.visible
	)


func debug_localization_cycle() -> bool:
	if not Localization.has_complete_catalogs():
		return false
	var original_language: String = Localization.current_language
	var translated_titles := {}
	for language_code in Localization.SUPPORTED_LANGUAGES:
		Localization.set_language(language_code, false)
		translated_titles[tr("MENU_START")] = true
	Localization.set_language(original_language, false)
	return translated_titles.size() == Localization.SUPPORTED_LANGUAGES.size()


func debug_free_roam_choice() -> bool:
	if not _victory_active or not _victory_backdrop.visible:
		return false
	_on_free_roam_pressed()
	return (
		not _victory_active
		and not _victory_backdrop.visible
		and not get_tree().paused
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)


func show_credits_for_preview() -> void:
	_on_credits_pressed()


func show_settings_for_preview() -> void:
	_on_main_settings_pressed()


func show_achievements_for_preview() -> void:
	_on_achievements_pressed()


func _build_main_menu() -> void:
	_main_backdrop = _make_backdrop("MainMenuBackdrop", Color(0.0, 0.0, 0.0, 0.0))
	add_child(_main_backdrop)
	_main_panel = _make_panel(
		Vector2(465.0, 540.0),
		0.0,
		0.0,
		Vector2(32.0, 24.0),
		false,
		10.0
	)
	_main_backdrop.add_child(_main_panel)

	var pages := Control.new()
	pages.custom_minimum_size = Vector2(445.0, 520.0)
	_main_panel.add_child(pages)

	_main_content = VBoxContainer.new()
	_main_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_content.alignment = BoxContainer.ALIGNMENT_BEGIN
	_main_content.add_theme_constant_override("separation", 8)
	pages.add_child(_main_content)
	_main_content.add_child(
		_make_title("GAME_TITLE", 44, Color(0.94, 0.99, 1.0))
	)
	_main_content.add_child(
		_make_title("GAME_SUBTITLE", 18, Color(0.62, 0.91, 0.98))
	)
	var version := str(ProjectSettings.get_setting("application/config/version", "0.2.0"))
	_main_content.add_child(
		_make_title("DEMO v%s" % version, 12, Color(0.98, 0.89, 0.51))
	)
	_main_content.add_child(
		_make_subtitle("MENU_TAGLINE", 15)
	)
	_main_content.add_child(_make_spacer(12.0))
	_main_content.add_child(_make_button("MENU_START", _on_start_pressed, true))
	_main_content.add_child(_make_button("MENU_CONTROLS", _on_controls_pressed, true))
	_main_content.add_child(_make_button("MENU_SETTINGS", _on_main_settings_pressed, true))
	_main_content.add_child(
		_make_button("MENU_ACHIEVEMENTS", _on_achievements_pressed, true)
	)
	_main_content.add_child(_make_button("MENU_CREDITS", _on_credits_pressed, true))
	_main_content.add_child(_make_button("MENU_EXIT", _on_exit_pressed, true))
	_main_content.add_child(_make_spacer(6.0))
	_main_content.add_child(_make_subtitle("MENU_MUSIC", 13))

	_controls_content = VBoxContainer.new()
	_controls_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls_content.add_theme_constant_override("separation", 11)
	pages.add_child(_controls_content)
	_controls_content.add_child(
		_make_title("CONTROLS_TITLE", 34, Color(0.83, 0.96, 1.0))
	)
	var controls := _make_subtitle("CONTROLS_BODY", 19)
	controls.add_theme_constant_override("line_spacing", 7)
	_controls_content.add_child(controls)
	_controls_content.add_child(_make_spacer(12.0))
	_controls_content.add_child(_make_button("BUTTON_BACK", _on_controls_back_pressed))
	_controls_content.visible = false

	_build_credits_page()
	_build_achievements_page()


func _build_credits_page() -> void:
	_credits_panel = _make_panel(
		Vector2(1120.0, 620.0),
		0.0,
		0.0,
		Vector2(32.0, 24.0),
		false,
		10.0
	)
	_main_backdrop.add_child(_credits_panel)
	_credits_content = _make_menu_content(_credits_panel)
	_credits_content.alignment = BoxContainer.ALIGNMENT_BEGIN
	_credits_content.add_theme_constant_override("separation", 8)
	_credits_content.add_child(
		_make_title("CREDITS_TITLE", 34, Color(0.83, 0.96, 1.0))
	)

	var columns := HBoxContainer.new()
	columns.custom_minimum_size = Vector2(1100.0, 480.0)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_credits_content.add_child(columns)
	columns.add_child(_make_credits_column("CREDITS_PRIMARY"))
	columns.add_child(_make_credits_column("CREDITS_ASSETS"))

	var back_button := _make_button("BUTTON_BACK", _on_credits_back_pressed, true)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_credits_content.add_child(back_button)
	_credits_panel.visible = false


func _make_credits_column(text_key: String) -> PanelContainer:
	var column := PanelContainer.new()
	column.custom_minimum_size = Vector2(543.0, 480.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.20, 0.27, 0.30)
	style.border_color = Color(0.55, 0.91, 0.98, 0.70)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.12, 0.67, 0.88, 0.16)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 2.0)
	style.set_content_margin_all(20.0)
	column.add_theme_stylebox_override("panel", style)

	var label := _make_subtitle(text_key, 17)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("line_spacing", 5)
	column.add_child(label)
	return column


func _build_achievements_page() -> void:
	_achievements_panel = _make_panel(
		Vector2(850.0, 620.0),
		0.0,
		0.0,
		Vector2(32.0, 24.0),
		false,
		10.0
	)
	_main_backdrop.add_child(_achievements_panel)
	var content := _make_menu_content(_achievements_panel)
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 7)
	content.add_child(
		_make_title("ACHIEVEMENTS_TITLE", 34, Color(0.90, 0.98, 1.0))
	)
	_achievement_progress_label = _make_subtitle("", 14)
	content.add_child(_achievement_progress_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(830.0, 454.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	content.add_child(scroll)

	_achievement_grid = GridContainer.new()
	_achievement_grid.columns = 2
	_achievement_grid.custom_minimum_size.x = 820.0
	_achievement_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievement_grid.add_theme_constant_override("h_separation", 10)
	_achievement_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_achievement_grid)

	content.add_child(
		_make_button("BUTTON_BACK", _on_achievements_back_pressed, true)
	)
	_achievements_panel.visible = false
	_rebuild_achievement_cards()


func _rebuild_achievement_cards() -> void:
	if not is_instance_valid(_achievement_grid):
		return
	for child in _achievement_grid.get_children():
		_achievement_grid.remove_child(child)
		child.queue_free()
	if not is_instance_valid(_achievement_manager):
		return
	_achievement_progress_label.text = tr("ACHIEVEMENTS_PROGRESS") % [
		_achievement_manager.get_unlocked_count(),
		_achievement_manager.get_total_count(),
	]
	for definition in _achievement_manager.get_definitions():
		_achievement_grid.add_child(_make_achievement_card(definition))


func _make_achievement_card(definition: Dictionary) -> PanelContainer:
	var achievement_id := str(definition.get("id", ""))
	var unlocked := _achievement_manager.is_unlocked(achievement_id)
	var secret := bool(definition.get("secret", false))
	var hidden := secret and not unlocked

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(405.0, 108.0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = (
		Color(0.055, 0.24, 0.31, 0.48)
		if unlocked
		else Color(0.025, 0.12, 0.16, 0.42)
	)
	card_style.border_color = (
		Color(0.76, 0.97, 1.0, 0.92)
		if unlocked
		else Color(0.38, 0.61, 0.66, 0.58)
	)
	card_style.set_border_width_all(1)
	card_style.border_width_top = 2
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(8.0)
	card_style.shadow_color = (
		Color(0.22, 0.78, 0.98, 0.22)
		if unlocked
		else Color(0.0, 0.0, 0.0, 0.16)
	)
	card_style.shadow_size = 4
	card_style.shadow_offset = Vector2(0.0, 2.0)
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(86.0, 86.0)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = (
		Color(0.08, 0.28, 0.36, 0.72)
		if unlocked
		else Color(0.03, 0.10, 0.13, 0.76)
	)
	icon_style.border_color = (
		Color(0.72, 0.96, 1.0, 0.90)
		if unlocked
		else Color(0.34, 0.51, 0.55, 0.70)
	)
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(9)
	icon_style.set_content_margin_all(3.0)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_frame)

	if hidden:
		var question := Label.new()
		question.text = "?"
		question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		question.add_theme_font_size_override("font_size", 46)
		question.add_theme_color_override("font_color", Color(0.54, 0.70, 0.74))
		question.add_theme_color_override(
			"font_outline_color",
			Color(0.01, 0.06, 0.08, 0.92)
		)
		question.add_theme_constant_override("outline_size", 4)
		icon_frame.add_child(question)
	else:
		var icon := TextureRect.new()
		icon.texture = load(str(definition.get("icon", ""))) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if not unlocked:
			icon.modulate = Color(0.30, 0.38, 0.40, 0.90)
		icon_frame.add_child(icon)

	var labels := VBoxContainer.new()
	labels.custom_minimum_size = Vector2(293.0, 0.0)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.add_theme_constant_override("separation", 3)
	row.add_child(labels)

	var name_label := Label.new()
	name_label.text = (
		"ACHIEVEMENT_HIDDEN_NAME"
		if hidden
		else str(definition.get("name_key", ""))
	)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.94, 0.99, 1.0) if unlocked else Color(0.62, 0.72, 0.74)
	)
	name_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.06, 0.08, 0.92)
	)
	name_label.add_theme_constant_override("outline_size", 2)
	labels.add_child(name_label)

	var description_label := Label.new()
	description_label.text = (
		"ACHIEVEMENT_HIDDEN_DESC"
		if hidden
		else str(definition.get("description_key", ""))
	)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.94, 0.97) if unlocked else Color(0.50, 0.62, 0.65)
	)
	description_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.06, 0.08, 0.90)
	)
	description_label.add_theme_constant_override("outline_size", 2)
	labels.add_child(description_label)
	return card


func _build_pause_menu() -> void:
	_pause_backdrop = _make_backdrop("PauseBackdrop", Color(0.01, 0.08, 0.12, 0.08))
	add_child(_pause_backdrop)
	var panel := _make_panel(
		Vector2(465.0, 500.0),
		0.0,
		0.0,
		Vector2(32.0, 24.0),
		false,
		10.0
	)
	_pause_backdrop.add_child(panel)
	var content := _make_menu_content(panel)
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 8)
	content.add_child(_make_title("PAUSE_TITLE", 34, Color(0.90, 0.98, 1.0)))
	content.add_child(_make_subtitle("PAUSE_SUBTITLE", 16))
	content.add_child(_make_spacer(10.0))
	content.add_child(_make_button("PAUSE_CONTINUE", _on_continue_pressed, true))
	content.add_child(_make_button("MENU_SETTINGS", _on_pause_settings_pressed, true))
	content.add_child(_make_button("PAUSE_RESTART", _on_restart_pressed, true))
	content.add_child(_make_button("VICTORY_MAIN_MENU", _on_return_to_menu_pressed, true))
	content.add_child(_make_button("MENU_EXIT", _on_exit_pressed, true))
	_pause_backdrop.visible = false


func _build_settings_menu() -> void:
	_settings_backdrop = _make_backdrop(
		"SettingsBackdrop",
		Color(0.0, 0.0, 0.0, 0.0)
	)
	add_child(_settings_backdrop)
	var panel := _make_panel(
		Vector2(520.0, 560.0),
		0.0,
		0.0,
		Vector2(32.0, 24.0),
		false,
		10.0
	)
	_settings_backdrop.add_child(panel)
	var content := _make_menu_content(panel)
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 5)
	content.add_child(_make_title("SETTINGS_TITLE", 34, Color(0.90, 0.98, 1.0)))
	content.add_child(_make_spacer(5.0))
	content.add_child(_make_subtitle("SETTINGS_DISPLAY_MODE", 16))
	_window_mode_option = _make_option_button(_on_window_mode_selected)
	content.add_child(_window_mode_option)
	content.add_child(_make_subtitle("SETTINGS_DISPLAY_HELP", 13))
	content.add_child(_make_spacer(5.0))
	content.add_child(_make_subtitle("SETTINGS_RESOLUTION", 16))
	_resolution_option = _make_option_button(_on_resolution_selected)
	content.add_child(_resolution_option)
	content.add_child(_make_subtitle("SETTINGS_RESOLUTION_HELP", 13))
	content.add_child(_make_spacer(5.0))
	content.add_child(_make_subtitle("SETTINGS_LANGUAGE", 16))
	_language_option = _make_option_button(_on_language_selected)
	content.add_child(_language_option)
	content.add_child(_make_subtitle("SETTINGS_LANGUAGE_HELP", 13))
	content.add_child(_make_spacer(5.0))
	content.add_child(_make_button("BUTTON_BACK", _on_settings_back_pressed, true))
	_settings_backdrop.visible = false
	_refresh_settings_options()


func _build_victory_menu() -> void:
	_victory_backdrop = _make_backdrop("VictoryBackdrop", Color(0.01, 0.08, 0.12, 0.06))
	add_child(_victory_backdrop)
	var panel := _make_panel(
		Vector2(465.0, 420.0),
		0.0,
		0.0,
		Vector2(32.0, 24.0),
		false,
		10.0
	)
	_victory_backdrop.add_child(panel)
	var content := _make_menu_content(panel)
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 8)
	content.add_child(_make_title("VICTORY_TITLE", 34, Color(1.0, 0.91, 0.48)))
	content.add_child(_make_subtitle("VICTORY_SUBTITLE", 18))
	content.add_child(_make_subtitle("VICTORY_COUNT", 16))
	content.add_child(_make_spacer(8.0))
	content.add_child(_make_button("VICTORY_FREE_ROAM", _on_free_roam_pressed, true))
	content.add_child(_make_button("VICTORY_REPLAY", _on_restart_pressed, true))
	content.add_child(_make_button("VICTORY_MAIN_MENU", _on_return_to_menu_pressed, true))
	_victory_backdrop.visible = false


func _build_achievement_toast() -> void:
	_achievement_toast = Panel.new()
	_achievement_toast.name = "AchievementToast"
	_achievement_toast.anchor_left = 1.0
	_achievement_toast.anchor_top = 0.0
	_achievement_toast.anchor_right = 1.0
	_achievement_toast.anchor_bottom = 0.0
	_achievement_toast.offset_left = -438.0
	_achievement_toast.offset_top = 30.0
	_achievement_toast.offset_right = -30.0
	_achievement_toast.offset_bottom = 142.0
	_achievement_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.025, 0.16, 0.22, 0.92)
	toast_style.border_color = Color(0.77, 0.97, 1.0, 0.96)
	toast_style.set_border_width_all(2)
	toast_style.set_corner_radius_all(12)
	toast_style.shadow_color = Color(0.16, 0.70, 0.92, 0.36)
	toast_style.shadow_size = 10
	toast_style.shadow_offset = Vector2(0.0, 3.0)
	_achievement_toast.add_theme_stylebox_override("panel", toast_style)
	add_child(_achievement_toast)

	_toast_icon = TextureRect.new()
	_toast_icon.position = Vector2(12.0, 12.0)
	_toast_icon.size = Vector2(88.0, 88.0)
	_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_toast.add_child(_toast_icon)

	var unlocked_label := Label.new()
	unlocked_label.position = Vector2(112.0, 12.0)
	unlocked_label.size = Vector2(282.0, 19.0)
	unlocked_label.text = "ACHIEVEMENT_UNLOCKED_TOAST"
	unlocked_label.add_theme_font_size_override("font_size", 12)
	unlocked_label.add_theme_color_override("font_color", Color(0.99, 0.88, 0.42))
	unlocked_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.06, 0.08, 0.92)
	)
	unlocked_label.add_theme_constant_override("outline_size", 2)
	unlocked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_toast.add_child(unlocked_label)

	_toast_name_label = Label.new()
	_toast_name_label.position = Vector2(112.0, 33.0)
	_toast_name_label.size = Vector2(282.0, 29.0)
	_toast_name_label.max_lines_visible = 1
	_toast_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast_name_label.add_theme_font_size_override("font_size", 18)
	_toast_name_label.add_theme_color_override("font_color", Color(0.94, 0.99, 1.0))
	_toast_name_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.06, 0.08, 0.92)
	)
	_toast_name_label.add_theme_constant_override("outline_size", 2)
	_toast_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_toast.add_child(_toast_name_label)

	_toast_description_label = Label.new()
	_toast_description_label.position = Vector2(112.0, 62.0)
	_toast_description_label.size = Vector2(282.0, 40.0)
	_toast_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_description_label.max_lines_visible = 2
	_toast_description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast_description_label.add_theme_font_size_override("font_size", 12)
	_toast_description_label.add_theme_color_override(
		"font_color",
		Color(0.80, 0.93, 0.96)
	)
	_toast_description_label.add_theme_color_override(
		"font_outline_color",
		Color(0.01, 0.06, 0.08, 0.90)
	)
	_toast_description_label.add_theme_constant_override("outline_size", 2)
	_toast_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achievement_toast.add_child(_toast_description_label)

	_achievement_toast.visible = false


func _on_achievement_unlocked(achievement_id: String) -> void:
	_rebuild_achievement_cards()
	_toast_queue.append(achievement_id)
	if not _toast_active:
		_show_next_achievement_toast()


func _show_next_achievement_toast() -> void:
	if _toast_queue.is_empty() or not is_instance_valid(_achievement_manager):
		_toast_active = false
		return
	var achievement_id: String = _toast_queue.pop_front()
	var definition := _achievement_manager.get_definition(achievement_id)
	if definition.is_empty():
		_show_next_achievement_toast()
		return
	_toast_active = true
	_toast_icon.texture = load(str(definition.get("icon", ""))) as Texture2D
	_toast_name_label.text = str(definition.get("name_key", ""))
	_toast_description_label.text = str(definition.get("description_key", ""))
	_achievement_toast.visible = true
	_achievement_toast.modulate.a = 0.0
	_achievement_toast.scale = Vector2(0.97, 0.97)
	_achievement_toast.pivot_offset = _achievement_toast.size * Vector2(0.5, 0.5)
	var toast_tween := create_tween()
	toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	toast_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	toast_tween.set_parallel(true)
	toast_tween.tween_property(_achievement_toast, "modulate:a", 1.0, 0.32)
	toast_tween.tween_property(_achievement_toast, "scale", Vector2.ONE, 0.32)
	toast_tween.set_parallel(false)
	toast_tween.tween_interval(3.4)
	toast_tween.tween_property(_achievement_toast, "modulate:a", 0.0, 0.42)
	toast_tween.tween_callback(_finish_achievement_toast)


func _finish_achievement_toast() -> void:
	_achievement_toast.visible = false
	_achievement_toast.modulate.a = 1.0
	_achievement_toast.scale = Vector2.ONE
	_toast_active = false
	_show_next_achievement_toast()


func _make_backdrop(node_name: String, color: Color) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.name = node_name
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = color
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	return backdrop


func _make_panel(
	panel_size: Vector2,
	background_alpha: float = 0.96,
	horizontal_offset: float = 0.0,
	top_left_position: Vector2 = Vector2(-1.0, -1.0),
	show_frame: bool = true,
	content_margin: float = 28.0
) -> PanelContainer:
	var panel := PanelContainer.new()
	if top_left_position.x >= 0.0 and top_left_position.y >= 0.0:
		panel.anchor_left = 0.0
		panel.anchor_top = 0.0
		panel.anchor_right = 0.0
		panel.anchor_bottom = 0.0
		panel.offset_left = top_left_position.x
		panel.offset_top = top_left_position.y
		panel.offset_right = top_left_position.x + panel_size.x
		panel.offset_bottom = top_left_position.y + panel_size.y
	else:
		panel.anchor_left = 0.5
		panel.anchor_top = 0.5
		panel.anchor_right = 0.5
		panel.anchor_bottom = 0.5
		panel.offset_left = -panel_size.x * 0.5 + horizontal_offset
		panel.offset_top = -panel_size.y * 0.5
		panel.offset_right = panel_size.x * 0.5 + horizontal_offset
		panel.offset_bottom = panel_size.y * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.13, 0.18, background_alpha)
	style.border_color = Color(0.46, 0.83, 0.91, 0.72 if show_frame else 0.0)
	style.set_border_width_all(2 if show_frame else 0)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(content_margin)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_menu_content(panel: PanelContainer) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	return content


func _make_title(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.07, 0.10, 0.92))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _make_subtitle(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.80, 0.93, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.07, 0.10, 0.92))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _make_button(text: String, callback: Callable, animated_glass: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300.0, 44.0)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.91, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.82, 0.96, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.01, 0.07, 0.10, 0.88))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_stylebox_override(
		"normal",
		_make_glass_button_style(
			Color(0.035, 0.20, 0.27, 0.34),
			Color(0.55, 0.91, 0.98, 0.76),
			Color(0.12, 0.67, 0.88, 0.16),
			4
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_glass_button_style(
			Color(0.10, 0.42, 0.55, 0.48),
			Color(0.82, 0.98, 1.0, 0.96),
			Color(0.28, 0.83, 1.0, 0.34),
			7
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_glass_button_style(
			Color(0.025, 0.28, 0.39, 0.60),
			Color(0.68, 0.94, 1.0, 0.92),
			Color(0.18, 0.68, 0.88, 0.22),
			3
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_make_glass_button_style(
			Color(0.08, 0.34, 0.46, 0.44),
			Color(0.92, 1.0, 1.0, 0.96),
			Color(0.34, 0.87, 1.0, 0.30),
			6
		)
	)
	button.clip_contents = true
	button.pressed.connect(callback)
	if animated_glass:
		var shimmer_delay := float(_glass_shimmer_index) * 0.34
		_glass_shimmer_index += 1
		button.ready.connect(_start_button_shimmer.bind(button, shimmer_delay))
	return button


func _make_glass_button_style(
	fill_color: Color,
	border_color: Color,
	shadow_color: Color,
	shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(9)
	style.corner_detail = 8
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 2.0)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	return style


func _start_button_shimmer(button: Button, delay: float) -> void:
	if not is_instance_valid(button):
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.52, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.75, 0.96, 1.0, 0.0),
		Color(0.75, 0.96, 1.0, 0.0),
		Color(0.90, 1.0, 1.0, 0.14),
		Color(0.75, 0.96, 1.0, 0.0),
		Color(0.75, 0.96, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 104
	texture.height = maxi(44, int(button.size.y))
	texture.fill_from = Vector2(0.0, 1.0)
	texture.fill_to = Vector2(1.0, 0.0)
	var shine := TextureRect.new()
	shine.name = "IceShimmer"
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.texture = texture
	shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shine.stretch_mode = TextureRect.STRETCH_SCALE
	shine.position = Vector2(-112.0, 1.0)
	shine.size = Vector2(104.0, maxf(42.0, button.size.y - 2.0))
	button.add_child(shine)
	var shimmer := button.create_tween()
	shimmer.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shimmer.set_loops()
	shimmer.tween_interval(delay + 0.25)
	shimmer.tween_property(
		shine,
		"position:x",
		button.size.x + 12.0,
		1.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shimmer.tween_interval(2.8)
	shimmer.tween_callback(func() -> void:
		if is_instance_valid(shine):
			shine.position.x = -112.0
	)


func _make_option_button(callback: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(420.0, 44.0)
	option.add_theme_font_size_override("font_size", 18)
	option.add_theme_color_override("font_color", Color(0.91, 0.98, 1.0))
	option.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	option.add_theme_color_override("font_pressed_color", Color(0.82, 0.96, 1.0))
	option.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	option.add_theme_color_override("font_outline_color", Color(0.01, 0.07, 0.10, 0.88))
	option.add_theme_constant_override("outline_size", 2)
	option.add_theme_stylebox_override(
		"normal",
		_make_glass_button_style(
			Color(0.035, 0.20, 0.27, 0.38),
			Color(0.55, 0.91, 0.98, 0.78),
			Color(0.12, 0.67, 0.88, 0.16),
			4
		)
	)
	option.add_theme_stylebox_override(
		"hover",
		_make_glass_button_style(
			Color(0.10, 0.42, 0.55, 0.50),
			Color(0.82, 0.98, 1.0, 0.96),
			Color(0.28, 0.83, 1.0, 0.34),
			7
		)
	)
	option.add_theme_stylebox_override(
		"pressed",
		_make_glass_button_style(
			Color(0.025, 0.28, 0.39, 0.64),
			Color(0.68, 0.94, 1.0, 0.94),
			Color(0.18, 0.68, 0.88, 0.22),
			3
		)
	)
	option.add_theme_stylebox_override(
		"focus",
		_make_glass_button_style(
			Color(0.08, 0.34, 0.46, 0.46),
			Color(0.92, 1.0, 1.0, 0.96),
			Color(0.34, 0.87, 1.0, 0.30),
			6
		)
	)
	option.alignment = HORIZONTAL_ALIGNMENT_CENTER
	option.clip_contents = true
	var popup := option.get_popup()
	var popup_panel := StyleBoxFlat.new()
	popup_panel.bg_color = Color(0.018, 0.13, 0.18, 0.94)
	popup_panel.border_color = Color(0.58, 0.92, 0.98, 0.90)
	popup_panel.set_border_width_all(1)
	popup_panel.set_corner_radius_all(8)
	popup_panel.set_content_margin_all(6.0)
	popup_panel.shadow_color = Color(0.02, 0.24, 0.34, 0.36)
	popup_panel.shadow_size = 8
	popup_panel.shadow_offset = Vector2(0.0, 3.0)
	popup.add_theme_stylebox_override("panel", popup_panel)
	popup.add_theme_stylebox_override(
		"hover",
		_make_glass_button_style(
			Color(0.12, 0.48, 0.62, 0.70),
			Color(0.78, 0.98, 1.0, 0.94),
			Color(0.22, 0.78, 0.98, 0.20),
			2
		)
	)
	popup.add_theme_font_size_override("font_size", 17)
	popup.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	popup.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	popup.add_theme_color_override("font_outline_color", Color(0.01, 0.06, 0.09, 0.90))
	popup.add_theme_constant_override("outline_size", 2)
	option.item_selected.connect(callback)
	var shimmer_delay := float(_glass_shimmer_index) * 0.28
	_glass_shimmer_index += 1
	option.ready.connect(_start_button_shimmer.bind(option, shimmer_delay))
	return option


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _on_start_pressed() -> void:
	if not _main_menu_active:
		return
	_main_menu_active = false
	main_menu_changed.emit(false)
	var start_tween := create_tween()
	start_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	start_tween.tween_property(_main_backdrop, "modulate:a", 0.0, 0.55)
	start_tween.tween_callback(_finish_game_start)


func _finish_game_start() -> void:
	_main_backdrop.visible = false
	_main_backdrop.modulate.a = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game_started.emit()


func _on_controls_pressed() -> void:
	_main_content.visible = false
	_controls_content.visible = true


func _on_controls_back_pressed() -> void:
	_controls_content.visible = false
	_main_content.visible = true


func _on_credits_pressed() -> void:
	_main_panel.visible = false
	_credits_content.visible = true
	_credits_panel.visible = true


func _on_credits_back_pressed() -> void:
	_credits_content.visible = false
	_credits_panel.visible = false
	_main_panel.visible = true


func _on_achievements_pressed() -> void:
	_rebuild_achievement_cards()
	_main_panel.visible = false
	_achievements_panel.visible = true


func _on_achievements_back_pressed() -> void:
	_achievements_panel.visible = false
	_main_panel.visible = true


func _on_main_settings_pressed() -> void:
	_open_settings("main")


func _on_pause_settings_pressed() -> void:
	_open_settings("pause")


func _open_settings(return_target: String) -> void:
	_settings_return_target = return_target
	_settings_active = true
	_main_backdrop.visible = false
	_pause_backdrop.visible = false
	_settings_backdrop.visible = true
	_refresh_settings_options()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_settings_back_pressed() -> void:
	_settings_active = false
	_settings_backdrop.visible = false
	if _settings_return_target == "pause":
		_pause_backdrop.visible = true
	else:
		_main_backdrop.visible = true


func _on_window_mode_selected(index: int) -> void:
	_apply_display_mode(index == 1)
	_save_display_settings()


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTION_OPTIONS.size():
		return
	_windowed_size = RESOLUTION_OPTIONS[index]
	if not _fullscreen_enabled:
		_apply_display_mode(false)
	_save_display_settings()


func _on_language_selected(index: int) -> void:
	if index < 0 or index >= Localization.SUPPORTED_LANGUAGES.size():
		return
	Localization.set_language(Localization.SUPPORTED_LANGUAGES[index])


func _on_language_changed(_language_code: String) -> void:
	_refresh_settings_options()
	_rebuild_achievement_cards()


func _load_display_settings() -> void:
	var config := ConfigFile.new()
	var load_result := config.load(SETTINGS_PATH)
	if load_result == OK:
		_fullscreen_enabled = bool(
			config.get_value("display", "fullscreen", false)
		)
		var saved_size := Vector2i(
			int(config.get_value("display", "window_width", DEFAULT_WINDOWED_SIZE.x)),
			int(config.get_value("display", "window_height", DEFAULT_WINDOWED_SIZE.y))
		)
		if saved_size in RESOLUTION_OPTIONS:
			_windowed_size = saved_size
	_apply_display_mode(_fullscreen_enabled)


func _save_display_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("display", "fullscreen", _fullscreen_enabled)
	config.set_value("display", "window_width", _windowed_size.x)
	config.set_value("display", "window_height", _windowed_size.y)
	var save_result := config.save(SETTINGS_PATH)
	if save_result != OK:
		push_warning("Не удалось сохранить настройки экрана: %s" % error_string(save_result))


func _apply_display_mode(fullscreen: bool) -> void:
	_fullscreen_enabled = fullscreen
	_refresh_settings_options()
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(_windowed_size)
	var current_screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(current_screen)
	var centered_position := usable_rect.position + Vector2i(
		maxi((usable_rect.size.x - _windowed_size.x) / 2, 0),
		maxi((usable_rect.size.y - _windowed_size.y) / 2, 0)
	)
	DisplayServer.window_set_position(centered_position)


func _refresh_settings_options() -> void:
	if not is_instance_valid(_window_mode_option):
		return
	_window_mode_option.clear()
	_window_mode_option.add_item(tr("SETTINGS_WINDOWED"))
	_window_mode_option.add_item(tr("SETTINGS_FULLSCREEN"))
	_window_mode_option.select(1 if _fullscreen_enabled else 0)

	_resolution_option.clear()
	for resolution in RESOLUTION_OPTIONS:
		_resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	var resolution_index := RESOLUTION_OPTIONS.find(_windowed_size)
	_resolution_option.select(maxi(resolution_index, 0))

	_language_option.clear()
	for language_code in Localization.SUPPORTED_LANGUAGES:
		var language_key := "SETTINGS_LANGUAGE_%s" % language_code.to_upper()
		_language_option.add_item(tr(language_key))
	var language_index := Localization.SUPPORTED_LANGUAGES.find(
		Localization.current_language
	)
	_language_option.select(maxi(language_index, 0))


func _on_continue_pressed() -> void:
	set_paused(false)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().set_meta("flaki_auto_start", true)
	get_tree().reload_current_scene()


func _on_return_to_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().set_meta("flaki_auto_start", false)
	get_tree().reload_current_scene()


func _on_free_roam_pressed() -> void:
	if not _victory_active:
		return
	_victory_active = false
	_cinematic_active = false
	_victory_backdrop.visible = false
	_victory_backdrop.modulate.a = 1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_changed.emit(false)
	free_roam_requested.emit()


func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
