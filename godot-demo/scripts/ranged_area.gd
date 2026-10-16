extends Node2D
class_name HanabiRangedArea

var combat: HanabiRangedCombat
var owner_fighter: HanabiFighter
var cfg: Dictionary
var kind: String
var visual: HanabiProjectileVisual
var expired := false
var stopping := false
var age := 0.0
var pulse := 0.0
var phase: StringName
var next_flame_hit: Dictionary = {}

func configure(manager: HanabiRangedCombat, owner: HanabiFighter, settings: Dictionary, type: String, at: Vector2) -> void:
	combat = manager; owner_fighter = owner; cfg = settings; kind = type
	position = at
	visual = HanabiProjectileVisual.new()
	visual.configure(owner.character_id)
	add_child(visual)
	phase = &"start" if kind == "flame" else &"pool"
	visual.play_effect(phase)
	if kind == "flame":
		visual.scale = Vector2.ONE*float(cfg.range)/(144.0*HanabiFighterAnimation.GAME_SCALE)
		_follow_owner()
		z_index = 0
	else:
		visual.scale = Vector2.ONE*(2.0*float(cfg.pool_radius))/(128.0*HanabiFighterAnimation.GAME_SCALE)
		z_index = -5

func _follow_owner() -> void:
	position = combat.safe_origin(owner_fighter.position,owner_fighter.aim,0.0)
	visual.position = owner_fighter.ranged_visual_origin(owner_fighter.aim)-position
	visual.rotation = owner_fighter.aim.angle()

func stop() -> void:
	if stopping or expired: return
	stopping = true
	phase = &"stop" if kind == "flame" else &"expire"
	visual.play_effect(phase,visual.rotation if kind == "flame" else 0.0)

func step(delta: float) -> void:
	if expired: return
	if not is_instance_valid(owner_fighter): _finish(); return
	age += delta
	if kind == "flame":
		_follow_owner()
		if not owner_fighter.alive or not owner_fighter.remote_held or owner_fighter.action_state in [&"hurt",&"dash",&"knockdown"]: stop()
	elif age >= float(cfg.pool_seconds): stop()
	if not stopping:
		if kind == "flame":
			# Check contact every physics frame. Each target has its own damage
			# interval, so a new target does not wait for another target's pulse.
			_damage()
		else:
			pulse -= delta
			while pulse <= 0.0:
				pulse += float(cfg.pool_tick_seconds)
				_damage()
	var finished := visual.advance(delta)
	if finished and stopping: _finish()
	elif finished and phase == &"start":
		phase = &"jet"
		visual.play_effect(&"jet",visual.rotation)

func _damage() -> void:
	for target in combat.world.fighters:
		if not is_instance_valid(target) or target == owner_fighter or not target.alive: continue
		var relative := target.position-position
		var inside := relative.length() <= float(cfg.range) and (relative.is_zero_approx() or relative.normalized().dot(owner_fighter.aim) >= cos(deg_to_rad(float(cfg.half_angle_degrees)))) if kind == "flame" else relative.length() <= float(cfg.pool_radius)+combat.world.rules.fighter_radius
		if not inside: continue
		if kind == "flame" and bool(cfg.blocked_by_walls) and combat.line_blocked(position,target.position): continue
		var key := target.get_instance_id()
		if kind == "flame" and age+0.000001 < float(next_flame_hit.get(key,0.0)): continue
		if target.take_hit(owner_fighter,int(cfg.damage if kind == "flame" else cfg.pool_damage)) and kind == "flame":
			next_flame_hit[key] = age+float(cfg.pulse_seconds)
			combat.ignite(target,owner_fighter,cfg)

func _finish() -> void:
	expired = true
	if is_instance_valid(owner_fighter) and owner_fighter.active_flame == self: owner_fighter.active_flame = null
	queue_free()
