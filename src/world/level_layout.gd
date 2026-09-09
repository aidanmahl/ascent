class_name LevelLayout
extends Resource

## Inspector-friendly override for the authored expedition. Leave platforms
## empty to use the built-in Orbital Garden campaign. Once populated, each Rect2 is
## one solid platform in world pixels: (x, y, width, height).
@export_category("Platforms")
@export var platforms: Array[Rect2] = []

## Each Rect2 is a spike strip in world pixels. These are intentionally
## simple so hazards can be dragged and resized directly in the inspector.
@export_category("Hazards")
@export var spike_strips: Array[Rect2] = []

## Enemy spawns are Vector4(x, y, kind, health): kind 0 = crawler,
## 1 = drifter, 2 = guardian. Guardian ids use the sequence guardian_0...
## and can be tuned in the inspector without changing code.
@export_category("Enemies")
@export var enemy_spawns: Array[Vector4] = []

## Optional solid boundary walls in world pixels. The built-in cave walls
## remain when this list is empty.
@export_category("Bounds")
@export var bounds: Rect2 = Rect2(0, -4144, 640, 4640)
