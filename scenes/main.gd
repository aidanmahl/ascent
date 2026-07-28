extends Node2D

## Placeholder scaffolding only: the real room/level framework
## (TileMapLayer-backed) is milestone 7. Builds flat ground and two walls
## to test movement against - collision data plus matching colored-
## rectangle visuals (CLAUDE.md: placeholder art only) - and hands the
## collision data to the player. The player doesn't build its own world;
## see player.gd.

const TILE_SIZE := 16
const TILE_COLOR := Color(0.55, 0.4, 0.25)

@onready var player: Player = $Player

func _ready() -> void:
	var solid_tiles := _build_geometry()
	player.solid_tiles = solid_tiles
	_spawn_visuals(solid_tiles)

func _build_geometry() -> Dictionary:
	var tiles := {}
	var floor_row := 10
	for col in range(-20, 20):
		tiles[Vector2i(col, floor_row)] = true
	for row in range(4, floor_row):
		tiles[Vector2i(-8, row)] = true
		tiles[Vector2i(8, row)] = true
	return tiles

func _spawn_visuals(tiles: Dictionary) -> void:
	for coord: Vector2i in tiles:
		var rect := ColorRect.new()
		rect.color = TILE_COLOR
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		rect.position = Vector2(coord.x * TILE_SIZE, coord.y * TILE_SIZE)
		add_child(rect)
