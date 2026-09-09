extends Node2D

var world: Node2D
var rooms: Array[Dictionary] = []
var active_room: Dictionary = {}
var attacks: Array[Dictionary] = []

func build() -> void:
	var ids := ["warden","sentinel","reservoir","crown"]
	var ledges := [11,23,29,41]
	for i in range(4):
		var shelf: Rect2 = world.platforms[ledges[i]]
		var floor_y := int(shelf.position.y)
		var room := {"id":ids[i],"door":Vector2(shelf.position.x+20,floor_y-12),
			"spawn":Vector2(752,floor_y-8),"center":Vector2(960,floor_y-120),"floor":floor_y}
		rooms.append(room)
		world._fill(44,75,floor_y/16,floor_y/16+1)
		world._fill(44,44,floor_y/16-18,floor_y/16)
		world._fill(75,75,floor_y/16-18,floor_y/16)
		world._fill(44,75,floor_y/16-18,floor_y/16-18)
		# Low islands are reachable with an ordinary jump, and let players
		# evade floor sweeps without spending their offensive magazine.
		world._fill(51,55,floor_y/16-2,floor_y/16-2)
		world._fill(64,68,floor_y/16-2,floor_y/16-2)
		for enemy: Dictionary in world.enemies:
			if enemy.id == ids[i]:
				enemy.home = room.center
				enemy.p = room.center
				enemy.max_hp = [18,24,28,36][i]
				enemy.hp = enemy.max_hp

func update(delta: float) -> void:
	if active_room.is_empty():
		for room: Dictionary in rooms:
			if world.player.position.distance_to(room.door) < 30:
				world.notify("E / ENTER " + room.id.to_upper() + " CHAMBER",0.1)
				if Input.is_action_just_pressed("interact"):
					enter_room(room)
					break
	else:
		if world.locks.get(active_room.id,false):
			attacks.clear()
			if world.player.position.distance_to(active_room.spawn) < 32:
				world.notify("E / RETURN TO THE ASCENT",0.1)
				if Input.is_action_just_pressed("interact"):
					leave_room()
		for i in range(attacks.size()-1,-1,-1):
			var attack: Dictionary = attacks[i]
			attack.time -= delta
			if attack.time <= 0 and attack.time > -attack.duration:
				if attack.rect.intersects(Rect2(world.player.position-Vector2(4,7),Vector2(8,14))):
					var deaths: int = world.deaths
					world.player.hurt(attack.rect.get_center())
					if deaths != world.deaths:
						return
			if attack.time <= -attack.duration:
				attacks.remove_at(i)
	queue_redraw()

func enter_room(room: Dictionary) -> void:
	active_room = room
	world.player.spawn_point = room.door
	teleport(room.spawn)
	world.player.health = world.player.max_health
	world.player.invincible = 1.0
	world.hostile.clear()
	world.bullets.clear()

func leave_room() -> void:
	if active_room.is_empty() or not world.locks.get(active_room.id,false):
		return
	teleport(active_room.door)
	active_room = {}

func teleport(p: Vector2) -> void:
	PlayerMovement._reset(world.player.state,p)
	world.player.position = p
	world.player.previous_position = p
	world.player.ammo = world.player.max_ammo
	world.camera.position = Vector2(960,active_room.floor-140) if p.x > 640 else Vector2(320,p.y-48)

func reset() -> void:
	active_room = {}
	attacks.clear()

func warning(rect: Rect2,delay: float = 0.8,duration: float = 0.3) -> void:
	attacks.append({"rect":rect,"time":delay,"duration":duration})

func tick_boss(e: Dictionary,delta: float) -> void:
	if active_room.is_empty() or active_room.id != e.id:
		return
	e.engaged = true
	e.t += delta
	e.cooldown -= delta
	var enraged: bool = e.hp <= e.max_hp/2
	e.p = e.home + Vector2(sin(e.t*1.4)*100,sin(e.t*2.1)*24)
	world.boss_name = {"warden":"WARDEN / JUMP THE SWEEP","sentinel":"SENTINEL / BAIT THE LANCES","reservoir":"ROOTHEART / FIND THE SAFE LANE","crown":"CROWN / CROSS THE STORM"}.get(e.id,"GUARDIAN")
	world.boss_hp = e.hp
	world.boss_max = e.max_hp
	if e.cooldown < 0.5:
		e["target"] = e.get("target",world.player.position)
	if e.cooldown <= 0:
		var floor_y: float = active_room.floor
		var target: Vector2 = e.get("target",world.player.position)
		var direction: Vector2 = (target-e.p).normalized()
		match e.id:
			"warden":
				# Fan, sweep, then a marked slam with two separated waves.
				if e.volley % 3 == 0:
					for n in range(5 if enraged else 3):
						world.spawn_hostile(e.p,direction.rotated((n-(2 if enraged else 1))*0.23),125)
				elif e.volley % 3 == 1:
					warning(Rect2(720,floor_y-13,480,13),0.85,0.35)
				else:
					warning(Rect2(target.x-38,floor_y-34,76,34),0.72,0.32)
					warning(Rect2(720,floor_y-13,200,13),1.05,0.24)
					warning(Rect2(1000,floor_y-13,200,13),1.25,0.24)
			"sentinel":
				# Lances, a parryable ricochet bolt, then a high/low beam.
				if e.volley % 3 == 0:
					warning(Rect2(target.x-15,floor_y-270,30,270),0.75,0.4)
					warning(Rect2(720,target.y-8,480,16),0.95,0.25)
				elif e.volley % 3 == 1:
					world.spawn_hostile(e.p,direction,190)
					world.spawn_hostile(e.p,Vector2(-direction.x,direction.y),150)
				else:
					var beam_y := floor_y-70 if e.volley % 2 == 0 else floor_y-150
					warning(Rect2(720,beam_y,480,18),0.9,0.32)
				if enraged and e.volley % 3 == 0:
					for n in range(8):
						world.spawn_hostile(e.p,Vector2.RIGHT.rotated(n*TAU/8+e.volley*0.3),105)
			"reservoir":
				# Root columns retain an adjacent safe lane; seeds create delayed zones.
				var safe: int = e.volley % 5
				for lane in range(5):
					if lane != safe:
						warning(Rect2(720+lane*96,floor_y-92,76,92),1.05 if not enraged else 0.8,0.55)
				if e.volley % 2 == 1:
					warning(Rect2(target.x-22,floor_y-44,44,44),0.72,0.3)
					warning(Rect2(720,floor_y-14,150,14),1.12,0.24)
				for n in range(3):
					world.spawn_hostile(e.p,direction.rotated((n-1)*0.3),110)
			"crown":
				# Ring, dash lane and two-height sweep; each leaves a recovery gap.
				if e.volley % 3 == 0:
					for n in range(12):
						if n != e.volley % 12:
							world.spawn_hostile(e.p,Vector2.RIGHT.rotated(n*TAU/12+e.volley*0.27),120 if enraged else 95)
				elif e.volley % 3 == 1:
					warning(Rect2(target.x-22,floor_y-270,44,270),0.75,0.35)
					world.spawn_hostile(e.p,direction,155)
				else:
					warning(Rect2(720,floor_y-12,480,12),0.9,0.3)
					warning(Rect2(720,floor_y-120,480,16),1.38,0.28)
		e.volley += 1
		e.erase("target")
		e.cooldown = 1.35 if enraged else 1.8
	if world.player.position.distance_to(e.p) < 23:
		world.player.hurt(e.p)

func _draw() -> void:
	for room: Dictionary in rooms:
		var color := Color("91d4b6") if world.locks.get(room.id,false) else Color("e2a078")
		for p: Vector2 in [room.door,room.spawn]:
			draw_rect(Rect2(p-Vector2(11,25),Vector2(22,34)),Color("182a3d"))
			draw_rect(Rect2(p-Vector2(11,25),Vector2(22,34)),color,false,2)
			draw_string(ThemeDB.fallback_font,p+Vector2(-4,-10),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
		if not active_room.is_empty() and active_room.id == room.id:
			draw_rect(Rect2(720,room.floor-272,480,272),Color("142536"),false,2)
	for attack: Dictionary in attacks:
		var live: bool = attack.time <= 0
		var color := Color(1,0.35,0.25,0.75) if live else Color(1,0.7,0.3,0.18)
		draw_rect(attack.rect,color)
		draw_rect(attack.rect,Color("ffcd8b"),false,1 if not live else 3)
	for e: Dictionary in world.enemies:
		if e.kind == "boss" and e.hp > 0 and e.has("target"):
			draw_line(e.p,e.target,Color(1,0.7,0.3,0.5),1)
