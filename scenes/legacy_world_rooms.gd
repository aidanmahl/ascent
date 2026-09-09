extends Node2D

## Compact, authored detours break the expedition's old one-way rhythm. They
## sit off the shaft and use explicit door links, so they remain useful on a
## return visit without relying on a living enemy or a precision fall.
var world: Node2D
var rooms: Array[Dictionary] = []
var active_room: Dictionary = {}
var discovered: Dictionary = {}

const MAP_NODES := [
	"WRECK", "JUNCTION", "HOLLOW", "WARDEN", "RELAY", "BOOTS",
	"CHIMNEY", "SENTINEL", "GLASS", "RESERVOIR", "ROOTHEART",
	"CANOPY", "STORM", "CROWN", "SUMMIT", "ARCHIVE", "CISTERN", "ROOST"
]

func build() -> void:
	# source platform index, far-away room tile origin, and local floor row.
	_add_room("archive",7,Vector2i(-74,-10),"ARCHIVE / RECOIL VAULT",true)
	_add_room("cistern",25,Vector2i(-74,-126),"CISTERN / PHASE GARDEN",true)
	_add_room("roost",35,Vector2i(-74,-198),"ROOST / WIND KICKS",false)

func _add_room(id: String, source_index: int, origin: Vector2i, title: String, fragment: bool) -> void:
	var source: Rect2 = world.platforms[source_index]
	var floor_row := origin.y + 28
	var bounds := Rect2(origin.x*16,origin.y*16,640,480)
	# A wide floor, side walls, distinct raised cover and a high return perch.
	world._fill(origin.x,origin.x+39,floor_row,floor_row+2)
	world._fill(origin.x,origin.x+1,origin.y, floor_row)
	world._fill(origin.x+38,origin.x+39,origin.y, floor_row)
	world._fill(origin.x+7,origin.x+12,floor_row-5,floor_row-4)
	world._fill(origin.x+20,origin.x+25,floor_row-9,floor_row-8)
	world._fill(origin.x+30,origin.x+34,floor_row-4,floor_row-3)
	var entry := Vector2(source.end.x-20,source.position.y-12)
	var spawn := Vector2((origin.x+4)*16,(floor_row)*16-12)
	var exit := Vector2((origin.x+35)*16,(floor_row)*16-12)
	var room := {"id":id,"title":title,"entry":entry,"spawn":spawn,"exit":exit,"bounds":bounds,"source":source_index}
	rooms.append(room)
	# One crawler and one ranged role make each detour a compact combat space.
	world.add_enemy("crawler",Vector2((origin.x+10)*16,(floor_row-5)*16-8),id+"_crawler",2,(origin.x+7)*16,(origin.x+12)*16)
	world.add_enemy("sentry",Vector2((origin.x+23)*16,(floor_row-9)*16-16),id+"_sentry",3)
	if id == "roost":
		world.add_enemy("hunter",Vector2((origin.x+32)*16,(floor_row-4)*16-18),id+"_hunter",3,(origin.x+30)*16,(origin.x+34)*16)
	if fragment:
		world.pickups.append({"p":Vector2((origin.x+23)*16,(floor_row-9)*16-28),"kind":"fragment","lock":"","label":"SUIT FRAGMENT","taken":false})

func update(_delta: float) -> void:
	if active_room.is_empty():
		for room: Dictionary in rooms:
			if world.player.position.distance_to(room.entry) < 28:
				world.notify("E / EXPLORE " + room.title,0.1)
				if Input.is_action_just_pressed("interact"):
					enter(room)
				break
	elif world.player.position.distance_to(active_room.exit) < 30:
		world.notify("E / RETURN TO THE ASCENT",0.1)
		if Input.is_action_just_pressed("interact"):
			leave()
	queue_redraw()

func enter(room: Dictionary) -> void:
	active_room = room
	discovered[room.id] = true
	teleport(room.spawn)
	world.player.spawn_point = room.spawn
	world.player.health = world.player.max_health
	world.hostile.clear()
	world.bullets.clear()
	world.notify(room.title + " / A side route with a way back.",4)

func leave() -> void:
	var return_to: Vector2 = active_room.entry
	active_room = {}
	teleport(return_to)

func teleport(point: Vector2) -> void:
	PlayerMovement._reset(world.player.state,point)
	world.player.position = point
	world.player.previous_position = point
	world.player.ammo = world.player.max_ammo
	world.camera.position = active_room.bounds.get_center()+Vector2(0,-70) if not active_room.is_empty() else Vector2(320,point.y-48)

func _draw() -> void:
	for room: Dictionary in rooms:
		var portal: Vector2 = room.exit if not active_room.is_empty() and active_room.id == room.id else room.entry
		draw_rect(Rect2(portal-Vector2(10,25),Vector2(20,30)),Color("1d3340"))
		draw_rect(Rect2(portal-Vector2(10,25),Vector2(20,30)),Color("91d4b6"),false,2)
		draw_string(ThemeDB.fallback_font,portal+Vector2(-4,-10),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d9f3cf"))
		if not active_room.is_empty() and active_room.id == room.id:
			draw_rect(room.bounds,Color("a4dfbd"),false,2)
			draw_string(ThemeDB.fallback_font,room.bounds.position+Vector2(20,30),room.title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a4dfbd"))
