extends Node2D
class_name HanabiRangedCombat

# Gameplay owns the physics clock; visuals never poll input or advance themselves.
var world: HanabiArenaWorld
var defaults: Dictionary
var areas: Array[HanabiRangedArea] = []
var transients: Array[HanabiProjectileVisual] = []
var burns: Dictionary = {}
var telemetry: Dictionary = {"fired":[0,0,0,0,0,0],"split_children":0,"bounces":0,"pierces":0,"pools":0,"burn_hits":0}

func configure(arena: HanabiArenaWorld) -> void:
	world = arena
	defaults = JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/ranged_defaults.json"))

func weapon(role: int) -> Dictionary:
	return defaults.weapons[role]

func fire(owner: HanabiFighter, heading: Vector2) -> void:
	if not is_instance_valid(owner) or not owner.alive: return
	var cfg := weapon(owner.character_id).duplicate(true)
	if cfg.kind == "flame":
		if is_instance_valid(owner.active_flame): return
		var flame := HanabiRangedArea.new()
		flame.configure(self,owner,cfg,"flame",Vector2.ZERO)
		add_child(flame)
		areas.append(flame)
		owner.active_flame = flame
	else:
		var count := 0
		for shot in world.boomerangs:
			if is_instance_valid(shot) and not shot.expired and shot.owner_fighter == owner and not shot.child: count += 1
		if count >= int(defaults.max_primary_per_owner): return
		if cfg.kind == "knife" and is_instance_valid(owner.active_boom): return
		var origin := safe_origin(owner.position,heading,float(cfg.radius))
		var shot := spawn_projectile(owner,cfg,origin,heading,false,owner.ranged_visual_origin(heading)-origin)
		if cfg.kind == "knife": owner.active_boom = shot
		if cfg.kind == "sniper": effect(owner.character_id,&"muzzle",owner.ranged_visual_origin(heading),heading.angle())
		if cfg.kind == "ricochet": effect(owner.character_id,&"cast",owner.ranged_visual_origin(heading),heading.angle())
	telemetry.fired[owner.character_id] += 1
	world.effect.emit("throw")

func spawn_projectile(owner: HanabiFighter, cfg: Dictionary, at: Vector2, heading: Vector2, is_child: bool = false, visual_offset: Vector2 = Vector2.ZERO) -> HanabiRangedProjectile:
	var shot := HanabiRangedProjectile.new()
	shot.configure(self,owner,cfg,at,heading,is_child,visual_offset)
	add_child(shot)
	world.boomerangs.append(shot)
	return shot

func pool(owner: HanabiFighter, cfg: Dictionary, at: Vector2) -> void:
	var area := HanabiRangedArea.new()
	area.configure(self,owner,cfg,"pool",at)
	add_child(area)
	areas.append(area)
	telemetry.pools += 1

func effect(role: int, clip: StringName, at: Vector2, heading: float = 0.0) -> void:
	if transients.size() >= int(defaults.max_transient_effects): return
	var visual := HanabiProjectileVisual.new()
	visual.configure(role)
	visual.position = at
	visual.z_index = 0
	visual.auto_free_on_finish = true
	add_child(visual)
	visual.play_effect(clip,heading)
	transients.append(visual)

func ignite(target: HanabiFighter, owner: HanabiFighter, cfg: Dictionary) -> void:
	if not target.alive: return
	var key := target.get_instance_id()
	if not burns.has(key):
		var visual := HanabiProjectileVisual.new()
		visual.configure(0)
		visual.position = Vector2(0,-32)
		target.add_child(visual)
		visual.play_effect(&"burn")
		burns[key] = {"target":target,"owner":owner,"remaining":float(cfg.burn_seconds),"timer":float(cfg.burn_tick_seconds),"cfg":cfg,"visual":visual}
	else:
		# One status per target, refreshed rather than stacking a new flame each tick.
		burns[key].remaining = float(cfg.burn_seconds)
		burns[key].owner = owner
		burns[key].cfg = cfg

func step(delta: float) -> void:
	# Snapshot arrays: a wall hit may append children / a pool during this step.
	for shot in world.boomerangs.duplicate():
		if is_instance_valid(shot) and not shot.expired: shot.step(delta)
	world.boomerangs = world.boomerangs.filter(func(shot): return is_instance_valid(shot) and not shot.expired)
	for area in areas.duplicate():
		if is_instance_valid(area) and not area.expired: area.step(delta)
	areas = areas.filter(func(area): return is_instance_valid(area) and not area.expired)
	for visual in transients:
		if is_instance_valid(visual) and not visual.expired: visual.advance(delta)
	transients = transients.filter(func(visual): return is_instance_valid(visual) and not visual.expired)
	for key in burns.keys():
		var status: Dictionary = burns[key]
		if not is_instance_valid(status.target) or not status.target.alive or not is_instance_valid(status.owner):
			_remove_burn(key)
			continue
		var active_delta := minf(delta,float(status.remaining))
		status.remaining -= delta
		status.timer -= active_delta
		status.visual.advance(active_delta)
		while status.timer <= 0.0 and status.target.alive:
			status.timer += float(status.cfg.burn_tick_seconds)
			# A zero-damage burn is presentation only: no HP loss, hurt state,
			# invulnerability refresh or kill attribution after leaving the jet.
			if int(status.cfg.burn_damage) > 0 and status.target.take_hit(status.owner,int(status.cfg.burn_damage)): telemetry.burn_hits += 1
		if status.remaining <= 0.0 or not status.target.alive: _remove_burn(key)

func _remove_burn(key: int) -> void:
	var visual = burns[key].visual
	if is_instance_valid(visual): visual.queue_free()
	burns.erase(key)

func clear() -> void:
	for shot in world.boomerangs:
		if is_instance_valid(shot): shot.expired = true; shot.queue_free()
	world.boomerangs.clear()
	for area in areas:
		if is_instance_valid(area): area.expired = true; area.queue_free()
	areas.clear()
	for visual in transients:
		if is_instance_valid(visual): visual.expired = true; visual.queue_free()
	transients.clear()
	for key in burns.keys(): _remove_burn(key)
	for owner in world.fighters:
		if is_instance_valid(owner): owner.active_boom = null; owner.active_flame = null; owner.remote_held = false

func safe_origin(at: Vector2, heading: Vector2, radius: float) -> Vector2:
	var destination := at+heading.normalized()*float(defaults.spawn_distance)
	var walls := wall_contacts(at,destination,radius)
	return walls[0].point+walls[0].normal*float(defaults.wall_epsilon) if not walls.is_empty() else destination

func wall_contacts(start: Vector2, end: Vector2, radius: float = 0.0) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	for obstacle in world.collision_shapes:
		var hit := HanabiMapGeometry.sweep(start,end,obstacle.polygon,radius)
		if not hit.is_empty():
			hit.wall = obstacle.id
			contacts.append(hit)
	contacts.sort_custom(func(a,b): return a.t < b.t)
	return contacts

func enemy_contacts(owner: HanabiFighter, start: Vector2, end: Vector2, radius: float, excluded: Dictionary) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	for target in world.fighters:
		if not is_instance_valid(target) or target == owner or not target.alive or excluded.has(target.get_instance_id()): continue
		var actor_radius := (target.collider.shape as CircleShape2D).radius
		var t := sweep_circle(start,end,target.position,actor_radius+radius)
		if t >= 0.0: contacts.append({"t":t,"point":start.lerp(end,t),"target":target})
	contacts.sort_custom(func(a,b): return a.t < b.t)
	return contacts

func line_blocked(start: Vector2, end: Vector2) -> bool:
	return not wall_contacts(start,end).is_empty()

# Continuous sweeps use the exact rectangles registered by _wall for native
# StaticBody2D. Inflating by projectile radius prevents high-speed tunneling.
static func sweep_box(start: Vector2, end: Vector2, box: Rect2) -> Dictionary:
	var displacement := end-start
	if displacement.is_zero_approx(): return {}
	var entry := 0.0
	var exit := 1.0
	var normal := -displacement.normalized()
	for axis in range(2):
		var origin := start[axis]
		var direction := displacement[axis]
		var low := box.position[axis]
		var high := box.end[axis]
		if absf(direction) < 0.00001:
			if origin < low or origin > high: return {}
			continue
		var near := (low-origin)/direction
		var far := (high-origin)/direction
		var face := Vector2.ZERO
		face[axis] = -1.0 if direction > 0.0 else 1.0
		if near > far:
			var temporary := near; near = far; far = temporary
		if near >= entry: entry = near; normal = face
		exit = minf(exit,far)
		if entry > exit: return {}
	if exit < 0.0 or entry > 1.0: return {}
	return {"t":maxf(0.0,entry),"point":start.lerp(end,maxf(0.0,entry)),"normal":normal}

static func sweep_circle(start: Vector2, end: Vector2, center: Vector2, radius: float) -> float:
	var motion := end-start
	var relative := start-center
	var c := relative.length_squared()-radius*radius
	if c <= 0.0: return 0.0
	var a := motion.length_squared()
	if a < 0.000001: return -1.0
	var b := 2.0*relative.dot(motion)
	var discriminant := b*b-4.0*a*c
	if discriminant < 0.0: return -1.0
	var t := (-b-sqrt(discriminant))/(2.0*a)
	return t if t >= 0.0 and t <= 1.0 else -1.0
