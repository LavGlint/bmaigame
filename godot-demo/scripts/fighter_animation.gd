extends RefCounted
class_name HanabiFighterAnimation

# One physics clock drives both visible frames and combat events. AnimatedSprite2D
# never advances independently, so pauses and fixed-fps simulation stay in sync.
const GAME_SCALE := 68.0/96.0
var game_scale := GAME_SCALE
static var resources: Dictionary = {}
var sprite: AnimatedSprite2D
var metadata: Dictionary = {}
var action: StringName = &"idle"
var direction: StringName = &"down"
var elapsed: float = 0.0
var frame_time: float = 0.0
var completed: bool = false
var release_emitted: bool = false
var release_frame: int = 2
var ownership_material := ShaderMaterial.new()
var ownership_cache: Dictionary = {}

func configure(target: AnimatedSprite2D, character_id: int) -> void:
	sprite = target
	ownership_cache.clear()
	ownership_material.shader = preload("res://assets/ui/shaders/atlas_ownership.gdshader")
	sprite.material = ownership_material
	var path := "res://assets/characters/role_%d/" % character_id
	if not resources.has(character_id):
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "manifest.json"))
		resources[character_id] = {"frames": load(path + "animations.tres"), "data": parsed}
	var data: Dictionary = resources[character_id]
	sprite.sprite_frames = data.frames
	metadata = data.data.animations
	release_frame = int(data.data.get("attack_release_frame", 2))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2.ZERO
	sprite.flip_h = false
	sprite.rotation = 0.0
	play(&"idle", &"down", true)

static func facing(vector: Vector2, fallback: StringName = &"down") -> StringName:
	if vector.length_squared() < 0.01: return fallback
	if absf(vector.x) > absf(vector.y): return &"right" if vector.x > 0 else &"left"
	return &"down" if vector.y > 0 else &"up"

func duration(next_action: StringName, next_direction: StringName) -> float:
	var clip := StringName(str(next_action) + "_" + str(next_direction))
	var frames := sprite.sprite_frames
	var length := 0.0
	for index in range(frames.get_frame_count(clip)):
		length += frames.get_frame_duration(clip, index) / frames.get_animation_speed(clip)
	return length

func play(next_action: StringName, next_direction: StringName, restart: bool = false) -> void:
	if not restart and action == next_action and direction == next_direction: return
	var preserve_phase := not restart and action == next_action and action in [&"idle", &"walk", &"run"]
	var phase := elapsed / duration(action, direction) if preserve_phase else 0.0
	action = next_action
	direction = next_direction
	elapsed = 0.0
	frame_time = 0.0
	completed = false
	release_emitted = false
	sprite.stop()
	sprite.animation = StringName(str(action) + "_" + str(direction))
	sprite.set_frame_and_progress(0, 0.0)
	apply_registration()
	if preserve_phase: advance(fmod(phase, 1.0) * duration(action, direction))

func advance(delta: float, rate: float = 1.0) -> Dictionary:
	var events := {"release": false, "finished": false}
	if completed or delta <= 0.0 or rate <= 0.0: return events
	var frames := sprite.sprite_frames
	var clip := sprite.animation
	var fps := frames.get_animation_speed(clip)
	elapsed += delta * rate
	frame_time += delta * rate
	var frame := sprite.frame
	var length := frames.get_frame_count(clip)
	var step_time := frames.get_frame_duration(clip, frame) / fps
	while frame_time + 0.000001 >= step_time:
		frame_time = maxf(0.0, frame_time - step_time)
		frame += 1
		if frame >= length:
			if frames.get_animation_loop(clip):
				frame = 0
				elapsed = fmod(elapsed, duration(action, direction))
			else:
				frame = length - 1
				frame_time = 0.0
				completed = true
				events.finished = true
				break
		if action == &"attack" and frame == mini(release_frame, length - 1) and not release_emitted:
			release_emitted = true
			events.release = true
		step_time = frames.get_frame_duration(clip, frame) / fps
	sprite.set_frame_and_progress(frame, 0.0 if completed else clampf(frame_time / step_time, 0.0, 1.0))
	apply_registration()
	return events

func apply_registration() -> void:
	var clip: Dictionary = metadata[str(sprite.animation)]
	var frame: Dictionary = clip.frames[sprite.frame]
	var density := float(frame.get("display_scale", clip.scale))
	var origin: Array = frame.get("display_offset", clip.offset)
	sprite.scale = Vector2.ONE * density * game_scale
	sprite.offset = Vector2(float(origin[0]), float(origin[1]))
	_apply_ownership(frame)

func _apply_ownership(frame: Dictionary) -> void:
	var ownership: Dictionary = frame.get("ownership", {})
	ownership_material.set_shader_parameter("ownership_enabled", not ownership.is_empty())
	if ownership.is_empty(): return
	var key := str(sprite.animation) + ":" + str(sprite.frame)
	if not ownership_cache.has(key):
		var rows: Array = ownership.rows
		var columns := int(ownership.lookup_columns)
		var lookup := Image.create(columns, rows.size(), false, Image.FORMAT_RGBAF)
		lookup.fill(Color(-1,-1,-1,-1))
		for y in rows.size():
			var spans: Array = rows[y]
			for x in columns:
				var values := [-1.0,-1.0,-1.0,-1.0]
				for index in range(4):
					if x*4+index < spans.size(): values[index] = float(spans[x*4+index])
				lookup.set_pixel(x,y,Color(values[0],values[1],values[2],values[3]))
		ownership_cache[key] = ImageTexture.create_from_image(lookup)
	var size: Array = ownership.source_size
	ownership_material.set_shader_parameter("ownership_lookup",ownership_cache[key])
	ownership_material.set_shader_parameter("source_size",Vector2(size[0],size[1]))
	ownership_material.set_shader_parameter("first_row",float(ownership.y))
	ownership_material.set_shader_parameter("lookup_size",Vector2(ownership.lookup_columns,ownership.rows.size()))
