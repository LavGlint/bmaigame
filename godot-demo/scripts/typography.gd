extends RefCounted
class_name HanabiTypography

const REGULAR = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
const BOLD = preload("res://assets/fonts/HarmonyOS_Sans_SC_Bold.ttf")
const SOFT_SHADER = preload("res://assets/ui/shaders/soft_type.gdshader")
static var pixel_bold: FontFile
static var soft_material: ShaderMaterial

static func has_chinese(text: String) -> bool:
	for character in text:
		var code := character.unicode_at(0)
		if code >= 0x3400 and code <= 0x9fff: return true
	return false

static func display_font() -> FontFile:
	if not pixel_bold:
		pixel_bold = BOLD.duplicate()
		pixel_bold.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		pixel_bold.multichannel_signed_distance_field = false
		pixel_bold.oversampling = 2.0
	return pixel_bold

static func material() -> ShaderMaterial:
	if not soft_material:
		soft_material = ShaderMaterial.new()
		soft_material.shader = SOFT_SHADER
	return soft_material

static func style_label(label: Label, display: bool = false) -> void:
	label.add_theme_font_override("font", display_font() if display else REGULAR)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if display and has_chinese(label.text):
		label.material = material()
