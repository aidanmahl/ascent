class_name TileCollision

## Pure AABB-vs-tile-grid collision resolution. No engine calls, no node
## lookups - solid geometry is a plain Dictionary[Vector2i, bool] the
## caller builds however it likes (from a real TileMapLayer at runtime, or
## synthetic in tests). This is what makes coyote time, jump buffer, and
## corner correction testable headlessly: the same pure function runs in
## the game and in a test with a hand-built solid_tiles dict.
##
## Discrete (non-swept) resolution: move the full axis delta, then clamp
## back on overlap. This only avoids tunneling because every movement
## speed in MovementConfig stays below tile_size (16px) - see the
## "never tunnels at max possible speed" test, which asserts that
## invariant explicitly rather than assuming it silently holds forever.
##
## The collider AABB is centered on `position` (matches the player's
## visual, which is centered on its Node2D position).

const EPS := 0.01

static func resolve(position: Vector2, velocity: Vector2, collider_size: Vector2, solid_tiles: Dictionary, tile_size: int, corner_correction_px: float) -> Dictionary:
	var pos := position
	var vel := velocity

	pos.x += vel.x
	var x_result := _resolve_x(pos, collider_size, vel.x, solid_tiles, tile_size)
	pos.x = x_result.x
	if x_result.collided:
		vel.x = 0.0

	pos.y += vel.y
	var y_result := _resolve_y(pos, collider_size, vel.y, solid_tiles, tile_size, corner_correction_px)
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
	}

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

static func _resolve_y(pos: Vector2, size: Vector2, vel_y: float, solid_tiles: Dictionary, tile_size: int, corner_correction_px: float) -> Dictionary:
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

	var blocking_cols: Array[int] = []
	for col in range(col_min, col_max + 1):
		if solid_tiles.has(Vector2i(col, row)):
			blocking_cols.append(col)

	if blocking_cols.is_empty():
		return {"position": pos, "collided": false}

	if blocking_cols.size() == 1:
		var corrected := _try_corner_correction(pos, half, blocking_cols[0], row, left, right, solid_tiles, tile_size, corner_correction_px)
		if corrected.corrected:
			return {"position": corrected.position, "collided": false}

	var result_pos := pos
	if vel_y > 0.0:
		result_pos.y = row * tile_size - half.y
	else:
		result_pos.y = (row + 1) * tile_size + half.y
	return {"position": result_pos, "collided": true}

## If the AABB only clips a single blocking tile by <= corner_correction_px
## on one side, and the tile beside it (across the AABB's full height) is
## clear, nudge sideways out of the corner instead of blocking.
static func _try_corner_correction(pos: Vector2, half: Vector2, blocking_col: int, row: int, left: float, right: float, solid_tiles: Dictionary, tile_size: int, corner_correction_px: float) -> Dictionary:
	var tile_left := float(blocking_col * tile_size)
	var tile_right := tile_left + tile_size
	var overlap_from_left := right - tile_left
	var overlap_from_right := tile_right - left

	var nudge := 0.0
	var nudge_dir := 0
	if overlap_from_left <= corner_correction_px and overlap_from_left <= overlap_from_right:
		nudge = overlap_from_left
		nudge_dir = -1
	elif overlap_from_right <= corner_correction_px:
		nudge = overlap_from_right
		nudge_dir = 1

	if nudge <= 0.0:
		return {"corrected": false}

	var nudge_col := blocking_col + nudge_dir
	var row_min := _to_tile(pos.y - half.y + EPS, tile_size)
	var row_max := _to_tile(pos.y + half.y - EPS, tile_size)
	for r in range(row_min, row_max + 1):
		if solid_tiles.has(Vector2i(nudge_col, r)):
			return {"corrected": false}

	var corrected_pos := pos
	corrected_pos.x += float(nudge_dir) * nudge
	return {"corrected": true, "position": corrected_pos}
