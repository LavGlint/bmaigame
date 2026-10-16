extends RefCounted
class_name HanabiUISkin

const WORDMARKS = {"对局设置":"match_setup", "角色选择":"character_select", "对局结束":"match_over", "游戏暂停":"paused", "角色图鉴":"archive", "本地对战":"local_battle", "电脑演示":"auto_battle", "游戏设置":"settings", "继续游戏":"continue", "再来一局":"replay", "返回大厅":"home", "操作说明":"controls", "选择角色":"select_fighter", "开始对局":"start_match", "恢复默认":"reset"}
const EXTRA_WORDMARKS = {"比赛记录":"records", "返回大厅？":"leave", "确认返回大厅":"confirm_leave", "UI / UX KIT":"ui_kit", "赤刃":"fighter_0", "星火":"fighter_1", "月织":"fighter_2", "桃铃":"fighter_3", "霜羽":"fighter_4", "晨光":"fighter_5"}
static var textures: Dictionary = {}
const IVORY_ICONS = ["home", "controller", "fighters", "settings", "play", "pause", "back", "exit", "map", "random", "clock", "rounds", "life", "boomerang", "dash", "crossed", "skull", "check", "refresh", "chevron", "sound", "keyboard", "offline", "help"]

static func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load("res://assets/ui/" + path)
	return textures[path]

static func button(variant: String, state: String) -> Texture2D:
	return texture("components/button_%s_%s.svg" % [variant, state])

static func wordmark(text: String) -> Texture2D:
	var key: String = WORDMARKS.get(text, EXTRA_WORDMARKS.get(text, ""))
	if key.is_empty(): return null
	return texture("titles-en/" + key + ".svg")

static func icon(name: String, state: String = "normal") -> Texture2D:
	if name in IVORY_ICONS:
		return texture("ivory-icons/%s/%s.png" % [state if state in ["hover", "pressed"] else "normal", name])
	return texture(("pixel-icons/" if HanabiPixelIcons.GRIDS.has(name) else "icons/") + name + ".svg")

static func action_icon(caption: String) -> String:
	if caption.contains("Ⅱ"): return "pause"
	for entry in [["返回", "back"], ["关闭", "back"], ["继续", "play"], ["开始", "play"], ["再来", "refresh"], ["恢复", "refresh"], ["选择角色", "fighters"], ["游戏设置", "settings"], ["操作说明", "help"], ["确认", "check"], ["退出", "exit"]]:
		if caption.contains(entry[0]): return entry[1]
	return ""

static func draw_material_icon(canvas: CanvasItem, name: String, rect: Rect2, state: String = "normal") -> void:
	var extent := maxf(40.0, floorf(minf(rect.size.x, rect.size.y) / 40.0) * 40.0)
	var target := Rect2((rect.position + (rect.size - Vector2.ONE * extent) / 2).round(), Vector2.ONE * extent)
	canvas.draw_texture_rect(icon(name, state), target, false, Color("87958d") if state == "disabled" else Color.WHITE)

static func draw_pixel_icon(canvas: CanvasItem, name: String, rect: Rect2, tint: Color) -> void:
	if not HanabiPixelIcons.GRIDS.has(name): return
	var cell := maxf(1.0, floorf(minf(rect.size.x, rect.size.y) / 12.0))
	var origin := (rect.position + (rect.size - Vector2.ONE * cell * 12.0) / 2.0).round()
	var rows: Array = HanabiPixelIcons.GRIDS[name]
	for y in range(12):
		for x in range(12):
			if rows[y][x] == "#":
				canvas.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2.ONE * cell), tint)

static func cover_uv(points: PackedVector2Array, size: Vector2, texture_size: Vector2, focus: Vector2 = Vector2(0.5, 0.5), zoom: float = 1.0) -> PackedVector2Array:
	var scale := maxf(size.x / texture_size.x, size.y / texture_size.y) * zoom
	var image_size := texture_size * scale
	var offset := (image_size - size) * focus
	var result := PackedVector2Array()
	for point in points: result.append((point + offset) / image_size)
	return result
