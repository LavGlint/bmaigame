extends Control

const BG = Color("101617")
const PANEL = Color("1a2825")
const LINE = Color("43584f")
const INK = Color("edf0eb")
const MUTED = Color("879b8e")
const GOLD = Color("d7ea45")
const MAP_NAMES = ["工业仓库·三线穿插", "石砌遗迹·双环绕行", "林间哨站·分叉穿插", "随机"]
const ROSTER_ORDER = [0, 1, 2, 3, 4, 5]

var world: HanabiArenaWorld
var router: HanabiInputRouter
var store: HanabiMatchStore
var sound: HanabiTonePlayer
var settings_store: HanabiUserSettings
var window_fullscreen: bool = false
var font: FontFile
var heading_font: FontFile
var modal_return_focus: Control
var canvas: Control
var page: Control
var screen: String = "lobby"
var session := HanabiLobbyState.new()
var menu_input := HanabiMenuInput.new()
var views: HanabiScreens
var selected_map: int:
	get: return session.selected_map
	set(value): session.selected_map = value
var round_seconds: int:
	get: return session.round_seconds
	set(value): session.round_seconds = value
var round_count: int:
	get: return session.round_count
	set(value): session.round_count = value
var initial_hearts: int:
	get: return session.initial_hearts
	set(value): session.initial_hearts = value
var characters: Array[int]:
	get: return session.characters
	set(value): session.characters = value
var ready_slots: Array[bool]:
	get: return session.ready_slots
	set(value): session.ready_slots = value
var active_slot: int:
	get: return session.active_slot
	set(value): session.active_slot = value
var health_meters: Array[HanabiHealthMeter] = []
var boom_labels: Array[Label] = []
var number_font: SystemFont
var mouse_target: Vector2
var mouse_aim_active: bool = false
var known_modes: Array[String] = ["key1", "ai", "ai", "ai"]
var known_devices: Array[int] = [-1, -1, -1, -1]
var hud_scores: Array[Label] = []
var hud_hearts: Array[Label] = []
var time_label: Label
var phase_label: Label
var round_label: Label
var ready_label: Label
var start_button: Button
var pause_panel: Control
var modal: Control
var modal_text: Label
var modal_kind: String = ""
var result_recorded: bool = false
var message: String = ""
var capture_path: String = ""
var capture_screen: String = "lobby"
var qa_mode: bool = false
var qa_clock: float = 0.0
var qa_pending: bool = false
var arena_view: TextureRect
var subviewport: SubViewport
var arena_camera: Camera2D
var selection_buttons: Array[Button] = []
var ready_buttons: Array[Button] = []

func _ready() -> void:
	DisplayServer.window_set_title("BOOMERANG BRAWL · v1.0.0")
	for arg in OS.get_cmdline_user_args():
		if arg == "--qa" or arg.begins_with("--capture="): qa_mode = true
	HanabiMenuInput.configure_native_menu()
	font = HanabiTypography.REGULAR
	heading_font = HanabiTypography.display_font()
	number_font = SystemFont.new()
	number_font.font_names = PackedStringArray(["Bahnschrift", "Consolas", "Arial"])
	number_font.font_weight = 650
	number_font.font_italic = true
	views = HanabiScreens.new(self)
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 18
	ui_theme.set_stylebox("panel", "TooltipPanel", _style(PANEL, LINE))
	ui_theme.set_color("font_color", "TooltipLabel", INK)
	ui_theme.set_font_size("font_size", "TooltipLabel", 14)
	theme = ui_theme
	router = HanabiInputRouter.new()
	add_child(router)
	store = HanabiMatchStore.new()
	sound = HanabiTonePlayer.new()
	add_child(sound)
	if settings_store == null:
		settings_store = HanabiUserSettings.new("user://qa-preview-settings.cfg" if qa_mode else HanabiUserSettings.DEFAULT_PATH)
		if qa_mode and "--screen=settings-reloaded" not in OS.get_cmdline_user_args():
			settings_store.values = HanabiUserSettings.DEFAULTS.duplicate()
			settings_store.has_saved = false
	sound.enabled = settings_store.values.sound_enabled
	sound.volume = settings_store.values.volume
	_apply_display_mode(settings_store.values.fullscreen)
	subviewport = SubViewport.new()
	subviewport.size = Vector2i(1280,720)
	subviewport.world_2d = World2D.new()
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(subviewport)
	world = HanabiArenaWorld.new()
	world.router = router
	world.font = font
	subviewport.add_child(world)
	arena_camera = Camera2D.new()
	arena_camera.name = "FullMapCamera"
	arena_camera.position_smoothing_enabled = false
	subviewport.add_child(arena_camera)
	_frame_map()
	world.match_finished.connect(_on_match_finished)
	world.effect.connect(sound.play_effect)
	router.devices_changed.connect(_devices_changed)
	router.controller_lost.connect(func(slot): world.set_paused("P%d 手柄断开，请重新连接后继续" % (slot + 1)))
	canvas = Control.new()
	canvas.size = Vector2(1280, 720)
	add_child(canvas)
	resized.connect(_resize_canvas)
	_resize_canvas()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--screen="): capture_screen = arg.trim_prefix("--screen=")
		if arg == "--demo": capture_screen = "game"
		if arg == "--qa": qa_mode = true
	qa_mode = qa_mode or not capture_path.is_empty()
	_show_screen("lobby")
	if capture_screen.begins_with("lobby-") and qa_mode:
		_qa_menu_interaction.call_deferred(capture_screen)
	if capture_screen in ["setup", "codex", "components"]: _show_screen(capture_screen)
	elif capture_screen == "characters": _enter_selection()
	elif capture_screen.begins_with("selection-") and qa_mode:
		router.modes.assign(["pad", "pad", "pad", "pad"])
		router.devices.assign([0, 1, 2, 3])
		router.connection_reader = func(): return PackedInt32Array([0, 1, 2, 3])
		_enter_selection()
		var confirmed := 0 if capture_screen == "selection-p1" else 1 if capture_screen == "selection-p2" else 2 if capture_screen == "selection-p3" else 3 if capture_screen == "selection-p4" else 4
		for slot in range(confirmed): session.confirm(slot)
		_show_screen("characters")
		if confirmed == 4: session.launch_remaining = -1.0
	elif capture_screen.begins_with("components-icons-") and qa_mode:
		_show_screen("components")
		_qa_icon_state.call_deferred(capture_screen.trim_prefix("components-icons-"))
	elif capture_screen in ["components-slider-held", "components-switch-held"] and qa_mode:
		_show_screen("components")
		_qa_hold_control.call_deferred(capture_screen == "components-slider-held")
	elif capture_screen == "setup-over-limit" and qa_mode:
		_set_seconds(180)
		_set_rounds(5)
	elif capture_screen == "settings-hover-on" and qa_mode:
		_show_settings()
		_qa_hover_sound.call_deferred()
	elif capture_screen == "settings": _show_settings()
	elif capture_screen in ["settings-saved", "settings-dirty", "settings-error", "settings-reloaded"] and qa_mode:
		_show_settings()
		if capture_screen != "settings-reloaded": _qa_settings_variant.call_deferred(capture_screen)
	elif capture_screen == "pause-settings" and qa_mode:
		_start(true)
		world.set_paused("暂停设置预览")
		_show_settings()
	elif capture_screen == "help": _show_help()
	elif capture_screen.begins_with("map-") and qa_mode:
		var id := capture_screen.trim_prefix("map-").trim_suffix("-setup").trim_suffix("-pause")
		selected_map = HanabiArenaWorld.MAP_IDS.find(id)
		if selected_map < 0: selected_map = 0
		if capture_screen.ends_with("-setup"):
			_show_screen("setup")
		else:
			for slot in range(4): characters[slot] = (slot+selected_map*2)%6
			_start(true)
			world.rng.seed = 302614+selected_map*31
			world.state = "playing"
			world.started = true
			if capture_screen.ends_with("-pause"): world.set_paused("地图实战暂停回归")
	elif capture_screen.begins_with("ranged-") and qa_mode:
		_start(true)
		_qa_ranged_preview.call_deferred(capture_screen.trim_prefix("ranged-"))
	elif capture_screen.begins_with("combat-") and qa_mode:
		_start(true)
		_qa_combat_preview.call_deferred(capture_screen.trim_prefix("combat-"))
	elif capture_screen in ["game", "pause", "results"]:
		_start(true)
		if capture_screen == "pause": world.set_paused("暂停菜单预览")
		if capture_screen == "results": world.finish_match(true)

func _qa_menu_interaction(kind: String) -> void:
	get_viewport().gui_release_focus()
	var button: Control = page.get_node("Menu3" if kind == "lobby-hover-archive" else "Menu2" if kind == "lobby-selected-auto" else "Menu4" if kind == "lobby-selected-settings" else "Menu1")
	if kind.contains("selected"):
		button.grab_focus()
		return
	var point := button.get_global_transform() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	if kind == "lobby-pressed-local":
		var click := InputEventMouseButton.new()
		click.position = point; click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true; click.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(click, true)

func _qa_combat_preview(kind: String) -> void:
	world.set_physics_process(false)
	world.state = "playing"
	world.started = true
	var positions := [Vector2(200,320),Vector2(520,280),Vector2(940,320),Vector2(590,540)]
	var directions := [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.UP]
	for slot in range(4):
		var role := (slot + 4) % 6 if kind == "extra-roles" else slot
		characters[slot] = role
		var fighter: HanabiFighter = world.fighters[slot]
		fighter.set_character(role)
		fighter.nickname = HanabiArtwork.CHARACTER_NAMES[role]
		fighter.reset_round()
		fighter.position = positions[slot]
		fighter.aim = directions[slot]
		fighter.invulnerable = 0.0
		fighter.throw_cooldown = 0.0
		if kind in ["run", "walk", "extra-roles"]:
			fighter.step({"move": directions[slot], "run": kind == "run"}, 0.1)
		elif kind == "attack":
			fighter.throw_or_recall()
			fighter.last_actions.throw = true
			fighter.step({"throw":role == 0}, 0.2)
		elif kind in ["hurt", "knockdown"]:
			if kind == "knockdown": fighter.hp = 1
			fighter.take_hit(world.fighters[(slot + 1) % 4])
			fighter.step({}, 0.2 if kind == "hurt" else 0.6)
	if kind == "attack":
		for tick in range(6):
			world.combat.step(1.0 / 60.0)
	_show_screen("game")

func _qa_ranged_preview(kind: String) -> void:
	world.set_physics_process(false)
	world.state = "playing"
	world.started = true
	world.clear_boomerangs()
	var role := ["gpt","claude","deepseek","eve","glm","jiuhu"].find(kind.trim_suffix("-pause"))
	if role < 0: role = 0
	var fighter := world.fighters[0]
	characters[0] = role
	fighter.set_character(role)
	fighter.nickname = HanabiArtwork.CHARACTER_NAMES[role]
	fighter.reset_round()
	fighter.position = Vector2(220,375)
	fighter.aim = Vector2.RIGHT
	fighter.invulnerable = 0.0
	fighter.throw_cooldown = 0.0
	for slot in range(1,4):
		world.fighters[slot].position = Vector2(990,150+slot*130)
		world.fighters[slot].invulnerable = 0.0
	if role == 0:
		world.fighters[1].position = Vector2(380,375)
	elif role in [1,4,5]:
		fighter.position = Vector2(270,285)
		fighter.aim = Vector2.UP
	elif role == 3:
		fighter.position = Vector2(270,285)
		fighter.aim = Vector2.UP
		world.fighters[1].position = Vector2(270,115)
	fighter.step({"throw":true},0.2)
	var duration := 0.27 if role == 0 else 0.35 if role == 5 else 0.6 if role == 4 else 0.3 if role == 1 else 0.05 if role == 3 else 0.14
	for tick in range(roundi(duration*60.0)):
		world.combat.step(1.0/60.0)
	for actor in world.fighters: actor.z_index = 0
	fighter.step({"throw":true},0.31)
	if role == 4: fighter.position = Vector2(185,285)
	_show_screen("game")
	if kind.ends_with("-pause"): world.set_paused("远程攻击暂停渲染回归")

func _qa_hover_sound() -> void:
	await get_tree().process_frame
	var toggle: HanabiUISwitch = modal.get_node("SoundSwitch")
	toggle.button_pressed = true
	toggle.grab_focus()
	var motion := InputEventMouseMotion.new()
	motion.position = toggle.get_global_transform() * (toggle.size / 2)
	get_viewport().push_input(motion, true)

func _qa_settings_variant(state: String) -> void:
	await get_tree().process_frame
	modal.get_node("SoundSwitch").button_pressed = true
	modal.get_node("VolumeSlider").value = 0.35
	_apply_display_mode(true)
	modal.get_node("SettingsDisplayMode").select(1)
	_settings_update_status()
	if state == "settings-error": settings_store.writer = func(_config, _path): return ERR_CANT_CREATE
	if state in ["settings-saved", "settings-error"]:
		var save: Button = modal.get_node("SettingsSave")
		var motion := InputEventMouseMotion.new()
		motion.position = save.get_global_transform() * (save.size / 2)
		get_viewport().push_input(motion, true)
		var click := InputEventMouseButton.new()
		click.position = motion.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT
		click.pressed = true
		get_viewport().push_input(click, true)
		click = click.duplicate()
		click.pressed = false
		click.button_mask = 0
		get_viewport().push_input(click, true)

func _qa_icon_state(state: String) -> void:
	await get_tree().process_frame
	get_viewport().gui_release_focus()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1270, 100)
	if state in ["hover", "pressed"]:
		for button in page.find_children("*", "Button", true, false):
			if button.tooltip_text == "大厅":
				motion.position = button.get_global_transform() * (button.size / 2)
				# Keep the QA close-up free of a timed tooltip overlay.
				button.tooltip_text = ""
	get_viewport().push_input(motion, true)
	if state == "pressed":
		var click := InputEventMouseButton.new()
		click.position = motion.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT
		click.pressed = true
		get_viewport().push_input(click, true)

func _qa_hold_control(slider_control: bool) -> void:
	await get_tree().process_frame
	get_viewport().gui_release_focus()
	var target: Control = page.get_node("GallerySlider") if slider_control else page.find_children("*", "CheckButton", true, false)[0]
	var motion := InputEventMouseMotion.new()
	motion.position = target.get_global_transform() * Vector2(target.size.x * (0.7 if slider_control else 0.8), target.size.y / 2)
	get_viewport().push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = motion.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	get_viewport().push_input(click, true)
	if slider_control:
		motion.position = target.get_global_transform() * Vector2(target.size.x * 0.35, target.size.y / 2)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)

func _resize_canvas() -> void:
	if not canvas: return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Vector2(1280, 720) * factor) / 2.0

func _frame_map() -> void:
	if not is_instance_valid(arena_camera) or not is_instance_valid(world.level): return
	var extent: Array = world.level.config.texture_world_size
	var map_size := Vector2(extent[0], extent[1])
	arena_camera.position = world.level.to_global(map_size * 0.5)
	var factor := minf(subviewport.size.x / map_size.x, subviewport.size.y / map_size.y)
	arena_camera.zoom = Vector2.ONE * factor
	arena_camera.force_update_scroll()

func _style(color: Color, border: Color = LINE, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(0)
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box

func _panel(rect: Rect2, parent: Node, color: Color = PANEL, border: Color = LINE) -> Panel:
	var node := HanabiSlantPanel.new()
	node.fill = color
	node.border = border
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _label(text: String, rect: Rect2, parent: Node, pixels: int = 20, color: Color = INK, centered: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", color)
	if pixels >= 24 and text.to_utf8_buffer().size() == text.length(): node.add_theme_font_override("font", number_font)
	elif pixels >= 20: HanabiTypography.style_label(node, true)
	if screen == "game":
		node.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.03, 0.95))
		node.add_theme_constant_override("shadow_offset_x", 1)
		node.add_theme_constant_override("shadow_offset_y", 2)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _button(text: String, rect: Rect2, parent: Node, callback: Callable, primary: bool = false, accent: Color = LINE) -> Button:
	var node := HanabiSlantButton.new()
	node.primary = primary
	node.accent = accent
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", 20)
	node.add_theme_color_override("font_color", BG if primary else INK)
	node.add_theme_color_override("font_hover_color", BG if primary else Color.WHITE)
	node.add_theme_color_override("font_focus_color", BG if primary else Color.WHITE)
	node.add_theme_color_override("font_pressed_color", BG if primary else GOLD)
	node.add_theme_color_override("font_disabled_color", MUTED)
	node.add_theme_stylebox_override("normal", _style(GOLD if primary else PANEL, GOLD if primary else accent, 2))
	node.add_theme_stylebox_override("hover", _style(Color("ddc36a") if primary else Color("2b4034"), GOLD, 2))
	node.add_theme_stylebox_override("pressed", _style(Color("a88a3c") if primary else Color("304938"), GOLD, 2))
	node.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 3))
	node.add_theme_stylebox_override("disabled", _style(Color("1b201c"), Color("344438")))
	node.pressed.connect(callback)
	parent.add_child(node)
	var caption_size := 22 if rect.size.y >= 39 and rect.size.x >= 180 else 18
	node.caption = _label(text, Rect2(12, 0, rect.size.x - 24, rect.size.y), node, caption_size, BG if primary else INK, true)
	HanabiTypography.style_label(node.caption, true)
	if primary: node.caption.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	if text.contains("确认返回大厅"): node.variant = "danger"
	var action_icon := HanabiUISkin.action_icon(text)
	if not action_icon.is_empty() and rect.size.x >= 180 and rect.size.y >= 39:
		node.leading_icon = action_icon
		node.caption.position.x = 51
		node.caption.size.x = rect.size.x - 65
	elif text == "Ⅱ":
		node.leading_icon = "pause"
		node.caption.hide()
	return node

func _texture(texture: Texture2D, rect: Rect2, parent: Node, cutout: bool = false) -> TextureRect:
	var node := TextureRect.new()
	node.position = rect.position
	node.size = rect.size
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if texture is AtlasTexture and texture.atlas.resource_path.ends_with("fighters.png"): node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cutout and texture is AtlasTexture and texture.atlas.resource_path.ends_with("lobby.png"):
		node.material = HanabiArtwork.sprite_material()
	parent.add_child(node)
	return node

func _show_screen(next: String) -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var focus_position := previous_focus.position if is_instance_valid(previous_focus) else Vector2(-1, -1)
	var same_page := next == screen
	if is_instance_valid(modal): modal.queue_free()
	modal = null
	modal_return_focus = null
	modal_kind = ""
	if page:
		canvas.remove_child(page)
		page.queue_free()
	page = Control.new()
	page.name = next.capitalize() + "Page"
	page.size = Vector2(1280, 720)
	canvas.add_child(page)
	screen = next
	router.selection_active = next == "characters"
	selection_buttons.clear()
	ready_buttons.clear()
	hud_scores.clear()
	hud_hearts.clear()
	health_meters.clear()
	boom_labels.clear()
	pause_panel = null
	var backdrop := Control.new()
	backdrop.set_script(preload("res://scripts/ui_canvas.gd"))
	backdrop.size = Vector2(1280, 720)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(backdrop)
	match next:
		"lobby": views.build_lobby()
		"setup": views.build_setup()
		"characters": views.build_characters()
		"game": views.build_game()
		"results": views.build_results()
		"codex": views.build_codex()
		"components": views.build_components()
	var buttons := page.find_children("*", "Button", true, false)
	buttons = buttons.filter(func(button): return button.focus_mode != Control.FOCUS_NONE and not button.disabled)
	if next in ["lobby", "results"]: start_button.grab_focus()
	elif next == "characters":
		var selected_button: Button = selection_buttons[ROSTER_ORDER.find(characters[active_slot])]
		if selected_button.disabled:
			if not start_button.disabled: start_button.grab_focus()
		else: selected_button.grab_focus()
	elif same_page and buttons.any(func(button): return button.position == focus_position):
		buttons.filter(func(button): return button.position == focus_position)[0].grab_focus()
	elif not buttons.is_empty(): buttons[0].grab_focus()
	queue_redraw()

func _open_setup() -> void:
	world.reset_to_lobby()
	_show_screen("setup")

func _map_texture(index: int) -> Texture2D:
	return load("res://assets/maps/%s/map.png" % HanabiArenaWorld.MAP_IDS[clampi(index,0,2)])

func _map_preview(index: int, rect: Rect2) -> void:
	if index == 3:
		_rect_panel(rect,page,Color(0.04,0.07,0.06,0.7))
		_icon("random",Rect2(rect.get_center()-Vector2(35,55),Vector2(70,70)),page,MUTED)
		_label("开局时随机确定地图",Rect2(rect.position+Vector2(0,rect.size.y*0.65),Vector2(rect.size.x,30)),page,18,MUTED,true)
		return
	var preview := _texture(_map_texture(index), rect, page)
	preview.name = "MapPreview"
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _set_map(value: int) -> void:
	selected_map = value
	_show_screen("setup")

func _set_seconds(value: int) -> void:
	round_seconds = value
	message = "总时长超过 12 分钟，请减少局数" if round_seconds * round_count > 720 else ""
	_show_screen("setup")

func _set_rounds(value: int) -> void:
	round_count = value
	message = "总时长超过 12 分钟，请缩短每局时长" if round_seconds * round_count > 720 else ""
	_show_screen("setup")

func _set_hearts(value: int) -> void:
	initial_hearts = value
	_show_screen("setup")

func _reset_settings() -> void:
	selected_map = 0
	round_seconds = 150
	round_count = 3
	initial_hearts = 3
	message = ""
	_show_screen("setup")

func _enter_selection() -> void:
	if not session.settings_valid(): return
	message = ""
	session.prepare(router.modes)
	menu_input.bind_turn(router, active_slot)
	known_modes.assign(router.modes)
	known_devices.assign(router.devices)
	_show_screen("characters")

func _set_active(slot: int) -> void:
	if slot != active_slot: return
	_show_screen("characters")

func _select_character(slot: int, character: int) -> void:
	if not router.slot_connected(slot): return
	if not session.select_character(slot, character, router.modes[slot] == "ai"):
		return
	message = ""
	_show_screen("characters")

func _cycle_character(slot: int, direction: int) -> void:
	var index: int = ROSTER_ORDER.find(characters[slot])
	_select_character(slot, ROSTER_ORDER[posmod(index + direction, ROSTER_ORDER.size())])

func _toggle_ready(slot: int) -> void:
	if router.modes[slot] == "ai": return
	if ready_slots[slot]: return
	if not router.slot_connected(slot) or not session.confirm(slot): return
	menu_input.bind_turn(router, active_slot)
	message = ""
	_show_screen("characters")

func _cancel_selection(slot: int) -> void:
	if not session.cancel_ready(slot, router.modes[slot] == "ai"): return
	menu_input.bind_turn(router, active_slot)
	message = "已返回 P%d，后续玩家需依次重新确认" % (slot + 1)
	_show_screen("characters")

func _previous_selection() -> void:
	var previous := session.previous_confirmed()
	if previous < 0: _show_screen("setup")
	else: _cancel_selection(previous)

func _refresh_ready() -> void:
	var count := ready_slots.count(true)
	ready_label.text = "READY  %d / 4" % count
	for slot in range(4):
		ready_buttons[slot].text = "电脑已就绪" if router.modes[slot] == "ai" else "已确认" if ready_slots[slot] else "确认角色" if session.can_select(slot) else "等待前一位"
		ready_buttons[slot].disabled = not session.can_select(slot) or not router.slot_connected(slot)
	for button in selection_buttons:
		button.disabled = not session.can_select(active_slot)
		button.tooltip_text = "所有角色已确认" if button.disabled else "仅更新当前玩家 P%d" % (active_slot + 1)
	start_button.disabled = count != 4 or not router.all_connected()
	start_button.text = "开始对局" if not start_button.disabled else "等待设备连接" if count == 4 else "等待 P%d 确认" % (active_slot + 1)
	start_button.tooltip_text = "全员确认后自动开场" if not start_button.disabled else "需按 P1 → P2 → P3 → P4 依次确认"
	if page.has_node("SelectionTurn"):
		page.get_node("SelectionTurn").text = _selection_hint()
	session.schedule_launch(router.all_connected())

func _selection_hint() -> String:
	if session.can_select(active_slot) and menu_input.waiting_neutral[active_slot]:
		return "当前轮到 P%d · 请先松开十字键并将摇杆回中，再选择角色" % (active_slot + 1)
	return message if not message.is_empty() else "全部确认 · 即将开始" if ready_slots.count(true) == 4 else "当前轮到 P%d  ·  确认后下一位才能选择" % (active_slot + 1)

func _devices_changed() -> void:
	if screen == "characters":
		var connected: PackedInt32Array = router.connection_reader.call() if router.connection_reader.is_valid() else Input.get_connected_joypads()
		var first_changed := 4
		for slot in range(4):
			if router.modes[slot] != known_modes[slot] or router.devices[slot] != known_devices[slot] or (router.modes[slot] == "pad" and router.devices[slot] not in connected):
				first_changed = mini(first_changed, slot)
		if first_changed < 4:
			session.invalidate_from(first_changed, router.modes)
			menu_input.bind_turn(router, active_slot)
			message = "设备发生变化，请从 P%d 依次确认" % (first_changed + 1)
		_show_screen("characters")
	elif screen == "lobby" and not is_instance_valid(modal): _show_screen("lobby")
	known_modes.assign(router.modes)
	known_devices.assign(router.devices)

func _start(is_demo: bool = false, automatic: bool = false) -> void:
	if world.state != "lobby": return
	if not session.settings_valid(): return
	if not is_demo and (not router.all_connected() or ready_slots.count(true) != 4): return
	world.rules.match_seconds = round_seconds * round_count
	world.rules.round_seconds = round_seconds
	world.rules.rounds = round_count
	world.rules.hearts = initial_hearts
	world.load_map(randi_range(0,2) if selected_map == 3 else selected_map)
	_frame_map()
	for slot in range(4):
		world.fighters[slot].set_character(characters[slot])
		world.fighters[slot].nickname = HanabiArtwork.CHARACTER_NAMES[characters[slot]]
	result_recorded = false
	world.start_match(is_demo)
	if automatic: world.phase_time = 0.05
	session.launch_remaining = -1.0
	mouse_aim_active = false
	router.keyboard_aim = Vector2.ZERO
	_show_screen("game")
	if get_viewport().gui_get_focus_owner(): get_viewport().gui_get_focus_owner().release_focus()

func _toggle_pause() -> void:
	if screen != "game" or is_instance_valid(modal): return
	if world.state == "paused":
		if router.all_connected() or world.demo: world.resume_match()
		else: world.pause_reason = "手柄尚未连接，请接回后继续"
	else: world.set_paused()

func _on_match_finished() -> void:
	if not world.demo and not result_recorded:
		store.add(world, router)
		result_recorded = true
	_show_screen("results")

func _replay() -> void:
	world.reset_to_lobby()
	_enter_selection()

func _return_lobby() -> void:
	world.reset_to_lobby()
	session.launch_remaining = -1.0
	message = ""
	_show_screen("lobby")

func _begin_modal(opacity: float = 0.72) -> bool:
	if is_instance_valid(modal): return false
	modal_return_focus = get_viewport().gui_get_focus_owner()
	if screen == "game": world.set_paused("查看菜单中")
	modal = Control.new()
	modal.size = Vector2(1280, 720)
	canvas.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, opacity)
	shade.size = Vector2(1280, 720)
	modal.add_child(shade)
	return true

func _open_modal(title: String, text: String) -> void:
	if not _begin_modal(): return
	_panel(Rect2(275, 115, 730, 478), modal, Color("142018"))
	_panel(Rect2(298, 145, 4, 38), modal, GOLD, Color.TRANSPARENT)
	_title(title, Rect2(319, 141, 454, 40), modal)
	_label("LOCAL ARENA  /  MENU", Rect2(320, 185, 620, 18), modal, 10, MUTED)
	modal_text = _label(text, Rect2(310, 202, 661, 303), modal, 18)
	modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_button("关闭  /  Esc", Rect2(756, 523, 212, 44), modal, _close_modal, true).grab_focus()

func _close_modal() -> void:
	if not is_instance_valid(modal): return
	canvas.remove_child(modal)
	modal.queue_free()
	modal = null
	modal_kind = ""
	if screen == "lobby":
		modal_return_focus = null
		_show_screen("lobby")
		return
	if screen == "game" and is_instance_valid(pause_panel):
		pause_panel.show()
		pause_panel.find_children("*", "Button", true, false)[0].grab_focus()
	elif is_instance_valid(modal_return_focus): modal_return_focus.grab_focus()
	modal_return_focus = null

func _show_help() -> void:
	if is_instance_valid(modal): return
	modal_kind = "help"
	_open_modal("操作说明", "选角依次进行：P1 确认后，才轮到 P2、P3、P4。\n左右 / 摇杆选择，空格 / A 确认，Q / B 返回；Y 设备。\n键盘 2：方向键选择，Enter 确认，Backspace 返回。\n改选或断连后，从该席位重新依次确认；电脑自动就绪。\n全员确认后 3 秒开场。\n\n手柄：左摇杆轻推行走、推满奔跑；A 远程攻击，B 冲刺，X 近战。\n键盘 1：WASD 移动，R 奔跑；鼠标瞄准，空格 / 左键投掷，Shift / 右键冲刺，E 近战。\n键盘 2：方向键移动，小键盘 0 奔跑，Enter 投掷，Ctrl 冲刺，斜杠近战。\n\n攻击第 3 帧出手；受击或冲刺可打断攻击准备。\nGPT 按住 A / 空格 / 左键 / Enter 喷火，接触扣 1 颗血，持续接触按间隔再扣 1 颗；离开火焰停止扣血。\nDeepSeek 再按攻击召回飞刀，往返均可命中。\nClaude 可弹射三次；GLM 碰墙留下毒泽。\nEve 狙击穿墙；酒狐单弹碰墙分成三颗子弹。\n击倒 +1 分，小局存活 +3 分；积分累计。\nP / Start 暂停，F 全屏；断连和窗口失焦自动暂停。")
	modal_text.add_theme_font_size_override("font_size", 15)

func _show_settings() -> void:
	if not _begin_modal(0.34): return
	modal_kind = "settings"
	_acrylic_card(Rect2(264, 96, 752, 532), modal)
	_title("游戏设置", Rect2(304, 118, 480, 46), modal)
	_label("游戏设置", Rect2(307, 171, 110, 25), modal, 15, INK)
	_label("调整立即生效，保存后下次启动沿用。", Rect2(430, 171, 530, 25), modal, 14, MUTED)
	_rect_panel(Rect2(304, 208, 656, 1), modal, Color(0.8, 0.9, 0.9, 0.10))
	_label("声音", Rect2(304, 224, 500, 27), modal, 18)
	_rect_panel(Rect2(304, 260, 656, 61), modal, Color(0.02, 0.025, 0.028, 0.43))
	var toggle := _switch("游戏音效", Rect2(315, 268, 627, 44), modal, sound.enabled, func(enabled):
		sound.enabled = enabled
		sound.play_effect("catch")
		_settings_update_status())
	toggle.name = "SoundSwitch"
	_rect_panel(Rect2(304, 329, 656, 61), modal, Color(0.02, 0.025, 0.028, 0.43))
	_label("音量", Rect2(328, 343, 154, 32), modal, 18)
	var volume_label := _label("%d%%" % roundi(sound.volume * 100), Rect2(865, 343, 77, 32), modal, 18, INK, true)
	volume_label.name = "SettingsVolumeValue"
	var slider := _slider(Rect2(500, 343, 344, 32), modal, sound.volume, func(value):
		sound.volume = value
		volume_label.text = "%d%%" % roundi(value * 100)
		_settings_update_status())
	slider.name = "VolumeSlider"
	_label("显示", Rect2(304, 411, 500, 27), modal, 18)
	_rect_panel(Rect2(304, 445, 656, 61), modal, Color(0.02, 0.025, 0.028, 0.43))
	_label("显示模式", Rect2(328, 459, 154, 32), modal, 18)
	var display := OptionButton.new()
	display.name = "SettingsDisplayMode"
	display.position = Vector2(548, 454)
	display.size = Vector2(390, 42)
	display.add_item("窗口化")
	display.add_item("全屏")
	display.select(1 if window_fullscreen else 0)
	display.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "focus"]:
		display.add_theme_stylebox_override(state, _style(Color(0.07, 0.08, 0.09, 0.70), GOLD if state == "focus" else Color(0.38, 0.43, 0.45, 0.46)))
	display.get_popup().add_theme_stylebox_override("panel", _style(Color("111619"), LINE))
	display.get_popup().add_theme_stylebox_override("hover", _style(Color("26322a"), GOLD))
	display.get_popup().add_theme_color_override("font_color", INK)
	display.item_selected.connect(func(index):
		_apply_display_mode(index == 1)
		_settings_update_status())
	modal.add_child(display)
	_rect_panel(Rect2(304, 530, 656, 1), modal, Color(0.8, 0.9, 0.9, 0.10))
	_label("", Rect2(304, 550, 288, 44), modal, 14, MUTED).name = "SettingsStatus"
	_rect_button("返回 / Esc", Rect2(610, 550, 132, 44), modal, _close_modal).name = "SettingsBack"
	_rect_button("保存设置", Rect2(758, 550, 202, 44), modal, _save_settings, true).name = "SettingsSave"
	var controls: Array[Control] = [toggle, slider, display, modal.get_node("SettingsBack"), modal.get_node("SettingsSave")]
	for index in range(controls.size()):
		var previous := controls[index].get_path_to(controls[(index + controls.size() - 1) % controls.size()])
		var next := controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = previous
		controls[index].focus_next = next
		controls[index].focus_neighbor_top = previous
		controls[index].focus_neighbor_bottom = next
		controls[index].focus_neighbor_left = previous
		controls[index].focus_neighbor_right = next
	_settings_update_status()
	toggle.grab_focus()

func _acrylic_card(rect: Rect2, parent: Node, prefix: String = "Settings", capture_background: bool = true) -> void:
	# Copy the dimmed scene before the glass and controls, so foreground text stays sharp.
	if capture_background:
		var copy := BackBufferCopy.new()
		copy.name = prefix + "BackdropCopy"
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		parent.add_child(copy)
	var frost := ColorRect.new()
	frost.name = prefix + "Acrylic"
	frost.position = rect.position
	frost.size = rect.size
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://assets/ui/shaders/acrylic.gdshader")
	frost.material = glass
	parent.add_child(frost)
	var card := _rect_panel(rect, parent, Color.TRANSPARENT, Color(0.67, 0.73, 0.75, 0.28))
	card.name = prefix + "Card"
	# A restrained top edge catches light without adding decorative symbols.
	_rect_panel(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 1)), parent, Color(0.90, 0.94, 0.95, 0.16))

func _rect_panel(rect: Rect2, parent: Node, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", _style(color, border, 1 if border.a > 0 else 0))
	parent.add_child(node)
	return node

func _rect_button(text: String, rect: Rect2, parent: Node, callback: Callable, primary: bool = false) -> HanabiSlantButton:
	var node: HanabiSlantButton = _button(text, rect, parent, callback, primary)
	node.kind = "rect"
	node.lean_override = 0
	node.leading_icon = ""
	node.fill = Color(0.06, 0.07, 0.08, 0.78)
	node.accent = Color(0.42, 0.47, 0.48, 0.55)
	node.caption.position.x = 12
	node.caption.size.x = rect.size.x - 24
	return node

func _settings_values() -> Dictionary:
	return {"sound_enabled":sound.enabled, "volume":sound.volume, "fullscreen":window_fullscreen}

func _settings_update_status() -> void:
	if modal_kind != "settings" or not is_instance_valid(modal) or not modal.has_node("SettingsSave"): return
	var saved := settings_store.has_saved and settings_store.matches(_settings_values())
	var status: Label = modal.get_node("SettingsStatus")
	status.text = "设置已保存" if saved else "有未保存的更改" if settings_store.has_saved else "点击保存，保留下次启动设置"
	status.add_theme_color_override("font_color", MUTED if saved else INK)
	var save: HanabiSlantButton = modal.get_node("SettingsSave")
	var had_focus := save.has_focus()
	save.disabled = saved
	save.text = "已保存" if saved else "保存设置"
	if saved and had_focus: modal.get_node("SettingsBack").grab_focus()

func _save_settings() -> Error:
	if modal_kind != "settings" or not is_instance_valid(modal): return ERR_UNAVAILABLE
	var error := settings_store.save_values(_settings_values())
	if error == OK: _settings_update_status()
	else:
		var status: Label = modal.get_node("SettingsStatus")
		status.text = "保存失败，请重试"
		status.add_theme_color_override("font_color", Color("e49c90"))
	return error

func _apply_display_mode(fullscreen: bool) -> void:
	window_fullscreen = fullscreen
	if not qa_mode and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _switch(text: String, rect: Rect2, parent: Node, value: bool, callback: Callable) -> HanabiUISwitch:
	var node := HanabiUISwitch.new()
	node.position = rect.position
	node.size = rect.size
	node.text = text
	node.button_pressed = value
	node.toggled.connect(callback)
	parent.add_child(node)
	return node

func _slider(rect: Rect2, parent: Node, value: float, callback: Callable) -> HSlider:
	var node := HanabiUISlider.new()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.position = rect.position
	node.size = rect.size
	node.min_value = 0
	node.max_value = 1
	node.step = 0.05
	node.value = value
	for state in ["slider", "grabber_area", "grabber_area_highlight"]:
		var rail := _style(Color("14231e") if state == "slider" else GOLD, Color("09110e") if state == "slider" else Color("82952a"), 1)
		rail.border_width_top = 2
		rail.border_width_bottom = 1
		rail.content_margin_top = 3
		rail.content_margin_bottom = 3
		rail.content_margin_left = 0
		rail.content_margin_right = 0
		node.add_theme_stylebox_override(state, rail)
	for entry in [["grabber", "normal"], ["grabber_highlight", "hover"], ["grabber_disabled", "disabled"]]:
		node.add_theme_icon_override(entry[0], HanabiUISkin.texture("components/slider_thumb_%s.svg" % entry[1]))
	node.value_changed.connect(callback)
	parent.add_child(node)
	return node

func _toggle_sound() -> void:
	sound.enabled = not sound.enabled
	sound.play_effect("catch")
	_close_modal()
	_show_settings()

func _show_history() -> void:
	var rows: Array[String] = []
	for index in range(mini(4, store.records.size())):
		var record: Dictionary = store.records[index]
		rows.append("%s  ·  %d 秒" % [record.date, record.seconds])
		var seats: Array[String] = []
		for entry in record.ranking: seats.append("P%d %s %d分" % [entry.slot, entry.name, entry.score])
		rows.append(" / ".join(seats))
	_open_modal("比赛记录", "\n\n".join(rows) if not rows.is_empty() else "还没有比赛记录。完成第一场对局后将在本机保存。")

func _confirm_leave() -> void:
	_open_modal("返回大厅？", "当前对局将结束。\n可以取消并继续游戏。")
	_button("确认返回大厅", Rect2(309, 356, 263, 48), modal, _return_lobby)

func _fullscreen() -> void:
	_apply_display_mode(not window_fullscreen)
	if modal_kind == "settings" and is_instance_valid(modal):
		modal.get_node("SettingsDisplayMode").select(1 if window_fullscreen else 0)
		_settings_update_status()

func _back() -> void:
	if is_instance_valid(modal): _close_modal(); return
	match screen:
		"setup", "results", "codex", "components": _return_lobby()
		"characters": _show_screen("setup")
		"game": _toggle_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(world) and not qa_mode:
		world.set_paused("窗口失去焦点，请确认后继续")

func _process(delta: float) -> void:
	if screen == "characters" and not is_instance_valid(modal):
		var device_menu_open := _selection_popup_open()
		if session.can_select(active_slot):
			if device_menu_open: menu_input.suspend_sticks(router, active_slot)
			else:
				for action in menu_input.poll_sticks(router, delta, active_slot): _selection_action(action)
			if page.has_node("SelectionTurn"): page.get_node("SelectionTurn").text = _selection_hint()
		if session.launch_remaining >= 0.0 and not device_menu_open:
			if not router.all_connected():
				session.launch_remaining = -1.0
				message = "手柄连接已变化，请重新准备"
			else:
				session.launch_remaining -= delta
				page.get_node("SelectionTurn").text = "全部确认 · %d 秒后开场 · B / Q 可返回" % ceili(session.launch_remaining)
				if session.launch_remaining <= 0.0: _start(false, true)
	if screen == "game":
		time_label.text = _clock(ceili(world.leg_remaining()))
		round_label.text = "ROUND %d / %d" % [world.match_leg, world.rules.rounds]
		for slot in range(4):
			var fighter: HanabiFighter = world.fighters[slot]
			hud_scores[slot].text = str(fighter.score).pad_zeros(2)
			health_meters[slot].value = fighter.hp
			health_meters[slot].maximum = world.rules.hearts
			health_meters[slot].cooldown = clampf(fighter.dash_cooldown / world.rules.dash_cooldown, 0.0, 1.0)
			boom_labels[slot].text = "本小局出局" if not fighter.alive else "受击硬直" if fighter.action_state == &"hurt" else "攻击准备" if fighter.pending_attack != "" else "返程中" if is_instance_valid(fighter.active_boom) and fighter.active_boom.returning else "飞行中 · 再按召回" if is_instance_valid(fighter.active_boom) else "停喷中" if is_instance_valid(fighter.active_flame) and fighter.active_flame.stopping else "龙炎喷射中" if is_instance_valid(fighter.active_flame) else "奔跑中" if fighter.action_state == &"run" else "按住攻击 · 龙炎" if fighter.character_id == 0 else "远程就绪"
			if router.modes[slot] == "key1" and mouse_aim_active: router.keyboard_aim = (mouse_target - fighter.position).normalized()
		phase_label.text = str(ceili(world.phase_time)) if world.state == "countdown" else ("VICTORY" if world.winner else "DRAW") if world.state == "roundover" else ""
		var show_pause := world.state == "paused"
		if show_pause and not pause_panel.visible:
			pause_panel.show()
			if not is_instance_valid(modal): pause_panel.find_children("*", "Button", true, false)[0].grab_focus()
		elif not show_pause: pause_panel.hide()
		pause_panel.get_node("PauseReason").text = world.pause_reason
	qa_clock += delta
	var capture_delay := 7.0 if capture_screen.begins_with("map-") and not capture_screen.ends_with("-setup") and not capture_screen.ends_with("-pause") else 5.0 if capture_screen == "game" else 1.0
	if not capture_path.is_empty() and not qa_pending and qa_clock > capture_delay:
		qa_pending = true
		_capture()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var output := get_viewport().get_texture().get_image()
	var error := output.save_png(capture_path)
	print("CAPTURE ", screen, " ", capture_path, " error=", error)
	get_tree().quit(0 if error == OK else 1)

func _clock(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 60, seconds % 60]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)

func _title(text: String, rect: Rect2, parent: Node) -> void:
	var texture := HanabiUISkin.wordmark(text)
	if not texture: texture = HanabiArtwork.title_texture(text)
	if texture:
		var title := _texture(texture, rect, parent)
		title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	else: _label(text, rect, parent, 39)

func _icon(name: String, rect: Rect2, parent: Node, color: Color = INK) -> TextureRect:
	var extent := maxf(40.0, floorf(minf(rect.size.x, rect.size.y) / 40.0) * 40.0)
	var target := Rect2((rect.position + (rect.size - Vector2.ONE * extent) / 2).round(), Vector2.ONE * extent)
	var node := HanabiUIIcon.new()
	node.icon_name = name
	node.position = target.position
	node.size = target.size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	if name not in HanabiUISkin.IVORY_ICONS: node.modulate = color
	return node

func _device_option(slot: int, rect: Rect2) -> void:
	var option := OptionButton.new()
	option.position = rect.position
	option.size = rect.size
	option.name = "SeatDevice%d" % slot
	option.add_theme_font_size_override("font_size", 12)
	option.add_theme_color_override("font_color", INK)
	option.add_theme_stylebox_override("normal", _style(PANEL, LINE))
	option.add_theme_stylebox_override("hover", _style(Color("2a3a33"), GOLD))
	option.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 2))
	option.add_theme_stylebox_override("pressed", _style(Color("2a3a33"), GOLD))
	option.get_popup().add_theme_color_override("font_color", INK)
	option.get_popup().add_theme_stylebox_override("panel", _style(PANEL, LINE))
	option.get_popup().add_theme_stylebox_override("hover", _style(Color("263a32"), GOLD))
	option.get_popup().add_theme_color_override("font_hover_color", INK)
	var modes: Array = [["电脑陪练", "ai", -1], ["键盘 1 · WASD / 鼠标", "key1", -1], ["键盘 2 · 方向键", "key2", -1]]
	var connected: PackedInt32Array = router.connection_reader.call() if router.connection_reader.is_valid() else Input.get_connected_joypads()
	for device in connected: modes.append(["手柄 %d" % (device + 1), "pad", device])
	for entry in modes:
		option.add_item(entry[0])
		option.set_item_metadata(option.item_count - 1, entry)
		if router.modes[slot] == entry[1] and router.devices[slot] == entry[2]: option.select(option.item_count - 1)
	option.item_selected.connect(func(index):
		var entry = option.get_item_metadata(index)
		router.set_mode(slot, entry[1], entry[2]))
	page.add_child(option)

func _selection_action(action: Dictionary) -> void:
	match action.action:
		"select": _cycle_character(action.slot, action.direction)
		"device":
			if session.can_select(action.slot):
				var option := page.get_node("SeatDevice%d" % action.slot) as OptionButton
				menu_input.suspend_sticks(router, active_slot)
				option.show_popup()
		"ready": _toggle_ready(action.slot)
		"cancel":
			if ready_slots[action.slot]: _cancel_selection(action.slot)
			elif session.can_select(action.slot): _previous_selection()
		"start":
			if not start_button.disabled: _start(false)

func _selection_popup_open() -> bool:
	if not is_instance_valid(page): return false
	for option in page.find_children("SeatDevice*", "OptionButton", false, false):
		if option.get_popup().visible: return true
	return false

func _input(event: InputEvent) -> void:
	# Release outside the field / during a modal must still end mouse-held flame.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		router.mouse_throw_held = false
	if screen == "characters" and not is_instance_valid(modal):
		if _selection_popup_open():
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				if router.modes[active_slot] != "pad" or event.device != router.devices[active_slot]: get_viewport().set_input_as_handled()
			return
		var focused := get_viewport().gui_get_focus_owner()
		if focused is OptionButton and event is InputEventKey and event.is_action_pressed("ui_accept") and menu_input.decode(event, router).is_empty(): return
	if event is InputEventKey and event.is_action("ui_accept") and screen == "game" and world.state == "playing" and not is_instance_valid(modal):
		# Space / Enter still reach the combat tap buffer, but cannot activate
		# a menu button that retained focus while entering or resuming a match.
		router._input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion and not is_instance_valid(modal) and (screen == "characters" or (screen == "game" and world.state == "playing")):
		if screen == "characters" and session.can_select(active_slot):
			var action := menu_input.stick_event(event, router, active_slot)
			if not action.is_empty(): _selection_action(action)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and screen == "game" and world.state == "playing" and not is_instance_valid(modal) and event.button_index != JOY_BUTTON_START:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F:
			_fullscreen()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE:
			_back()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_P and screen == "game":
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
	if screen == "characters" and not is_instance_valid(modal):
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER and "key2" not in router.modes and not start_button.disabled:
			_start(false)
			get_viewport().set_input_as_handled()
			return
		var action := menu_input.decode(event, router)
		if not action.is_empty():
			_selection_action(action)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START and screen == "game": _toggle_pause()
		elif event.button_index == JOY_BUTTON_B and (screen != "game" or world.state == "paused"): _back()
	if screen == "game" and world.state == "playing" and not is_instance_valid(modal):
		if event is InputEventMouseMotion or event is InputEventMouseButton:
			var point: Vector2 = arena_view.get_global_transform().affine_inverse() * event.position
			var hud_point := point / arena_view.size * Vector2(1280,720)
			var over_hud := Rect2(10,7,1260,59).has_point(hud_point) or Rect2(160,674,960,40).has_point(hud_point)
			var in_arena := Rect2(Vector2.ZERO, arena_view.size).has_point(point) and not over_hud
			var target := world.combat_from_canvas(point / arena_view.size * Vector2(subviewport.size))
			if in_arena and world.field.has_point(target):
				mouse_target = target
				mouse_aim_active = true
				if event is InputEventMouseButton and event.pressed:
					if event.button_index == MOUSE_BUTTON_LEFT:
						router.mouse_throw_tap = true
						router.mouse_throw_held = true
					if event.button_index == MOUSE_BUTTON_RIGHT: router.mouse_dash_tap = true

func _show_codex() -> void:
	_show_screen("codex")

func _inspect_character(index: int) -> void:
	active_slot = 0
	_open_modal(HanabiArtwork.CHARACTER_CODES[index], ["按住攻击持续喷射龙炎，松开停喷。碰到火焰扣 1 颗血，持续接触每 0.75 秒再扣 1 颗。离开停止扣血，火苗仅为视觉效果；墙体可遮挡。", "单颗魔法光弹，最多三次墙面弹射；第三次后继续飞行，第四次碰墙终止。", "飞餐刀出程后自动回旋，也可再按攻击手动召回；往返均可命中。", "高速狙击子弹穿过障碍物；默认命中一名对手后终止。", "毒气弹碰障碍物转为固定毒泽，持续造成区域伤害后消退。", "每次一颗光弹，碰墙分成三颗独立子弹；子弹默认不再次分裂。"][index])
	_texture(HanabiArtwork.face(index), Rect2(694, 212, 241, 225), modal)

func _quit() -> void:
	sound.enabled = false
	get_tree().quit()


