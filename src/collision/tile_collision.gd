class_name TileCollision

## Pure AABB-vs-tile-grid collision resolution. No engine calls, no node
## lookups - solid geometry is a plain Dictionary[Vector2i, bool] the
## caller builds however it likes (from a real TileMapLayer at runtime, or
## synthetic in tests). This is what makes coyote time, jump buffer, and
## collision resolution testable headlessly: the same pure function runs
## in the game and in a test with a hand-built solid_tiles dict.
##
## Discrete (non-swept) resolution: move the full axis delta, then clamp
## back on overlap. This only avoids tunneling because every movement
## speed in MovementConfig stays below tile_size (16px) - see the
## "never tunnels at max possible speed" test, which asserts that
## invariant explicitly rather than assuming it silently holds forever.
##
## The collider AABB is centered on `position` (matches the player's
## visual, which is centered on its Node2D position).
##
## Milestone 4 tuning iteration 3: replaced the old per-corner "nudge"
## correction (which only handled the ceiling case, made jumping into a
## platform corner feel unforgiving anyway since it never applied to the
## X axis, AND actively broke ledge-standing by nudging players off an
## edge during floor resolution) with a horizontal-only margin: the actual
## collision width used here is collider_size.x minus
## collision_width_margin_px on each side - narrower than the visual
## sprite, so a few pixels of visual overlap on either a jump-up corner or
## a ledge edge never registers as contact at all. No snap, no special
## case, no asymmetry between "helps" and "hurts" - one number, applied
## uniformly to both axes' horizontal extent. Height is untouched.

const EPS := 0.01

static func resolve(position: Vector2, velocity: Vector2, collider_size: Vector2, solid_tiles: Dictionary, tile_size: int, collision_width_margin_px: float) -> Dictionary:
	var pos := position
	var vel := velocity
	var size := Vector2(maxf(collider_size.x - collision_width_margin_px * 2.0, 1.0), collider_size.y)

	pos.x += vel.x
	var x_result := _resolve_x(pos, size, vel.x, solid_tiles, tile_size)
	pos.x = x_result.x
	var on_wall_left := false
	var on_wall_right := false
	if x_result.collided:
		if vel.x < 0.0:
			on_wall_left = true
		else:
			on_wall_right = true
		vel.x = 0.0

	pos.y += vel.y
	var y_result := _resolve_y(pos, size, vel.y, solid_tiles, tile_size)
	pos = y_result.position
	var on_floor := false
	var on_ceiling := false
	if y_result.collided:
		if vel.y > 0.0:
			on_floor = true
		else:
			on_ceiling = true
		vel.y = 0.0

	return {
		"position": pos,
		"velocity": vel,
		"on_floor": on_floor,
		"on_ceiling": on_ceiling,
		"on_wall_left": on_wall_left,
		"on_wall_right": on_wall_right,
	}

## Pure proximity probe - no velocity, no movement, no collision response.
## True if a solid tile is immediately adjacent on `side` (-1 left, 1
## right) to a collider currently resting at `position`. This exists
## because on_wall_left/right (returned by resolve() above) only reads
## true on a frame where an actual nonzero-velocity collision occurs - the
## instant velocity.x hits 0 (e.g. friction settling a released "into"
## press to rest), resolve() never runs _resolve_x's collision check at
## all and the flag goes false regardless of whether the collider is still
## physically touching the wall. Callers that need to know "is this thing
## still actually beside a wall" independent of this frame's velocity (see
## player_movement.gd's _update_wall_attachment) need this instead.
##
## Assumes `position` is already resting exactly at a tile boundary on
## that side (true whenever it got there via resolve()'s own collision
## response) - the EPS probes just outside the edge to identify which tile
## column the edge is resting against, mirroring _resolve_x's own column
## math exactly (see the two branches there) so this agrees with whatever
## resolve() would have reported had this frame been a real collision.
static func is_touching_wall(position: Vector2, collider_size: Vector2, solid_tiles: Dictionary, tile_size: int, collision_width_margin_px: float, side: float) -> bool:
	if side == 0.0:
		return false

	var half := Vector2(maxf(collider_size.x - collision_width_margin_px * 2.0, 1.0), collider_size.y) * 0.5
	var row_min := _to_tile(position.y - half.y + EPS, tile_size)
	var row_max := _to_tile(position.y + half.y - EPS, tile_size)
	var col: int
	if side < 0.0:
		col = _to_tile(position.x - half.x - EPS, tile_size)
	else:
		col = _to_tile(position.x + half.x + EPS, tile_size)

	for row in range(row_min, row_max + 1):
		if solid_tiles.has(Vector2i(col, row)):
			return true
	return false

static func _to_tile(coord: float, tile_size: int) -> int:
	return int(floor(coord / float(tile_size)))

static func _resolve_x(pos: Vector2, size: Vector2, vel_x: float, solid_tiles: Dictionary, tile_size: int) -> Dictionary:
	if vel_x == 0.0:
		return {"x": pos.x, "collided": false}

	var half := size * 0.5
	var row_min := _to_tile(pos.y - half.y + EPS, tile_size)
	var row_max := _to_tile(pos.y + half.y - EPS, tile_size)

	if vel_x > 0.0:
		var col := _to_tile(pos.x + half.x - EPS, tile_size)
		for row in range(row_min, row_max + 1):
			if solid_tiles.has(Vector2i(col, row)):
				return {"x": col * tile_size - half.x, "collided": true}
	else:
		var col := _to_tile(pos.x - half.x + EPS, tile_size)
		for row in range(row_min, row_max + 1):
			if solid_tiles.has(Vector2i(col, row)):
				return {"x": (col + 1) * tile_size + half.x, "collided": true}

	return {"x": pos.x, "collided": false}

static func _resolve_y(pos: Vector2, size: Vector2, vel_y: float, solid_tiles: Dictionary, tile_size: int) -> Dictionary:
	if vel_y == 0.0:
		return {"position": pos, "collided": false}

	var half := size * 0.5
	var left := pos.x - half.x
	var right := pos.x + half.x
	var col_min := _to_tile(left + EPS, tile_size)
	var col_max := _to_tile(right - EPS, tile_size)

	var row: int
	if vel_y > 0.0:
		row = _to_tile(pos.y + half.y - EPS, tile_size)
	else:
		row = _to_tile(pos.y - half.y + EPS, tile_size)

	var blocking := false
	for col in range(col_min, col_max + 1):
		if solid_tiles.has(Vector2i(col, row)):
			blocking = true
			break

	if not blocking:
		return {"position": pos, "collided": false}

	var result_pos := pos
	if vel_y > 0.0:
		result_pos.y = row * tile_size - half.y
	else:
		result_pos.y = (row + 1) * tile_size + half.y
	return {"position": result_pos, "collided": true}
