extends RefCounted
class_name HanabiMapGeometry

static func polygon(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values: result.append(Vector2(value[0],value[1]))
	return result

static func rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func closest(point: Vector2, shape: PackedVector2Array) -> Dictionary:
	var distance := INF
	var at := Vector2.ZERO
	var normal := Vector2.ZERO
	var signed_area := 0.0
	for i in shape.size(): signed_area += shape[i].cross(shape[(i+1)%shape.size()])
	for i in shape.size():
		var a := shape[i]; var b := shape[(i+1)%shape.size()]
		var candidate := Geometry2D.get_closest_point_to_segment(point,a,b)
		var current := point.distance_squared_to(candidate)
		if current < distance:
			distance = current; at = candidate
			normal = (b-a).orthogonal().normalized()*(1.0 if signed_area > 0.0 else -1.0)
	return {"distance":sqrt(distance),"point":at,"normal":normal}

static func circle_clear(point: Vector2, radius: float, shapes: Array[Dictionary]) -> bool:
	for obstacle in shapes:
		var shape: PackedVector2Array = obstacle.polygon
		if Geometry2D.is_point_in_polygon(point,shape) or closest(point,shape).distance < radius-0.0001: return false
	return true

static func sweep(start: Vector2, end: Vector2, shape: PackedVector2Array, radius: float = 0.0) -> Dictionary:
	var motion := end-start
	if motion.is_zero_approx(): return {}
	var nearest := closest(start,shape)
	if Geometry2D.is_point_in_polygon(start,shape): return {"t":0.0,"point":start,"normal":nearest.normal}
	var overlap_normal: Vector2 = (start-Vector2(nearest.point)).normalized()
	if nearest.distance <= radius+0.00001 and motion.dot(overlap_normal) < -0.00001:
		return {"t":0.0,"point":start,"normal":overlap_normal}
	var best: Dictionary = {}
	var best_t := INF
	var area := 0.0
	for i in shape.size(): area += shape[i].cross(shape[(i+1)%shape.size()])
	for i in shape.size():
		var a := shape[i]; var b := shape[(i+1)%shape.size()]
		var edge := b-a
		var normal := edge.orthogonal().normalized()*(1.0 if area > 0.0 else -1.0)
		var approach := motion.dot(normal)
		if approach < -0.000001:
			var t := (radius-(start-a).dot(normal))/approach
			if t >= -0.000001 and t <= 1.0 and t < best_t:
				var point := start+motion*maxf(0.0,t)
				var u := (point-normal*radius-a).dot(edge)/edge.length_squared()
				if u >= -0.000001 and u <= 1.000001:
					best_t = maxf(0.0,t)
					best = {"t":best_t,"point":point,"normal":normal}
		if radius > 0.0:
			# Swept circle against the endpoint capsule: true diagonal normals,
			# including concave L-shaped gaps, without bounding-box blockage.
			var t := HanabiRangedCombat.sweep_circle(start,end,a,radius)
			if t >= 0.0 and t < best_t:
				var point := start.lerp(end,t)
				var n := (point-a).normalized()
				if motion.dot(n) < -0.000001:
					best_t = t; best = {"t":t,"point":point,"normal":n}
	return best
