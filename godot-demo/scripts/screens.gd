extends RefCounted
class_name HanabiScreens

var app

func _init(controller) -> void:
	app = controller

func header(title: String, subtitle: String, stage: int = -1) -> void:
	app._panel(Rect2(31, 26, 3, 60), app.page, app.GOLD, Color.TRANSPARENT)
	app._title(title, Rect2(49, 27, 636, 61), app.page)
	app._label(title + "   /   LOCAL ARENA PROJECT", Rect2(52, 96, 615, 19), app.page, 12, app.MUTED)
	app.page.set_meta("english_title", subtitle)
	if stage >= 0:
		for index in range(3):
			var x: float = 718 + index * 174
			app._panel(Rect2(x, 41, 166, 34), app.page, app.GOLD if index == stage else Color(0.08, 0.13, 0.11, 0.4))
			app._label(["01 对局设置", "02 角色选择", "03 开始对局"][index], Rect2(x + 7, 41, 150, 34), app.page, 15, app.BG if stage == index else app.MUTED, true)

func footer(back: Callable, text: String = "Enter / A 确认    Esc / B 返回    F 全屏") -> void:
	app._button("← 返回大厅", Rect2(24, 674, 146, 31), app.page, back)
	key_hint("A", "确认", Vector2(765, 674), app.page)
	key_hint("B", "返回", Vector2(925, 674), app.page)
	app._label("F 全屏", Rect2(1100, 674, 144, 29), app.page, 12, app.MUTED, true)
	app.page.tooltip_text = text

func key_hint(key: String, title: String, position: Vector2, parent: Node, width: float = 129) -> void:
	var glyph_key := "menu" if key == "START" else key.to_lower()
	if glyph_key in HanabiGamepadPrompt.KEYS:
		var glyph := HanabiGamepadPrompt.new()
		glyph.key_name = glyph_key
		glyph.app = app
		glyph.action_id = "move" if title.begins_with("移动") else "throw" if title.contains("投掷") else "dash" if title == "冲刺" else "slash" if title == "近战" else "pause" if title == "暂停" else "confirm" if title == "确认" else ""
		glyph.position = position + Vector2(5, 0)
		glyph.size = Vector2(32, 32)
		glyph.set_meta("hint_key", key)
		parent.add_child(glyph)
		if not title.is_empty(): app._label(title, Rect2(position + Vector2(44, 0), Vector2(width - 44, 32)), parent, 14, app.INK)
		return
	var skin := HanabiUISkin.texture("components/keycap_" + key.to_lower() + ".svg")
	var keycap: TextureRect = app._texture(skin, Rect2(position, Vector2(42, 26)), parent)
	keycap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	app._label(key, Rect2(position, Vector2(42, 26)), parent, 12, app.INK, true)
	app._label(title, Rect2(position + Vector2(50, 0), Vector2(width - 50, 26)), parent, 13, app.INK)

func section(title: String, icon: String, rect: Rect2) -> void:
	app._icon(icon, Rect2(rect.position, Vector2(25, 25)), app.page, app.MUTED)
	app._label(title, Rect2(rect.position + Vector2(35, -2), rect.size - Vector2(35, 0)), app.page, 20)

func metric(title: String, value: String, icon: String, rect: Rect2, parent: Node, color: Color = Color("edf0eb")) -> void:
	app._icon(icon, Rect2(rect.position + Vector2(0, 4), Vector2(22, 22)), parent, app.MUTED)
	app._label(title, Rect2(rect.position + Vector2(32, 0), Vector2(rect.size.x * 0.60, rect.size.y)), parent, 17)
	app._label(value, Rect2(rect.position + Vector2(rect.size.x - 100, 0), Vector2(89, rect.size.y)), parent, 25, color, true)

func art_card(title: String, subtitle: String, rect: Rect2, character: int, callback: Callable, number: String, primary: bool = false, _banner: int = -1) -> Button:
	var button: HanabiSlantButton = app._button("", rect, app.page, callback, false, app.GOLD if primary else app.LINE)
	button.kind = "menu"
	if title == "本地对战": button.icon_name = "controller"
	elif title == "电脑演示": button.icon_name = "play"
	button.lean_override = minf(67, rect.size.y * 0.30)
	button.selected = primary
	var lobby_art := title in ["本地对战", "电脑演示", "角色图鉴"]
	var data: Dictionary = {}
	if lobby_art:
		HanabiMenuIllustrations.apply(button, int(number) - 1)
		data = HanabiMenuIllustrations.card(int(number) - 1)
	else:
		button.art = HanabiArtwork.hero_texture(character)
		button.art_uv = HanabiArtwork.hero_uv(character, rect.size.x / rect.size.y)
		button.shade = 0.05 if primary else 0.18
	var label_x := button.lean_override * 0.3 + 11
	var overrides: Dictionary = data.get("title_override", {})
	var panel_rect := HanabiMenuIllustrations.rectangle(overrides.panel_rect) if not overrides.is_empty() else Rect2(label_x, rect.size.y - 80, minf(rect.size.x - 90, 226), 61)
	var accent_rect := HanabiMenuIllustrations.rectangle(overrides.accent_rect) if not overrides.is_empty() else Rect2(label_x + 15, rect.size.y - 72, 3, 45)
	var english_rect := HanabiMenuIllustrations.rectangle(overrides.english_rect) if not overrides.is_empty() else Rect2(label_x + 30, rect.size.y - 69, 187, 28)
	var chinese_rect := HanabiMenuIllustrations.rectangle(overrides.chinese_rect) if not overrides.is_empty() else Rect2(label_x + 31, rect.size.y - 36, 187, 17)
	app._panel(panel_rect, button, Color(0.03, 0.06, 0.05, 0.92), Color.TRANSPARENT).name = "TitlePlate"
	app._panel(accent_rect, button, app.GOLD, Color.TRANSPARENT).name = "TitleAccent"
	app._title(title, english_rect, button)
	button.get_child(button.get_child_count() - 1).name = "EnglishTitle"
	var chinese: Label = app._label(title if HanabiUISkin.wordmark(title) else subtitle, chinese_rect, button, 10 if not overrides.is_empty() else 11, Color("aebfb4"))
	chinese.name = "ChineseSubtitle"
	# Apply the final rectangle after font/theme setup; Label's initial default
	# minimum height otherwise expands this 14-unit subtitle to 23 units.
	if not overrides.is_empty(): chinese.size = chinese_rect.size
	# Separate nearest-filtered icon node: illustration's Linear filter must not
	# soften the pixel icons or their hover/press variants.
	if lobby_art:
		var corner := button.points()[2]
		app._icon(button.icon_name if not button.icon_name.is_empty() else "fighters", Rect2(corner - Vector2(56, 53), Vector2(40, 40)), button).name = "MenuIcon"
	app._panel(Rect2(button.lean_override + 3, 4, 69, 49), button, app.GOLD if primary else Color("c8cec7"), Color.TRANSPARENT)
	app._label(number, Rect2(button.lean_override + 8, 4, 58, 47), button, 37, app.BG, true)
	return button

func build_lobby() -> void:
	app._panel(Rect2(35, 17, 3, 32), app.page, app.GOLD, Color.TRANSPARENT)
	app._label("LOCAL ARENA PROJECT", Rect2(49, 15, 466, 22), app.page, 12, app.MUTED)
	app._label("回旋竞技计划", Rect2(50, 37, 430, 19), app.page, 10, app.MUTED)
	var brand_top: TextureRect = app._texture(HanabiUISkin.texture("titles-en/brand_top.svg"), Rect2(29, 85, 509, 83), app.page)
	brand_top.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	brand_top.name = "BrandBoomerang"
	var brand_bottom: TextureRect = app._texture(HanabiUISkin.texture("titles-en/brand_bottom.svg"), Rect2(17, 177, 472, 123), app.page)
	brand_bottom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	brand_bottom.modulate = app.GOLD
	brand_bottom.name = "BrandBrawl"
	app._label("1—4 PLAYER LOCAL COMBAT", Rect2(39, 315, 479, 26), app.page, 15, app.INK)
	app._panel(Rect2(40, 350, 445, 1), app.page, Color("608e8055"), Color.TRANSPARENT)
	app._panel(Rect2(46, 435, 3, 143), app.page, app.GOLD, Color.TRANSPARENT)
	for index in range(3):
		app._texture(HanabiUISkin.texture("titles-en/slogan_%d.svg" % (index + 1)), Rect2(62, 435 + index * 48, 258, 39), app.page).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	app._label("1—4 人本地同屏", Rect2(61, 586, 410, 25), app.page, 16, app.MUTED)
	app.start_button = art_card("本地对战", "LOCAL BATTLE", Rect2(624, 58, 632, 216), 0, app._open_setup, "01", true, 0)
	art_card("电脑演示", "AUTO BATTLE", Rect2(586, 286, 650, 190), 2, app._start.bind(true), "02", false, 1)
	var archive: HanabiSlantButton = art_card("角色图鉴", "CHARACTERS", Rect2(548, 490, 360, 144), 4, app._show_codex, "03")
	archive.icon_name = "fighters"
	var settings: HanabiSlantButton = app._button("", Rect2(920, 490, 290, 144), app.page, app._show_settings)
	settings.kind = "menu"
	settings.name = "Menu4"
	settings.lean_override = 38
	settings.icon_name = "settings"
	app._panel(Rect2(37, 3, 62, 39), settings, Color("c8cec7"), Color.TRANSPARENT)
	app._label("04", Rect2(45, 3, 50, 39), settings, 31, app.BG, true)
	app._panel(Rect2(11, 73, 184, 55), settings, Color("09100fec"), Color.TRANSPARENT)
	app._panel(Rect2(25, 83, 3, 35), settings, app.GOLD, Color.TRANSPARENT)
	app._title("游戏设置", Rect2(38, 79, 141, 24), settings)
	app._label("音效 · 显示", Rect2(38, 106, 139, 16), settings, 10, app.MUTED)
	app._panel(Rect2(26, 640, 776, 60), app.page, Color(0.06, 0.1, 0.09, 0.79))
	app._texture(HanabiArtwork.sprite_texture(app.characters[0]), Rect2(34, 641, 57, 57), app.page)
	app._label("本地玩家", Rect2(98, 645, 137, 24), app.page, 15)
	app._label("LOCAL PLAYER", Rect2(98, 670, 137, 16), app.page, 9, app.MUTED)
	for slot in range(4):
		var x: float = 242 + slot * 107
		app._icon("keyboard" if app.router.modes[slot].begins_with("key") else "controller", Rect2(x, 650, 29, 27), app.page, HanabiArtwork.COLORS[slot])
		app._label("P%d" % (slot + 1), Rect2(x + 33, 650, 35, 27), app.page, 15, HanabiArtwork.COLORS[slot])
		app._label("电脑" if app.router.modes[slot] == "ai" else "键盘" if app.router.modes[slot].begins_with("key") else "手柄", Rect2(x, 678, 75, 14), app.page, 9, app.MUTED, true)
	app._button("操作说明", Rect2(826, 675, 123, 28), app.page, app._show_help)
	app._button("比赛记录", Rect2(955, 675, 124, 28), app.page, app._show_history)
	app._button("退出", Rect2(1085, 675, 130, 28), app.page, app._quit)
	app._icon("offline", Rect2(1053, 9, 38, 34), app.page, app.MUTED)
	app._label("本地同屏", Rect2(1103, 13, 144, 23), app.page, 15, app.MUTED)
	app._label("OFFLINE PLAY", Rect2(1104, 36, 143, 12), app.page, 9, app.MUTED)
	# Explicit directional neighbors keep the slanted card geometry from making
	# native Godot focus search jump diagonally to a footer action.
	var cards: Array[Control] = [app.page.get_node("Menu1"),app.page.get_node("Menu2"),archive,settings]
	for edge in [[0,"bottom",1],[1,"top",0],[1,"bottom",2],[2,"top",1],[2,"right",3],[3,"left",2],[3,"top",1]]:
		cards[edge[0]].set("focus_neighbor_" + edge[1],cards[edge[0]].get_path_to(cards[edge[2]]))

func build_setup() -> void:
	header("对局设置", "MATCH SETUP", 0)
	section("地图选择", "map", Rect2(39, 135, 536, 31))
	for index in range(4):
		var x: float = 36 + index % 2 * 263
		var y: float = 174 + int(index / 2) * 143
		var card: HanabiSlantButton = app._button("", Rect2(x, y, 250, 128), app.page, app._set_map.bind(index), false, app.GOLD if app.selected_map == index else app.LINE)
		card.name = "MapCard%d" % index
		card.kind = "map"
		card.selected = app.selected_map == index
		if index < 3:
			var image: TextureRect = app._texture(app._map_texture(index), Rect2(3, 3, 244, 122), card)
			image.name = "MapImage"
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			image.material = HanabiArtwork.map_material()
			image.material.set_shader_parameter("clip_lean", 0.06)
		else: app._icon("random", Rect2(91, 14, 57, 57), card, app.MUTED)
		app._panel(Rect2(11, 88, 219, 34), card, Color(0.03, 0.06, 0.05, 0.85), Color.TRANSPARENT)
		app._label("%02d  %s" % [index + 1, app.MAP_NAMES[index]], Rect2(22, 88, 207, 33), card, 17, app.GOLD if index == app.selected_map else app.INK)
		if card.selected:
			app._icon("check", Rect2(193, 3, 40, 40), card)
	var labels = ["每局时长", "对局局数", "初始生命"]
	for row in range(3):
		var y: float = 493 + row * 52
		section(labels[row], ["clock", "rounds", "life"][row], Rect2(38, y + 7, 141, 30))
		for column in range(3):
			var value: int = [120, 150, 180][column] if row == 0 else [1, 3, 5][column]
			var callback: Callable = app._set_seconds.bind(value) if row == 0 else app._set_rounds.bind(value) if row == 1 else app._set_hearts.bind(value)
			var selected: int = app.round_seconds if row == 0 else app.round_count if row == 1 else app.initial_hearts
			var option: HanabiSlantButton = app._button(app._clock(value) if row == 0 else "%02d%s" % [value, "局" if row == 1 else ""], Rect2(179 + column * 122, y, 116, 37), app.page, callback, selected == value)
			option.variant = "tab"
			option.selected = selected == value
	app._label("每组最多 12 分钟", Rect2(38, 651, 487, 23), app.page, 12, app.MUTED)
	app._label(["INDUSTRIAL WAREHOUSE", "STONE RUINS", "WOODLAND OUTPOST", "RANDOM ARENA"][app.selected_map], Rect2(593, 134, 625, 40), app.page, 32)
	app._label("4 人同屏 · 自由混战", Rect2(595, 178, 604, 23), app.page, 15, app.MUTED)
	app._map_preview(app.selected_map, Rect2(592, 216, 643, 292))
	app._panel(Rect2(596, 518, 626, 94), app.page, Color(0.05, 0.09, 0.07, 0.4))
	app._label("每局 %s    局数 %02d    生命 %02d" % [app._clock(app.round_seconds), app.round_count, app.initial_hearts], Rect2(621, 525, 560, 31), app.page, 18)
	var valid: bool = app.session.settings_valid()
	app._label("总时长  %s" % app._clock(app.round_seconds * app.round_count), Rect2(621, 555, 560, 29), app.page, 22, app.GOLD if valid else Color("df9984")).name = "SetupDuration"
	var warning := "超过 12 分钟，请减少局数或缩短每局时长" if not valid else ""
	var validation: Label = app._label(warning, Rect2(621, 591, 560, 21), app.page, 13, Color("df9984"))
	validation.name = "SetupValidation"
	validation.visible = not valid
	app._button("恢复默认", Rect2(595, 623, 215, 43), app.page, app._reset_settings)
	app.start_button = app._button("选择角色  →", Rect2(828, 623, 391, 43), app.page, app._enter_selection, true)
	app.start_button.disabled = not valid
	app.start_button.tooltip_text = warning if not valid else "继续选择角色"
	footer(app._return_lobby)

func build_characters() -> void:
	app.page.set_meta("english_title", "SELECT FIGHTER")
	app._title("角色选择", Rect2(24, 17, 425, 44), app.page)
	app._label("角色选择", Rect2(470, 24, 180, 32), app.page, 19, app.MUTED)
	app._label("", Rect2(25, 61, 880, 25), app.page, 14, app.INK).name = "SelectionTurn"
	app.ready_label = app._label("", Rect2(947, 19, 309, 40), app.page, 25, app.INK, true)
	var copy := BackBufferCopy.new()
	copy.name = "SelectionBackdropCopy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	app.page.add_child(copy)
	for slot in range(4):
		app._acrylic_card(Rect2(24 + slot * 312, 94, 296, 438), app.page, "Seat%d" % slot, false)
		if app.session.can_select(slot):
			var card: Panel = app.page.get_node("Seat%dCard" % slot)
			card.add_theme_stylebox_override("panel", app._style(Color.TRANSPARENT, app.GOLD, 2))
	for slot in range(4):
		var x: float = 24 + slot * 312
		var color: Color = HanabiArtwork.COLORS[slot]
		var shown: bool = app.ready_slots[slot] or slot == app.active_slot
		var current: bool = app.session.can_select(slot)
		var connected: bool = app.router.slot_connected(slot)
		var character: int = app.characters[slot]
		app._rect_panel(Rect2(x + 12, 104, 39, 27), app.page, color)
		app._label("P%d" % (slot + 1), Rect2(x + 12, 104, 39, 27), app.page, 18, app.BG, true)
		app._label(HanabiArtwork.CHARACTER_CODES[character] if shown else "WAITING", Rect2(x + 62, 100, 157, 29), app.page, 22, app.INK).name = "SeatName%d" % slot
		app._label(HanabiArtwork.CHARACTER_NAMES[character] if shown else "尚未选择", Rect2(x + 62, 129, 170, 20), app.page, 12, app.MUTED)
		app._label("READY" if app.ready_slots[slot] else "SELECT" if current and connected else "离线" if current else "等待", Rect2(x + 223, 105, 61, 23), app.page, 12, color, true).name = "SeatStatus%d" % slot
		if app.ready_slots[slot] and app.router.modes[slot] != "ai":
			var edit: HanabiSlantButton = app._rect_button("改选", Rect2(x + 242, 132, 43, 22), app.page, app._cancel_selection.bind(slot))
			edit.caption.add_theme_font_size_override("font_size", 11)
		app._device_option(slot, Rect2(x + 12, 157, 272, 23))
		if shown:
			var hero: TextureRect = app._texture(HanabiArtwork.hero_texture(character), Rect2(x + 12, 188, 272, 302), app.page)
			hero.name = "SelectedHero%d" % slot
			var sprite: TextureRect = app._texture(HanabiArtwork.sprite_texture(character), Rect2(x + 202, 398, 78, 85), app.page)
			sprite.name = "SelectedSprite%d" % slot
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		else:
			app._label("%02d" % (slot + 1), Rect2(x + 35, 230, 226, 110), app.page, 76, Color(0.60, 0.70, 0.65, 0.13), true)
			app._label("等待选择", Rect2(x + 25, 342, 246, 37), app.page, 22, app.MUTED, true)
			app._label("当前轮到 P%d" % (app.active_slot + 1), Rect2(x + 25, 381, 246, 27), app.page, 14, app.MUTED, true)
		var ready: HanabiSlantButton = app._rect_button("", Rect2(x + 12, 492, 272, 29), app.page, app._toggle_ready.bind(slot), current)
		ready.name = "SeatConfirm%d" % slot
		ready.caption.add_theme_font_size_override("font_size", 14)
		app.ready_buttons.append(ready)
	app._rect_panel(Rect2(24, 548, 3, 59), app.page, app.GOLD)
	app._label("角色池", Rect2(39, 548, 226, 33), app.page, 21)
	app._label("P1 → P2 → P3 → P4", Rect2(40, 584, 260, 23), app.page, 13, app.MUTED)
	for index in range(6):
		var character: int = app.ROSTER_ORDER[index]
		var button: HanabiSlantButton = app._button("", Rect2(322 + index * 107, 549, 99, 106), app.page, app._select_character.bind(app.active_slot, character))
		button.name = "Roster%d" % character
		button.kind = "portrait"
		button.lean_override = 0
		# Native TextureRect respects AtlasTexture crops and preserves square faces;
		# the name strip no longer covers the chin or changes portrait composition.
		var face: TextureRect = app._texture(HanabiArtwork.face(character), Rect2(2, 2, 95, 80), button)
		face.name = "RosterFace"
		button.selected = app.session.can_select(app.active_slot) and character == app.characters[app.active_slot]
		app._rect_panel(Rect2(1, 84, 97, 21), button, Color(0.02, 0.03, 0.025, 0.88))
		app._label(HanabiArtwork.CHARACTER_NAMES[character], Rect2(1, 84, 97, 21), button, 10, app.INK, true)
		var marker := 0
		for slot in range(4):
			if app.characters[slot] == character and (app.ready_slots[slot] or slot == app.active_slot):
				var color: Color = HanabiArtwork.COLORS[slot]
				app._rect_panel(Rect2(2 + marker * 24, 2, 23, 17), button, color)
				app._label("P%d" % (slot + 1), Rect2(2 + marker * 24, 2, 23, 17), button, 10, app.BG, true)
				marker += 1
		app.selection_buttons.append(button)
	app._rect_button("对局设置", Rect2(24, 665, 175, 38), app.page, func(): app._show_screen("setup")).name = "SelectionBack"
	app._rect_button("返回上一位", Rect2(213, 665, 158, 38), app.page, app._previous_selection).name = "SelectionPrevious"
	key_hint("L", "选择", Vector2(397, 668), app.page, 107)
	key_hint("A", "确认", Vector2(511, 668), app.page, 106)
	key_hint("B", "返回", Vector2(625, 668), app.page, 106)
	key_hint("Y", "设备", Vector2(742, 668), app.page, 107)
	app._label("F 全屏", Rect2(858, 667, 106, 31), app.page, 12, app.MUTED, true)
	app.start_button = app._rect_button("开始对局", Rect2(982, 665, 274, 38), app.page, app._start.bind(false), true)
	app._refresh_ready()

func build_game() -> void:
	app.arena_view = app._texture(app.subviewport.get_texture(), Rect2(0, 0, 1280, 720), app.page)
	app.arena_view.stretch_mode = TextureRect.STRETCH_SCALE
	for slot in range(4):
		var x: float = [10, 259, 777, 1027][slot]
		var color: Color = HanabiArtwork.COLORS[slot]
		app._panel(Rect2(x, 8, 243, 58), app.page, Color(0.04, 0.08, 0.065, 0.12), Color(color, 0.2))
		app._texture(HanabiArtwork.face(app.characters[slot]), Rect2(x + 10, 8, 59, 56), app.page)
		app._label("P%d" % (slot + 1), Rect2(x + 74, 9, 37, 23), app.page, 15, color)
		var health := HanabiHealthMeter.new()
		health.position = Vector2(x + 74, 36)
		health.size = Vector2(83, 17)
		health.maximum = app.initial_hearts
		health.tint = color
		health.mouse_filter = Control.MOUSE_FILTER_IGNORE
		app.page.add_child(health)
		app.health_meters.append(health)
		app.hud_scores.append(app._label("00", Rect2(x + 166, 13, 65, 36), app.page, 31, app.INK, true))
		app.boom_labels.append(app._label("", Rect2(x + 74, 50, 134, 15), app.page, 10, app.INK))
	app._panel(Rect2(511, 7, 259, 59), app.page, Color(0.04, 0.08, 0.065, 0.1), Color(app.LINE, 0.12))
	app.time_label = app._label("", Rect2(511, 7, 209, 38), app.page, 32, app.INK, true)
	app.round_label = app._label("", Rect2(512, 45, 208, 17), app.page, 12, app.INK, true)
	app._button("Ⅱ", Rect2(728, 17, 34, 36), app.page, app._toggle_pause)
	app._panel(Rect2(160, 674, 960, 40), app.page, Color(0.04, 0.08, 0.065, 0.07), Color.TRANSPARENT)
	key_hint("L", "移动 / 奔跑", Vector2(196, 678), app.page, 189)
	key_hint("A", "投掷 / 召回", Vector2(413, 678), app.page, 179)
	key_hint("B", "冲刺", Vector2(616, 678), app.page, 111)
	key_hint("X", "近战", Vector2(750, 678), app.page, 111)
	key_hint("START", "暂停", Vector2(889, 678), app.page, 123)
	app.phase_label = app._label("", Rect2(335, 267, 610, 84), app.page, 46, app.INK, true)
	app.phase_label.add_theme_color_override("font_shadow_color", app.BG)
	app.phase_label.add_theme_constant_override("shadow_offset_x", 2)
	app.phase_label.add_theme_constant_override("shadow_offset_y", 3)
	app.pause_panel = Control.new()
	app.pause_panel.position = Vector2(925, 164)
	app.pause_panel.size = Vector2(332, 429)
	app.page.add_child(app.pause_panel)
	app._acrylic_card(Rect2(0, 0, 332, 429), app.pause_panel, "Pause")
	app._title("游戏暂停", Rect2(24, 26, 284, 52), app.pause_panel)
	app._label("游戏已暂停", Rect2(26, 85, 280, 24), app.pause_panel, 12, app.MUTED)
	app._rect_panel(Rect2(24, 117, 284, 1), app.pause_panel, Color(0.8, 0.9, 0.9, 0.10))
	var resume: Button = app._rect_button("继续游戏", Rect2(24, 137, 284, 47), app.pause_panel, app._toggle_pause, true)
	resume.name = "PauseResume"
	var help: Button = app._rect_button("操作说明", Rect2(24, 198, 284, 42), app.pause_panel, app._show_help)
	help.name = "PauseHelp"
	var settings: Button = app._rect_button("游戏设置", Rect2(24, 254, 284, 42), app.pause_panel, app._show_settings)
	settings.name = "PauseSettings"
	var leave: Button = app._rect_button("返回大厅", Rect2(24, 310, 284, 42), app.pause_panel, app._confirm_leave)
	leave.name = "PauseLeave"
	var controls: Array[Control] = [resume, help, settings, leave]
	for index in range(controls.size()):
		var previous := controls[index].get_path_to(controls[(index + controls.size() - 1) % controls.size()])
		var next := controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = previous
		controls[index].focus_next = next
		controls[index].focus_neighbor_top = previous
		controls[index].focus_neighbor_bottom = next
		controls[index].focus_neighbor_left = previous
		controls[index].focus_neighbor_right = next
	app._rect_panel(Rect2(24, 371, 284, 1), app.pause_panel, Color(0.8, 0.9, 0.9, 0.10))
	var reason: Label = app._label("", Rect2(24, 382, 284, 31), app.pause_panel, 12, app.MUTED, true)
	reason.name = "PauseReason"
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.pause_panel.hide()

func build_results() -> void:
	header("对局结束", "MATCH OVER")
	app._label("对局时长   %s" % app._clock(maxi(0, int(app.world.rules.match_seconds - app.world.remaining))), Rect2(959, 41, 282, 36), app.page, 21)
	for slot in range(4):
		var x: float = 24 + slot * 313
		var color: Color = HanabiArtwork.COLORS[slot]
		var fighter: HanabiFighter = app.world.fighters[slot]
		var card: HanabiSlantButton = app._button("", Rect2(x, 143, 301, 471), app.page, func(): pass, false, color)
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.kind = "result"
		card.lean_override = 54
		card.art = HanabiArtwork.hero_texture(app.characters[slot])
		card.art_uv = HanabiArtwork.hero_uv(app.characters[slot], 301.0 / 471.0)
		app._panel(Rect2(5, 285, 290, 181), card, Color(0.03, 0.06, 0.05, 0.96), Color.TRANSPARENT)
		app._label("P%d  %s" % [slot + 1, fighter.nickname], Rect2(20, 295, 260, 31), card, 22, color)
		for row in range(3):
			metric(["得分", "击倒", "被击倒"][row], str([fighter.score, fighter.kills, fighter.deaths][row]).pad_zeros(2), ["boomerang", "crossed", "skull"][row], Rect2(25, 337 + row * 36, 262, 30), card, color)
	app.start_button = app._button("再来一局  →", Rect2(387, 641, 284, 49), app.page, app._replay, true)
	app._button("返回大厅", Rect2(688, 641, 233, 49), app.page, app._return_lobby)

func build_codex() -> void:
	header("角色图鉴", "CHARACTER ARCHIVE")
	for index in range(6):
		art_card(HanabiArtwork.CHARACTER_NAMES[index], "BOOMERANG FIGHTER", Rect2(36 + index % 3 * 411, 149 + int(index / 3) * 233, 392, 214), index, app._inspect_character.bind(index), "%02d" % (index + 1))
	footer(app._return_lobby)

func build_components() -> void:
	app._title("UI / UX KIT", Rect2(35, 23, 600, 47), app.page)
	app._label("像素倒角 · 哑光面板 · 实体按压反馈 · 中文轻像素 / 英文大标题", Rect2(37, 77, 870, 27), app.page, 14, app.MUTED)
	var states = ["normal", "hover", "pressed", "disabled"]
	for column in range(4):
		app._label(["普通", "悬停 / 聚焦", "按下 / 选中", "禁用"][column], Rect2(224 + column * 249, 111, 236, 27), app.page, 14, app.MUTED, true)
	for row in range(4):
		var y: float = 153 + row * 65
		app._label(["主操作按钮", "次操作按钮", "确认 / 离开", "分段页签"][row], Rect2(37, y, 176, 48), app.page, 18)
		for column in range(4):
			var button: HanabiSlantButton = app._button(["选择角色", "恢复默认", "确认离开", "03 局"][row], Rect2(224 + column * 249, y, 236, 48), app.page, func(): pass, row == 0)
			button.variant = ["primary", "secondary", "danger", "tab"][row]
			button.preview_state = states[column]
			button.disabled = column == 3
	app._panel(Rect2(34, 430, 582, 98), app.page, Color("101a18df"))
	app._label("设置控件", Rect2(49, 438, 163, 26), app.page, 17, app.MUTED)
	app._switch("游戏音效", Rect2(48, 473, 247, 43), app.page, true, func(_enabled): pass)
	var volume_label: Label = app._label("70%", Rect2(504, 439, 78, 25), app.page, 15, app.GOLD, true)
	volume_label.name = "GalleryVolume"
	app._slider(Rect2(329, 483, 260, 25), app.page, 0.7, func(value): volume_label.text = "%d%%" % roundi(value * 100)).name = "GallerySlider"
	app._panel(Rect2(639, 430, 591, 98), app.page, Color("101a18df"))
	app._label("玩家准备条 / 数据条", Rect2(655, 438, 520, 26), app.page, 17, app.MUTED)
	app._icon("controller", Rect2(658, 477, 34, 32), app.page, HanabiArtwork.COLORS[0])
	app._label("P1  READY", Rect2(706, 478, 178, 29), app.page, 19, HanabiArtwork.COLORS[0])
	app._icon("check", Rect2(873, 477, 31, 31), app.page, app.GOLD)
	var health := HanabiHealthMeter.new()
	health.position = Vector2(950, 481)
	health.size = Vector2(119, 18)
	health.value = 2
	health.cooldown = 0.3
	app.page.add_child(health)
	app._label("02:30", Rect2(1091, 472, 119, 38), app.page, 26, app.INK, true)
	app._label("奶白图标 · 悬停 / 按下 / 手柄聚焦", Rect2(37, 545, 661, 27), app.page, 17, app.MUTED)
	for index in range(8):
		var icon_button: HanabiSlantButton = app._button("", Rect2(39 + index * 66, 582, 54, 48), app.page, func(): pass)
		app._icon(["home", "settings", "fighters", "controller", "clock", "map", "boomerang", "refresh"][index], Rect2(7, 4, 40, 40), icon_button)
		icon_button.tooltip_text = ["大厅", "设置", "角色", "手柄", "时长", "地图", "回旋镖", "重玩"][index]
	key_hint("A", "确认", Vector2(615, 582), app.page)
	key_hint("B", "返回", Vector2(787, 582), app.page)
	key_hint("START", "暂停", Vector2(955, 582), app.page)
	app._label("ABXY 材质", Rect2(615, 621, 137, 25), app.page, 12, app.MUTED)
	for index in range(4): key_hint(["A", "B", "X", "Y"][index], "", Vector2(759 + index * 49, 616), app.page)
	app._button("游戏设置", Rect2(830, 660, 181, 39), app.page, app._show_settings)
	app._button("返回大厅", Rect2(1023, 660, 205, 39), app.page, app._return_lobby, true)
