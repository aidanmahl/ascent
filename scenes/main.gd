extends Node2D

## Placeholder scaffolding only: the real room/level framework
## (TileMapLayer-backed) is milestone 7. Builds a movement gym to test
## tuning against - collision data plus matching colored-rectangle
## visuals (CLAUDE.md: placeholder art only) - and hands the collision
## data to the player. The player doesn't build its own world; see
## player.gd.
##
## This is a milestone 4 tuning aid, NOT the sample level from SPEC.md
## section 9 (that's milestone 10, authored after tuning is signed off).
## Ugly and functional on purpose: every section exercises one mechanic
## (or a combo) in isolation so movement feel can be judged section by
## section, then chains them so nothing needs a restart to reach.

const TILE_SIZE := 16
const TILE_COLOR := Color(0.55, 0.4, 0.25)

## No room system yet (milestone 7), so "reset" - R, or falling below
## KILL_PLANE_Y - means this level spawn point, not a room start.
const SPAWN_POINT := Vector2(0, 400)
## Comfortably below every section's floor (lowest is row 30, y=480-496) -
## the dash-required gap (section B) has no floor under it at all, so
## missing that dash currently means falling forever without this.
const KILL_PLANE_Y := 1000.0

@onready var player: Player = $Player

func _ready() -> void:
	var solid_tiles := _build_geometry()
	player.solid_tiles = solid_tiles
	player.spawn_point = SPAWN_POINT
	player.kill_plane_y = KILL_PLANE_Y
	player.position = SPAWN_POINT
	_spawn_visuals(solid_tiles)

## Row numbers decrease upward (Godot's Y-down convention) - the level
## climbs from floor_row at the bottom toward increasingly negative rows,
## matching the game's name. Column/row math below is annotated with the
## approximate pixel sizes it produces (tile_size = 16px) against the
## default_movement_config.tres values current as of milestone 4 tuning
## iteration 1: max jump height ~49.5px, idealized max jump distance
## ~87.5px (already-at-top-speed, the SPEC.md "compute from config" upper
## bound - a realistic short-run-up jump lands well under this), dash
## distance ~81.2px (11 frames at 7.0 + 1 retained frame at 4.2).
##
## Worth knowing: with the reduced gravity, dash's ~81px range is now
## SHORTER than jump's idealized ~87.5px max, so a gap that's cleanly
## "dash-only, not jump-able" doesn't really exist at the theoretical
## extremes - the dash gap below (80px) is sized to need a confident dash
## and to be past what a realistic (non-idealized-runup) jump reaches, not
## to be mathematically jump-proof. Flagging this rather than quietly
## picking numbers that hide it - if you want a cleaner separation, the
## lever is dash_speed/dash_duration_frames or air_acceleration, not
## something this geometry pass should be deciding on its own.
func _build_geometry() -> Dictionary:
	var tiles := {}
	var floor_row := 30

	# --- A: long flat run - top speed and stopping distance ---
	_fill_rect(tiles, -4, 40, floor_row, floor_row)
	_fill_rect(tiles, -5, -5, 10, floor_row)  # left boundary wall

	# --- B: dash-required gap (cols 41-46 empty, 5 tiles = 80px) ---
	_fill_rect(tiles, 47, 65, floor_row, floor_row)

	# --- C: overhang / ceiling corridor (same row as B's landing) ---
	# Low ceiling over cols 52-58 (3 tiles / 48px clearance - blocks a
	# full jump, passable at a run). Gap in the ceiling at 60-63 leaves
	# room to jump freely for comparison.
	_fill_rect(tiles, 52, 58, floor_row - 3, floor_row - 3)

	# --- D: floating platforms - double jump only ---
	# Each step is 4 rows (64px) above the last: clears the ~49.5px
	# single-jump max, within double-jump reach.
	_fill_rect(tiles, 66, 68, floor_row, floor_row)
	_fill_rect(tiles, 69, 71, floor_row - 4, floor_row - 4)
	_fill_rect(tiles, 72, 74, floor_row - 8, floor_row - 8)
	_fill_rect(tiles, 75, 77, floor_row - 12, floor_row - 12)
	_fill_rect(tiles, 78, 80, floor_row - 16, floor_row - 16)

	# --- E: vertical wall-jump shaft ---
	# 3-tile-wide (48px) shaft, 20 rows (320px) tall, climbed from the
	# last floating platform (D) via chained wall jumps.
	var shaft_top := floor_row - 16 - 20
	_fill_rect(tiles, 82, 82, shaft_top, floor_row - 16)
	_fill_rect(tiles, 86, 86, shaft_top, floor_row - 16)
	var landing_row := shaft_top - 1
	_fill_rect(tiles, 86, 90, landing_row, landing_row)  # landing at the top

	# --- G: dash+jump gap ---
	# 9 tiles (144px) at cols 91-99, flat, well beyond either dash or
	# jump alone: needs the exit-retention momentum from a dash carried
	# into a jump (or vice versa) to cross. Landing continues to col 111
	# so there's room to walk up to section F without a running start.
	_fill_rect(tiles, 100, 111, landing_row, landing_row)

	# --- F: wall-to-wall climbing at varying widths ---
	# Two dead-end shafts branching up from the G landing, narrower and
	# wider than E's 3 tiles - each capped with a small platform; falling
	# back off either (no fall damage) returns to the G landing below.
	var f_wall_bottom := landing_row - 1
	var f_wall_top := f_wall_bottom - 11
	var f_cap := f_wall_top - 1

	_fill_rect(tiles, 112, 112, f_wall_top, f_wall_bottom)  # 2-tile gap (32px)
	_fill_rect(tiles, 115, 115, f_wall_top, f_wall_bottom)
	_fill_rect(tiles, 112, 115, f_cap, f_cap)

	_fill_rect(tiles, 119, 119, f_wall_top, f_wall_bottom)  # 4-tile gap (64px)
	_fill_rect(tiles, 124, 124, f_wall_top, f_wall_bottom)
	_fill_rect(tiles, 119, 124, f_cap, f_cap)

	return tiles

func _fill_rect(tiles: Dictionary, col0: int, col1: int, row0: int, row1: int) -> void:
	for col in range(col0, col1 + 1):
		for row in range(row0, row1 + 1):
			tiles[Vector2i(col, row)] = true

func _spawn_visuals(tiles: Dictionary) -> void:
	for coord: Vector2i in tiles:
		var rect := ColorRect.new()
		rect.color = TILE_COLOR
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		rect.position = Vector2(coord.x * TILE_SIZE, coord.y * TILE_SIZE)
		add_child(rect)
