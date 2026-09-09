extends Node2D

var world: Node2D
var rooms: Array[Dictionary] = []
var active_room: Dictionary = {}
var discovered: Dictionary = {}
var visited_anchors: Dictionary = {}
var entry_grace := 0.0

func build() -> void:
	rooms = world.campaign.rooms
	update_membership()

func update_membership() -> void:
	var id := CampaignLayout.room_at(world.player.position)
	if id > 0 and (active_room.is_empty() or active_room.id != id):
		active_room = rooms[id-1]
		discovered[id] = true
		entry_grace = 1.0
		if world.started:
			world.notify(active_room.name.to_upper(),3)
	for edge: Dictionary in world.campaign.edges:
		if int(edge.a)==id or int(edge.b)==id:
			edge.seen = true

func update(delta: float) -> void:
	update_membership()
	entry_grace = maxf(0,entry_grace-delta)
	for mechanism: Dictionary in world.campaign.mechanisms:
		if world.locks.get(mechanism.flag,false):
			continue
		if not mechanism.needs.is_empty() and not world.locks.get(mechanism.needs,false):
			continue
		if world.player.position.distance_to(mechanism.p)<30:
			world.locks[mechanism.flag] = true
			world.notify(mechanism.label,5)
			world.sound("save")
	world.locks["wind"] = world.locks.get("pump",false) and world.locks.get("core",false)
	# Kinematic platforms move the body only while supported, without resetting
	# velocity/resources or changing rooms. Tiles remain the static collision source.
	for lift: Dictionary in world.campaign.lifts:
		lift.last_y = lift.y
		if not world.locks.get(lift.flag,false):
			continue
		lift.phase += delta * 0.65
		lift.y = lerpf(lift.bottom,lift.top,(1.0-cos(lift.phase))*0.5)
		var p: Player = world.player
		var feet := p.position.y+8
		if absf(p.position.x-float(lift.x))<60 and p.state.velocity.y>=0 and feet>=float(lift.last_y)-7 and feet<=float(lift.last_y)+12:
			p.position.y = lift.y-8
			p.state.position = p.position
			p.state.velocity.y = 0
			p.state.on_floor = true
			p.state.dash_available = p.dash_unlocked
			p.state.wall_kick_available = true
			p.ammo = p.max_ammo
	queue_redraw()

func camera_target() -> Vector2:
	var p: Player = world.player
	var lead := clampf(p.state.velocity.x*9,-48,48)
	return Vector2(clampf(p.position.x+lead,320,2880),clampf(p.position.y-35,180,2220))

func _draw() -> void:
	for lift: Dictionary in world.campaign.lifts:
		var tint := Color("c6ddac") if world.locks.get(lift.flag,false) else Color("526565")
		draw_line(Vector2(lift.x,lift.top),Vector2(lift.x,lift.bottom),Color("456564"),2)
		draw_rect(Rect2(lift.x-64,lift.y,128,8),Color("254747"))
		draw_line(Vector2(lift.x-64,lift.y),Vector2(lift.x+64,lift.y),tint,3)
		for x in [-36,36]:
			draw_circle(Vector2(lift.x+x,lift.y+7),4,tint)
	for mechanism: Dictionary in world.campaign.mechanisms:
		var p: Vector2 = mechanism.p
		var lit: bool = world.locks.get(mechanism.flag,false)
		draw_arc(p,17,0,TAU,12,Color("9ae7c2") if lit else Color("d4ae76"),3)
		for n in range(4):
			var d := Vector2.RIGHT.rotated(n*PI/2+world.time*(0.4 if lit else 0))
			draw_line(p-d*12,p+d*12,Color("738f84"),2)
