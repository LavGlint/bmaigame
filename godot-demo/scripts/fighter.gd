extends CharacterBody2D
class_name HanabiFighter

var slot: int = 0
var nickname: String = ""
var tint: Color = Color.WHITE
var world
var sprite: AnimatedSprite2D
var hp: int = 2
var alive: bool = true
var aim: Vector2 = Vector2.RIGHT
var invulnerable: float = 0.8
var dash_time: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var slash_time: float = 0.0
var slash_cooldown: float = 0.0
var throw_cooldown: float = 0.0
var active_boom
var active_flame
var remote_held := false
var score: int = 0
var kills: int = 0
var wins: int = 0
var deaths: int = 0
var character_id: int = 0
var survival: float = 0.0
var lot: int = 0
var last_actions: Dictionary = {}
var animation_clock: float = 0.0
var feedback_text: String = ""
var feedback_time: float = 0.0
var hit_flash: float = 0.0
var animation: HanabiFighterAnimation
var action_state: StringName = &"idle"
var is_running: bool = false
var pending_attack: String = ""
var attack_aim: Vector2 = Vector2.RIGHT
var collider: CollisionShape2D

func configure(index: int, arena) -> void:
	slot = index
	character_id = index
	world = arena
	nickname = HanabiRules.NAMES[slot]
	tint = HanabiRules.COLORS[slot]
	position = world.spawn_position(slot)
	aim = Vector2(-1 if slot % 2 else 1, 0.3 if slot < 2 else -0.3).normalized()

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	var shape := CircleShape2D.new()
	shape.radius = world.rules.fighter_radius
	collider = CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	animation = HanabiFighterAnimation.new()
	animation.game_scale = world.rules.fighter_height/96.0
	animation.configure(sprite, character_id)

func set_character(index: int) -> void:
	character_id = clampi(index, 0, 5)
	if sprite:
		pending_attack = ""
		action_state = &"idle"
		animation.configure(sprite, character_id)

func set_presentation_size(height: float, radius: float = 16.0) -> void:
	animation.game_scale = clampf(height,64.0,72.0)/96.0
	animation.apply_registration()
	(collider.shape as CircleShape2D).radius = radius

func reset_round() -> void:
	position = world.spawn_position(slot)
	velocity = Vector2.ZERO
	hp = world.rules.hearts
	alive = true
	invulnerable = 0.8
	dash_time = 0.0
	dash_cooldown = 0.0
	slash_time = 0.0
	slash_cooldown = 0.0
	throw_cooldown = 0.3
	active_boom = null
	active_flame = null
	remote_held = false
	last_actions.clear()
	feedback_text = ""
	feedback_time = 0.0
	hit_flash = 0.0
	animation_clock = 0.0
	pending_attack = ""
	is_running = false
	action_state = &"idle"
	if sprite:
		sprite.modulate = Color.WHITE
		animation.play(&"idle", HanabiFighterAnimation.facing(aim), true)
	queue_redraw()

func step(command: Dictionary, delta: float) -> void:
	remote_held = bool(command.get("throw",false))
	if character_id == 0 and not remote_held:
		if is_instance_valid(active_flame): active_flame.stop()
		if pending_attack == "throw": pending_attack = ""
	if not alive:
		presentation_step(delta)
		return
	survival += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	slash_time = maxf(0.0, slash_time - delta)
	slash_cooldown = maxf(0.0, slash_cooldown - delta)
	throw_cooldown = maxf(0.0, throw_cooldown - delta)
	var movement: Vector2 = command.get("move", Vector2.ZERO)
	movement = movement.limit_length()
	var target_aim: Vector2 = command.get("aim", Vector2.ZERO)
	if target_aim.length() > 0.15:
		aim = target_aim.normalized()
	elif movement.length() > 0.1:
		aim = movement.normalized()
	if command.get("dash", false) and not last_actions.get("dash", false) and dash_cooldown <= 0.0 and action_state != &"hurt":
		pending_attack = ""
		if is_instance_valid(active_flame): active_flame.stop()
		action_state = &"dash"
		dash_time = world.rules.dash_seconds
		dash_cooldown = world.rules.dash_cooldown
		dash_direction = movement.normalized() if movement.length() > 0.1 else aim
		world.burst(position, tint, 7)
		world.effect.emit("dash")
		feedback("冲刺", 0.3)
	is_running = bool(command.get("run", false)) and movement.length() > 0.1 and action_state not in [&"attack", &"hurt"]
	if dash_time > 0.0:
		velocity = dash_direction * world.rules.dash_speed
	elif action_state == &"hurt":
		velocity = Vector2.ZERO
	else:
		var speed: float = world.rules.run_speed if is_running else world.rules.move_speed
		velocity = movement * speed * (0.55 if action_state == &"attack" else 1.0)
	move_and_slide()
	if command.get("throw", false) and not last_actions.get("throw", false):
		throw_or_recall()
	elif character_id == 0 and remote_held and not is_instance_valid(active_flame) and _can_attack():
		throw_or_recall()
	if command.get("slash", false) and not last_actions.get("slash", false):
		melee()
	last_actions = {"throw": command.get("throw", false), "dash": command.get("dash", false), "slash": command.get("slash", false)}
	_update_locomotion()
	_advance_visual(delta, true)
	queue_redraw()

func throw_or_recall() -> void:
	if not _can_attack() or throw_cooldown > 0.0:
		return
	_begin_attack("recall" if is_instance_valid(active_boom) else "throw")
	throw_cooldown = float(world.combat.weapon(character_id).cooldown)

func melee() -> void:
	if not _can_attack() or slash_cooldown > 0.0:
		return
	_begin_attack("slash")
	slash_cooldown = 0.65

func _can_attack() -> bool:
	return alive and dash_time <= 0.0 and action_state not in [&"attack", &"hurt", &"knockdown"]

func _begin_attack(kind: String) -> void:
	pending_attack = kind
	attack_aim = aim.normalized()
	action_state = &"attack"
	is_running = false
	animation.play(&"attack", HanabiFighterAnimation.facing(attack_aim), true)

func _release_attack() -> void:
	var kind := pending_attack
	pending_attack = ""
	if not alive or kind.is_empty(): return
	if kind == "throw":
		if not is_instance_valid(active_boom) and (character_id != 0 or remote_held): world.spawn_boom(self, attack_aim)
		feedback("龙炎" if character_id == 0 else "投掷", 0.3)
		return
	if kind == "recall":
		if is_instance_valid(active_boom): active_boom.recall()
		feedback("召回", 0.4)
		return
	slash_time = 0.2
	world.effect.emit("slash")
	feedback("近战", 0.25)
	for opponent in world.fighters:
		if opponent == self or not opponent.alive:
			continue
		var to_opponent: Vector2 = opponent.position - position
		if to_opponent.length() < 62.0 and to_opponent.normalized().dot(attack_aim) > 0.05:
			opponent.take_hit(self)
	for boom in world.boomerangs:
		if boom.owner_fighter != self and position.distance_to(boom.position) < 65.0:
			boom.recall()

func _update_locomotion() -> void:
	if action_state in [&"attack", &"hurt", &"knockdown"]: return
	var moving := velocity.length() > 8.0
	action_state = &"dash" if dash_time > 0.0 else &"run" if moving and is_running else &"walk" if moving else &"idle"
	var clip := &"run" if action_state == &"dash" else action_state
	animation.play(clip, HanabiFighterAnimation.facing(velocity if moving else aim, animation.direction))

func _advance_visual(delta: float, allow_attack_release: bool) -> void:
	animation_clock += delta
	feedback_time = maxf(0.0, feedback_time - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	var rate := 1.8 if action_state == &"dash" else clampf(velocity.length() / world.rules.run_speed, 0.15, 1.5) if action_state == &"run" else clampf(velocity.length() / world.rules.move_speed, 0.15, 1.5) if action_state == &"walk" else 1.0
	var events := animation.advance(delta, rate)
	if events.release:
		if allow_attack_release: _release_attack()
		else: pending_attack = ""
	if events.finished and action_state in [&"attack", &"hurt"]:
		pending_attack = ""
		action_state = &"idle"
		_update_locomotion()
	if character_id == 0 and is_instance_valid(active_flame) and not active_flame.stopping and action_state not in [&"hurt",&"dash",&"knockdown"]:
		# Keep an authored firing pose without replaying the release event.
		action_state = &"attack"
		if animation.action != &"attack" or animation.completed or animation.direction != HanabiFighterAnimation.facing(aim):
			animation.play(&"attack",HanabiFighterAnimation.facing(aim))
			animation.completed = true
			animation.release_emitted = true
			sprite.set_frame_and_progress(animation.release_frame,0.0)
			animation.apply_registration()
	elif character_id == 0 and action_state == &"attack" and pending_attack.is_empty() and animation.completed:
		action_state = &"idle"
		_update_locomotion()
	var opacity := 0.45 if not alive and animation.completed else 0.55 if alive and invulnerable > 0.0 and int(animation_clock * 15.0) % 2 else 1.0
	sprite.modulate = Color(1.0, 0.45 if hit_flash > 0.0 else 1.0, 0.45 if hit_flash > 0.0 else 1.0, opacity)

func presentation_step(delta: float) -> void:
	# Death and recovery keep playing between rounds; no gameplay event fires here.
	velocity = Vector2.ZERO
	is_running = false
	if alive and action_state not in [&"hurt", &"knockdown"]:
		pending_attack = ""
		action_state = &"idle"
		animation.play(&"idle", animation.direction)
	_advance_visual(delta, false)
	queue_redraw()

func take_hit(attacker: HanabiFighter, damage: int = 1) -> bool:
	if not alive or invulnerable > 0.0 or dash_time > 0.0 or attacker == self:
		return false
	hp = maxi(0,hp-maxi(0,damage))
	if is_instance_valid(active_flame): active_flame.stop()
	pending_attack = ""
	is_running = false
	velocity = Vector2.ZERO
	hit_flash = 0.12
	feedback("受击", 0.4)
	invulnerable = 0.6
	world.burst(position + Vector2(0, -15), tint, 12)
	world.effect.emit("hit")
	if hp <= 0:
		alive = false
		action_state = &"knockdown"
		deaths += 1
		velocity = Vector2.ZERO
		attacker.score += world.rules.kill_points
		attacker.kills += 1
		attacker.feedback("击倒 +1", 0.8)
		world.burst(position, tint, 28)
		world.effect.emit("ko")
		if sprite:
			animation.play(&"knockdown", animation.direction, true)
	else:
		action_state = &"hurt"
		animation.play(&"hurt", animation.direction, true)
	queue_redraw()
	return true

func feedback(text: String, duration: float = 0.5) -> void:
	feedback_text = text
	feedback_time = duration

func ranged_visual_origin(direction: Vector2) -> Vector2:
	var marker := Vector2(35,-48)
	match HanabiFighterAnimation.facing(direction):
		&"left": marker = Vector2(-35,-48)
		&"up": marker = Vector2(0,-70)
		&"down": marker = Vector2(0,-35)
	return position+sprite.position+marker*animation.game_scale

func _draw() -> void:
	draw_set_transform(Vector2(2,0),0.0,Vector2(1.0,0.42))
	draw_circle(Vector2.ZERO, 27.0, Color(0.2, 0.38, 0.3, 0.16))
	draw_arc(Vector2(-4, 0), 30.0, 0.0, TAU, 36, Color(tint, 0.65 if alive else 0.15), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	if not alive:
		return
	var arrow := PackedVector2Array([aim * 35 + aim.orthogonal() * 4, aim * 44, aim * 35 - aim.orthogonal() * 4])
	draw_colored_polygon(arrow, tint)
	draw_line(aim * 46, aim * 78, Color(tint, 0.35), 1.0)
	if slash_time > 0.0:
		var angle := attack_aim.angle()
		draw_arc(Vector2.ZERO, 57.0, angle - 0.95, angle + 0.95, 20, Color("fff8e0"), 8.0, true)
		draw_arc(Vector2.ZERO, 57.0, angle - 0.95, angle + 0.95, 20, tint, 2.0, true)
	if world.font:
		var title := "P%d · %s" % [slot + 1, nickname]
		var size: Vector2 = world.font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_rect(Rect2(-size.x / 2 - 6, -85, size.x + 12, 20), Color("18231ed0"))
		draw_string(world.font, Vector2(-size.x / 2, -71), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e3e0ca"))
		for index in range(world.rules.hearts):
			var x: float = -world.rules.hearts * 5 + index * 11
			draw_rect(Rect2(x, -60, 9, 4), tint if index < hp else Color("46594d"))
		if feedback_time > 0.0:
			var text_width: float = world.font.get_string_size(feedback_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_rect(Rect2(-text_width / 2 - 4, 31, text_width + 8, 20), Color("101617b0"))
			draw_string(world.font, Vector2(-text_width / 2, 46), feedback_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d7ea45"))
