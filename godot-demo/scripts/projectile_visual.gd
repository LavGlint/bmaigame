extends Node2D
class_name HanabiProjectileVisual

# Display only; the owning combat node supplies the single physics clock.
@export_file("*.json") var manifest_path: String
@export var auto_free_on_finish := false
static var resources: Dictionary = {}
var sprite: AnimatedSprite2D
var config: Dictionary
var elapsed: float = 0.0
var completed: bool = false
var expired: bool = false
var role_id: int = 0

func _ready() -> void:
	if not manifest_path.is_empty() and sprite == null:
		configure(int(manifest_path.get_base_dir().get_base_dir().get_file().trim_prefix("role_")))

func configure(role: int) -> void:
	role_id = role
	var base := "res://assets/characters/role_%d/projectiles/" % role
	if not resources.has(role):
		resources[role] = {"frames":load(base+"effects.tres"),"data":JSON.parse_string(FileAccess.get_file_as_string(base+"manifest.json"))}
	config = resources[role].data
	sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)
	sprite.sprite_frames = resources[role].frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.stop()

func play_effect(clip: StringName, heading: float = 0.0) -> void:
	rotation = heading
	elapsed = 0.0
	completed = false
	sprite.stop()
	sprite.animation = clip
	sprite.set_frame_and_progress(0,0.0)
	_register_frame()

func advance(delta: float) -> bool:
	if completed or expired: return false
	elapsed += delta
	var frames := sprite.sprite_frames
	var fps := frames.get_animation_speed(sprite.animation)
	var count := frames.get_frame_count(sprite.animation)
	var units := elapsed*fps
	if not frames.get_animation_loop(sprite.animation) and units >= count:
		completed = true
		sprite.set_frame_and_progress(count-1,0.0)
		_register_frame()
		if auto_free_on_finish:
			expired = true
			queue_free()
		return true
	sprite.set_frame_and_progress(int(units)%count,fmod(units,1.0))
	_register_frame()
	return false

func _register_frame() -> void:
	var clip: Dictionary = config.animations[str(sprite.animation)]
	var frame: Dictionary = clip.frames[sprite.frame]
	sprite.scale = Vector2.ONE * float(clip.display_scale) * HanabiFighterAnimation.GAME_SCALE
	sprite.offset = Vector2(frame.offset[0],frame.offset[1])
