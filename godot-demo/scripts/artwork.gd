extends RefCounted
class_name HanabiArtwork

const CHARACTER_NAMES = ["GPT娘", "Claude娘", "DeepSeek娘", "Eve_aic", "GLM娘", "酒狐"]
const CHARACTER_CODES = ["GPT", "CLAUDE", "DEEPSEEK", "EVE", "GLM", "JIU HU"]
const COLORS = [Color("608e80"), Color("c8a04f"), Color("a283a9"), Color("c58591")]
static var character_assets: Dictionary = {}

static func character_art(character: int) -> HanabiUICharacterArt:
	if not character_assets.has(character): character_assets[character] = load("res://assets/ui/characters/slot_%d.tres" % character)
	return character_assets[character]

static func region(path: String, rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = rect
	return texture

static func portrait(character: int) -> Texture2D:
	# Clean transparent sprites derived from the approved character designs.
	if character_art(character).sprite: return character_art(character).sprite
	var sheet: Texture2D = preload("res://assets/fighters.png")
	var cell := Vector2(sheet.get_width() / 3, sheet.get_height() / 2)
	return region("res://assets/fighters.png", Rect2(Vector2((character % 3) * cell.x, int(character / 3) * cell.y), cell))

static func sprite_texture(character: int) -> Texture2D:
	return portrait(character)

static func hero_texture(character: int) -> Texture2D:
	if character_art(character).hero: return character_art(character).hero
	# The outer pink portrait is clipped in the six-lane design; use its complete results art.
	return preload("res://assets/v4/results.png") if character == 3 else preload("res://assets/v4/characters.png")

static func face(character: int) -> Texture2D:
	if character_art(character).avatar: return character_art(character).avatar
	var rectangles = [Rect2(725, 228, 164, 168), Rect2(398, 187, 151, 168), Rect2(964, 219, 164, 183), Rect2(1488, 207, 166, 186), Rect2(150, 165, 162, 170), Rect2(1283, 218, 156, 178)]
	return region("res://assets/v4/characters.png", rectangles[character])

static func hero_uv(character: int, aspect: float = 0.0) -> PackedVector2Array:
	if character_art(character).hero: return PackedVector2Array()
	if character == 3:
		var top := 0.17
		var bottom := 0.62
		var width := 0.19
		if aspect > 0.0:
			if aspect > width * 1672.0 / ((bottom - top) * 941.0):
				if aspect > 1.5: top = 0.27
				bottom = top + width * 1672.0 / aspect / 941.0
			else: width = (bottom - top) * 941.0 * aspect / 1672.0
		var center_top := 0.90 - (top - 0.17) * 0.10
		var center_bottom := 0.90 - (bottom - 0.17) * 0.10
		return PackedVector2Array([Vector2(center_top - width / 2, top), Vector2(center_top + width / 2, top), Vector2(center_bottom + width / 2, bottom), Vector2(center_bottom - width / 2, bottom)])
	var lane: int = [2, 1, 3, 5, 0, 4][character]
	var bounds = [0.0, 0.226, 0.400, 0.588, 0.759, 0.915, 1.0]
	var slopes = [0.0, 0.174, 0.187, 0.169, 0.126, 0.124, 0.0]
	var top := 0.17
	var bottom := 0.65
	var width_top: float = bounds[lane + 1] - bounds[lane] - (top - 0.1115) * (slopes[lane + 1] - slopes[lane])
	var width_bottom: float = bounds[lane + 1] - bounds[lane] - (bottom - 0.1115) * (slopes[lane + 1] - slopes[lane])
	var width: float = minf(width_top, width_bottom) - 0.036
	if aspect > 0.0:
		var height: float = (bottom - top) * 941.0
		if aspect > width * 1672.0 / height:
			# Wide menu cards crop toward the face rather than stretching the portrait.
			if aspect > 1.5: top = 0.245
			bottom = top + width * 1672.0 / aspect / 941.0
		else:
			width = height * aspect / 1672.0
	var center_top: float = (bounds[lane] + bounds[lane + 1]) * 0.5 - (top - 0.1115) * (slopes[lane] + slopes[lane + 1]) * 0.5
	var center_bottom: float = (bounds[lane] + bounds[lane + 1]) * 0.5 - (bottom - 0.1115) * (slopes[lane] + slopes[lane + 1]) * 0.5
	# Parallel UV edges keep every scanline the same scale, including outer lanes.
	return PackedVector2Array([
		Vector2(center_top - width * 0.5, top), Vector2(center_top + width * 0.5, top),
		Vector2(center_bottom + width * 0.5, bottom), Vector2(center_bottom - width * 0.5, bottom)])

static func title_texture(title: String) -> AtlasTexture:
	var titles = {
		"对局设置": ["setup", Rect2(86, 34, 360, 81)],
		"角色选择": ["characters", Rect2(88, 20, 321, 82)],
		"对局结束": ["results", Rect2(29, 60, 583, 190)],
		"游戏暂停": ["gameplay", Rect2(1375, 245, 245, 66)]
	}
	if not titles.has(title): return null
	var data: Array = titles[title]
	return region("res://assets/v4/%s.png" % data[0], data[1])

static func letter_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float cut_slope = 0.0; uniform vec2 crop_origin = vec2(0.0); uniform vec2 crop_size = vec2(1.0); void fragment(){vec4 c=texture(TEXTURE,UV);vec2 p=(UV-crop_origin)/crop_size;float light=max(c.r,max(c.g,c.b));c.a*=smoothstep(0.29,0.45,light); if(p.y>1.0-cut_slope*p.x){c.a=0.0;} if(cut_slope>0.0){if(p.y<0.24*(1.0-p.x)){c.a=0.0;} c.a*=smoothstep(0.29,0.45,min(c.r,min(c.g,c.b)));} COLOR=c;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

static func map_material(_variant: int = 0) -> ShaderMaterial:
	# Clip the existing UI card shape only; map colors always come from its PNG.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float clip_lean = 0.0; void fragment(){vec4 c=texture(TEXTURE,UV); if(clip_lean>0.0 && (UV.x<clip_lean*(1.0-UV.y)||UV.x>1.0-clip_lean*UV.y)){c.a=0.0;} COLOR=c;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

static func sprite_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE, UV); float light=max(c.r,max(c.g,c.b)); c.a*=smoothstep(0.06,0.115,light); COLOR=c; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

static func roster_material(selected: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform int selected = 2; void fragment(){vec4 c=texture(TEXTURE,UV); float dy=UV.y-0.151; float b1=0.200-dy*0.110; float b2=0.350-dy*0.120; float b3=0.588-dy*0.158; float b4=0.750-dy*0.120; float b5=0.900-dy*0.120; int lane=UV.x<b1?0:UV.x<b2?1:UV.x<b3?2:UV.x<b4?3:UV.x<b5?4:5; if(lane!=selected){float l=dot(c.rgb,vec3(0.299,0.587,0.114)); c.rgb=mix(c.rgb,vec3(l*0.68),0.72);}else{c.rgb=min(c.rgb*1.17,vec3(1.0)); float left=lane==0?0.0:lane==1?b1:lane==2?b2:lane==3?b3:lane==4?b4:b5; float right=lane==0?b1:lane==1?b2:lane==2?b3:lane==3?b4:lane==4?b5:1.0; if(min(UV.x-left,right-UV.x)<0.002){c.rgb=vec3(0.784,0.667,0.282);}} COLOR=c;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("selected", selected)
	return material
