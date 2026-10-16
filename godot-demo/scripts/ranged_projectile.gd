extends Node2D
class_name HanabiRangedProjectile

var combat: HanabiRangedCombat
var owner_fighter: HanabiFighter
var world: HanabiArenaWorld
var cfg: Dictionary
var role_id: int
var kind: String
var velocity := Vector2.ZERO
var age := 0.0
var distance := 0.0
var returning := false
var expired := false
var child := false
var split_depth := 0
var hits: Dictionary = {}
var pierced_walls: Dictionary = {}
var bounces_remaining := 0
var visual: HanabiProjectileVisual
var visual_offset := Vector2.ZERO

func configure(manager: HanabiRangedCombat, owner: HanabiFighter, settings: Dictionary, at: Vector2, heading: Vector2, is_child: bool, offset: Vector2) -> void:
	combat = manager; world = manager.world; owner_fighter = owner
	cfg = settings; role_id = owner.character_id; kind = str(cfg.kind)
	position = at; child = is_child; visual_offset = offset
	velocity = heading.normalized()*float(cfg.child_speed if child else cfg.speed)
	bounces_remaining = int(cfg.get("bounces",0))
	visual = HanabiProjectileVisual.new()
	visual.configure(role_id)
	visual.position = visual_offset
	add_child(visual)
	visual.play_effect(&"child" if child else &"flight",velocity.angle())
	z_index = 0

func recall() -> void:
	# Melee can recall a knife, but never turns another weapon into a knife.
	if kind != "knife" or expired or returning: return
	returning = true
	hits.clear()
	visual.play_effect(&"return",velocity.angle())

func step(delta: float) -> void:
	if expired: return
	if not is_instance_valid(owner_fighter): terminate(); return
	age += delta
	if kind == "knife" and age >= float(cfg.return_after): recall()
	if returning: velocity = (owner_fighter.position-position).normalized()*float(cfg.return_speed)
	var lifetime := float(cfg.child_lifetime if child else cfg.lifetime)
	var limit := float(cfg.child_range if child else cfg.range)
	# Clamp the final sweep to the configured range / lifetime.
	var budget := minf(delta,maxf(0.0,lifetime-(age-delta)))
	if not returning: budget = minf(budget,maxf(0.0,limit-distance)/maxf(velocity.length(),1.0))
	if returning:
		var end := position+velocity*budget
		var catch_t := HanabiRangedCombat.sweep_circle(position,end,owner_fighter.position,float(cfg.catch_radius))
		if catch_t >= 0.0: end = position.lerp(end,catch_t)
		_damage_line(position,end)
		position = end
		if catch_t >= 0.0:
			combat.effect(role_id,&"catch",owner_fighter.ranged_visual_origin(owner_fighter.aim))
			owner_fighter.feedback("接住",0.35)
			world.effect.emit("catch")
			terminate()
	elif kind == "sniper":
		_sniper_sweep(budget)
	else:
		_solid_sweep(budget)
	if not expired:
		visual.rotation = velocity.angle()
		visual.advance(delta)
		if age >= lifetime or (not returning and distance >= limit) or not world.field.grow(180.0).has_point(position):
			if kind == "knife" and age < lifetime: recall()
			else: terminate(true)

func _damage_line(start: Vector2, end: Vector2) -> void:
	for contact in combat.enemy_contacts(owner_fighter,start,end,float(cfg.radius),hits):
		var target: HanabiFighter = contact.target
		if target.take_hit(owner_fighter,int(cfg.damage)):
			hits[target.get_instance_id()] = true
			combat.effect(role_id,&"impact",contact.point+visual_offset,velocity.angle())

func _sniper_sweep(seconds: float) -> void:
	var end := position+velocity*seconds
	var enemies := combat.enemy_contacts(owner_fighter,position,end,float(cfg.radius),hits)
	var stop_t := 1.0
	if not bool(cfg.pierce_enemies) and not enemies.is_empty(): stop_t = enemies[0].t
	for wall in combat.wall_contacts(position,end,float(cfg.radius)):
		if wall.t > stop_t: break
		if not pierced_walls.has(wall.wall):
			pierced_walls[wall.wall] = true
			combat.telemetry.pierces += 1
			combat.effect(role_id,&"pierce",wall.point+visual_offset,velocity.angle())
	for contact in enemies:
		if contact.t > stop_t: break
		var target: HanabiFighter = contact.target
		target.take_hit(owner_fighter,int(cfg.damage))
		hits[target.get_instance_id()] = true
		combat.effect(role_id,&"impact",contact.point+visual_offset,velocity.angle())
	var destination := position.lerp(end,stop_t)
	distance += position.distance_to(destination)
	position = destination
	if not bool(cfg.pierce_enemies) and not enemies.is_empty(): terminate()

func _solid_sweep(seconds: float) -> void:
	var remaining := seconds
	# Multiple contacts can occur in one physics tick. Continue residual travel
	# after a bounce, separating along the collision normal before the next sweep.
	for guard in range(16):
		if expired or remaining <= 0.000001: break
		var end := position+velocity*remaining
		var walls := combat.wall_contacts(position,end,float(cfg.radius))
		var enemies := combat.enemy_contacts(owner_fighter,position,end,float(cfg.radius),hits)
		var wall_t := float(walls[0].t) if not walls.is_empty() else INF
		var enemy_t := float(enemies[0].t) if not enemies.is_empty() else INF
		if wall_t == INF and enemy_t == INF:
			distance += position.distance_to(end); position = end; break
		var is_wall := wall_t <= enemy_t
		var contact: Dictionary = walls[0] if is_wall else enemies[0]
		var t := float(contact.t)
		var at: Vector2 = contact.point
		distance += position.distance_to(at); position = at
		remaining *= maxf(0.0,1.0-t)
		var normal: Vector2 = contact.normal if is_wall else (at-contact.target.position).normalized()
		if is_wall:
			# A corner can contact two native faces at the same instant. Reflect
			# their combined normal once, rather than spending two bounce charges.
			for adjacent in walls:
				if adjacent == contact: continue
				if absf(float(adjacent.t)-t) > 0.000001: break
				normal += Vector2(adjacent.normal)
			normal = normal.normalized()
		if normal.is_zero_approx(): normal = -velocity.normalized()
		if not is_wall:
			var target: HanabiFighter = contact.target
			hits[target.get_instance_id()] = true
			target.take_hit(owner_fighter,int(cfg.child_damage if child else cfg.damage))
		if kind == "knife":
			combat.effect(role_id,&"impact",at+visual_offset,velocity.angle())
			if is_wall: recall(); break
			position += velocity.normalized()*float(combat.defaults.wall_epsilon)
			continue
		if kind == "ricochet" and bool(cfg.bounce_walls if is_wall else cfg.bounce_enemies) and bounces_remaining > 0:
			bounces_remaining -= 1
			combat.telemetry.bounces += 1
			combat.effect(role_id,&"bounce",at+visual_offset,velocity.angle())
			velocity = velocity.bounce(normal)
			position = at+normal*float(combat.defaults.wall_epsilon)
			continue
		if kind == "poison":
			combat.effect(role_id,&"burst",at+visual_offset)
			if is_wall or bool(cfg.pool_on_enemy): combat.pool(owner_fighter,cfg,at+normal*float(combat.defaults.wall_epsilon))
			terminate(); break
		if kind == "split" and is_wall and (not child or (bool(cfg.children_split) and split_depth < int(cfg.get("max_split_depth",1)))):
			combat.effect(role_id,&"split",at+visual_offset)
			var reflected := velocity.normalized().bounce(normal)
			for degrees in [-float(cfg.split_degrees),0.0,float(cfg.split_degrees)]:
				var heading := reflected.rotated(deg_to_rad(degrees))
				if heading.dot(normal) < 0.05: heading = (heading+normal*(0.05-heading.dot(normal))).normalized()
				var spawned := combat.spawn_projectile(owner_fighter,cfg,at+normal*float(combat.defaults.wall_epsilon),heading,true,visual_offset)
				spawned.split_depth = split_depth+1
				combat.telemetry.split_children += 1
			terminate(); break
		terminate(true); break

func terminate(with_effect: bool = false) -> void:
	if expired: return
	if with_effect and is_instance_valid(owner_fighter):
		combat.effect(role_id,&"burst" if kind == "poison" else &"impact",position+visual_offset,velocity.angle())
	expired = true
	if is_instance_valid(owner_fighter) and owner_fighter.active_boom == self: owner_fighter.active_boom = null
	queue_free()
