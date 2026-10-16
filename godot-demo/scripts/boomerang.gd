extends Node2D
class_name HanabiBoomerang

var owner_fighter: HanabiFighter
var world
var velocity: Vector2 = Vector2.ZERO
var age: float = 0.0
var returning: bool = false
var expired: bool = false
var hits: Dictionary = {}
var trail: PackedVector2Array = PackedVector2Array()
var spin: float = 0.0

func configure(fighter: HanabiFighter, arena, release_aim: Vector2 = Vector2.ZERO) -> void:
	owner_fighter = fighter
	world = arena
	var direction := fighter.aim if release_aim.is_zero_approx() else release_aim.normalized()
	position = fighter.position + direction * 25.0
	velocity = direction * world.rules.throw_speed

func recall() -> void:
	if not returning:
		returning = true
		hits.clear()

func step(delta: float) -> void:
	if expired:
		return
	age += delta
	spin += delta * 23.0
	trail.append(position)
	if trail.size() > 9:
		trail.remove_at(0)
	if age >= world.rules.return_after:
		recall()
	if returning:
		velocity = (owner_fighter.position - position).normalized() * world.rules.return_speed
	var previous := position
	var destination := position + velocity * delta
	if not returning:
		var query := PhysicsRayQueryParameters2D.create(previous, destination, 2)
		var collision := get_world_2d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			destination = collision.position
			recall()
			world.burst(destination, owner_fighter.tint, 6)
	position = destination
	for opponent in world.fighters:
		if opponent == owner_fighter or not opponent.alive or hits.has(opponent.slot):
			continue
		if segment_distance(opponent.position, previous, position) < 27.0 and opponent.take_hit(owner_fighter):
			hits[opponent.slot] = true
	if (returning and segment_distance(owner_fighter.position, previous, position) < 22.0) or age > 3.0:
		expired = true
		if owner_fighter.active_boom == self:
			owner_fighter.active_boom = null
			owner_fighter.throw_cooldown = 0.15
			owner_fighter.feedback("接住", 0.35)
		world.effect.emit("catch")
		queue_free()
	queue_redraw()

static func segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))

func _draw() -> void:
	if trail.size() > 1:
		var relative := PackedVector2Array()
		for point in trail:
			relative.append(point - position)
		draw_polyline(relative, Color(owner_fighter.tint, 0.45), 6.0, true)
	draw_set_transform(Vector2.ZERO, spin)
	var vertices := PackedVector2Array([Vector2(0, -4), Vector2(-17, -17), Vector2(-22, -10), Vector2(-3, 8), Vector2(3, 8), Vector2(22, -10), Vector2(17, -17)])
	draw_colored_polygon(vertices, Color("fff4d6"))
	draw_polyline(PackedVector2Array([Vector2(-15, -10), Vector2(0, 4), Vector2(15, -10)]), owner_fighter.tint, 3.0, true)
	draw_set_transform(Vector2.ZERO)
