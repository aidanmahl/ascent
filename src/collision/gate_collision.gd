class_name GateCollision
extends RefCounted

## Gates are trigger volumes, not tiles. Keeping this separate from tile
## collision prevents a membrane from becoming solid halfway through a dash.
static func body_rect(center: Vector2, collider_size: Vector2) -> Rect2:
	return Rect2(center - collider_size * 0.5, collider_size)

static func swept_touches(from: Vector2, to: Vector2, gate: Rect2, collider_size: Vector2) -> bool:
	var expanded := gate.grow_individual(collider_size.x * 0.5, collider_size.y * 0.5, collider_size.x * 0.5, collider_size.y * 0.5)
	if expanded.has_point(from) or expanded.has_point(to):
		return true
	var distance := from.distance_to(to)
	var steps := maxi(1,ceili(distance))
	for i in range(1,steps + 1):
		if expanded.has_point(from.lerp(to,float(i)/float(steps))):
			return true
	return false

## Resolve an invalid overlap to the closest face. Returning a clear position,
## rather than a previous frame position, makes embedded recovery deterministic.
static func nearest_clear_position(center: Vector2, gate: Rect2, collider_size: Vector2, velocity: Vector2) -> Vector2:
	var expanded := gate.grow_individual(collider_size.x * 0.5, collider_size.y * 0.5, collider_size.x * 0.5, collider_size.y * 0.5)
	if not expanded.has_point(center):
		return center
	var choices := [
		Vector2(expanded.position.x - 0.05, center.y),
		Vector2(expanded.end.x + 0.05, center.y),
		Vector2(center.x, expanded.position.y - 0.05),
		Vector2(center.x, expanded.end.y + 0.05)
	]
	if absf(velocity.x) > absf(velocity.y):
		return choices[0] if velocity.x > 0 else choices[1]
	if absf(velocity.y) > 0:
		return choices[2] if velocity.y > 0 else choices[3]
	var best: Vector2 = choices[0]
	for candidate in choices:
		if candidate.distance_squared_to(center) < best.distance_squared_to(center):
			best = candidate
	return best
