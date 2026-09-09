extends Node2D

var world: Node2D
var rooms: Array[Dictionary] = []
var active_room: Dictionary = {}
var attacks: Array[Dictionary] = []

func build() -> void:
	for enemy: Dictionary in world.enemies:
		if enemy.kind != "boss":
			continue
		var id: int = enemy.room
		var o := CampaignLayout.origin(id)
		var floor_y := o.y + (400 if id==23 else 352)
		var center := Vector2(o.x+352,floor_y-80)
		if id==11:
			floor_y = o.y+176
			center = Vector2(o.x+464,floor_y-64)
			world.campaign.shelf(Vector2(o.x+464,floor_y),192)
			# Upper archive alcove is reached from the boot gallery above.
		var bounds := Rect2(Vector2(o.x+208,floor_y-144),Vector2(352,144)) if id!=11 else Rect2(o+Vector2(352,32),Vector2(256,144))
		var room := {"id":enemy.id,"room":id,"bounds":bounds,"center":center,"floor":floor_y,"door":Vector2(o.x+112,floor_y-8),"spawn":Vector2(o.x+112,floor_y-8)}
		if id==11:
			room.door=o+Vector2(128,24)
		rooms.append(room)
		enemy.home = center
		enemy.p = center
		# Low islands make floor sweeps escapable without consuming ammo.
		if id != 11:
			world.campaign.shelf(Vector2(o.x+240,floor_y-32),80)
			world.campaign.shelf(Vector2(o.x+464,floor_y-32),80)
		world.locks["arena_"+enemy.id] = true
		if id!=11:
			for rect: Rect2 in [Rect2(o,Vector2(16,480)),Rect2(o+Vector2(624,0),Vector2(16,480)),Rect2(o,Vector2(640,16)),Rect2(o+Vector2(0,464),Vector2(640,16))]:
				world.gates.append({"id":"arena_"+enemy.id,"rect":rect,"kind":"seal","lock":"arena_"+enemy.id,"breached":false})

func update(delta: float) -> void:
	if not active_room.is_empty() and active_room.id == "warden" and not active_room.bounds.grow(48).has_point(world.player.position):
		for enemy: Dictionary in world.enemies:
			if enemy.id == "warden" and not world.locks.get("warden",false):
				enemy.hp = enemy.max_hp
				enemy.p = enemy.home
				enemy.cooldown = 1.5
		world.hostile.clear()
		reset()
	if active_room.is_empty():
		for room: Dictionary in rooms:
			if not world.locks.get(room.id,false) and room.bounds.has_point(world.player.position):
				active_room = room
				world.locks["arena_"+room.id] = false
				# Select a real safe exterior anchor; never move the player on entry.
				world.player.spawn_point = room.door
				world.player.invincible = maxf(world.player.invincible,0.75)
				break
	elif world.locks.get(active_room.id,false):
		world.locks["arena_"+active_room.id] = true
		attacks.clear()
		active_room = {}
	for i in range(attacks.size()-1,-1,-1):
		var attack: Dictionary = attacks[i]
		attack.time -= delta
		if attack.time <= 0 and attack.time > -attack.duration and attack.rect.has_point(world.player.position):
			var deaths: int = world.deaths
			world.player.hurt(attack.rect.get_center())
			if world.deaths != deaths:
				return
		if attack.time <= -attack.duration:
			attacks.remove_at(i)
	queue_redraw()

func reset() -> void:
	for room: Dictionary in rooms:
		world.locks["arena_"+room.id] = true
	active_room = {}
	attacks.clear()

func warning(rect: Rect2,delay: float = 0.8,duration: float = 0.3) -> void:
	if not active_room.is_empty():
		var room_bounds := Rect2(CampaignLayout.origin(active_room.room)+Vector2(16,16),Vector2(608,448))
		rect = rect.intersection(room_bounds)
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
		var left: float = active_room.center.x-240
		var target: Vector2 = e.get("target",world.player.position)
		var direction: Vector2 = (target-e.p).normalized()
		match e.id:
			"warden":
				# Fan, sweep, then a marked slam with two separated waves.
				if e.volley % 3 == 0:
					for n in range(5 if enraged else 3):
						world.spawn_hostile(e.p,direction.rotated((n-(2 if enraged else 1))*0.23),125)
				elif e.volley % 3 == 1:
					warning(Rect2(left,floor_y-13,480,13),0.85,0.35)
				else:
					warning(Rect2(target.x-38,floor_y-34,76,34),0.72,0.32)
					warning(Rect2(left,floor_y-13,200,13),1.05,0.24)
					warning(Rect2(left+280,floor_y-13,200,13),1.25,0.24)
			"sentinel":
				# Lances, a parryable ricochet bolt, then a high/low beam.
				if e.volley % 3 == 0:
					warning(Rect2(target.x-15,floor_y-270,30,270),0.75,0.4)
					warning(Rect2(left,target.y-8,480,16),0.95,0.25)
				elif e.volley % 3 == 1:
					world.spawn_hostile(e.p,direction,190)
					world.spawn_hostile(e.p,Vector2(-direction.x,direction.y),150)
				else:
					var beam_y := floor_y-70 if e.volley % 2 == 0 else floor_y-150
					warning(Rect2(left,beam_y,480,18),0.9,0.32)
				if enraged and e.volley % 3 == 0:
					for n in range(8):
						world.spawn_hostile(e.p,Vector2.RIGHT.rotated(n*TAU/8+e.volley*0.3),105)
			"reservoir":
				# Root columns retain an adjacent safe lane; seeds create delayed zones.
				var safe: int = clampi(floori((target.x-left)/96),0,4)
				for lane in range(5):
					if lane != safe:
						warning(Rect2(left+lane*96,floor_y-92,76,92),1.05 if not enraged else 0.8,0.55)
				if e.volley % 2 == 1:
					warning(Rect2(target.x-22,floor_y-44,44,44),0.72,0.3)
					warning(Rect2(left,floor_y-14,150,14),1.12,0.24)
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
					warning(Rect2(left,floor_y-12,480,12),0.9,0.3)
					warning(Rect2(left,floor_y-120,480,16),1.38,0.28)
		e.volley += 1
		e.erase("target")
		e.cooldown = 2.1 if enraged else 2.5
	if world.player.position.distance_to(e.p) < 23:
		world.player.hurt(e.p)

func _draw() -> void:
	for attack: Dictionary in attacks:
		var live: bool = attack.time <= 0
		var color := Color(1,0.35,0.25,0.65) if live else Color(1,0.7,0.3,0.14)
		draw_rect(attack.rect,color)
		draw_rect(attack.rect,Color("ffcd8b"),false,1 if not live else 3)
	for e: Dictionary in world.enemies:
		if e.kind == "boss" and e.hp > 0 and e.has("target"):
			draw_line(e.p,e.target,Color(1,0.7,0.3,0.5),1)
