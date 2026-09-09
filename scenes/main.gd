extends Node2D

const Scenery = preload("res://scenes/scenery.gd")
const HUD = preload("res://scenes/hud.gd")
const Audio = preload("res://scenes/sound.gd")
const START := Vector2(120, 472)
const SUMMIT := -4048.0
const Level = preload("res://src/world/expedition_level.gd")
const GateCollision = preload("res://src/collision/gate_collision.gd")
var legacy_campaign := false
var campaign: CampaignLayout
var suit_fragments := 0
var tiles: Dictionary = {}
var platforms: Array[Rect2] = []
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var hostile: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var switches: Array[Dictionary] = []
var kick_plates: Array[Dictionary] = []
var locks: Dictionary = {}
var capacitor: Dictionary = {}
var signs: Array = []
var combat_time := 0.0
var boss_name := ""
var boss_hp := 0
var boss_max := 1
var particles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var checkpoints: Array[Vector2] = []
var checkpoint_index := -1
var elapsed := 0.0
var time := 0.0
var shake := 0.0
var started := false
var paused := false
var map_open := false
var finished := false
var muted := false
var deaths := 0
var kills := 0
var message := ""
var message_time := 0.0
var camera: Camera2D
var scenery: Node2D
var hud: Node2D
var audio: Node
var arenas: Node2D
var rooms: Node2D
var rng := RandomNumberGenerator.new()
@onready var player: Player = $Player
@export_category("Level Authoring")
@export var layout: LevelLayout

func _ready() -> void:
	if layout and not layout.platforms.is_empty():
		legacy_campaign = true
	rng.seed = 8021
	_setup_input()
	_build_level()
	player.solid_tiles = tiles
	player.spawn_point = START if legacy_campaign else CampaignLayout.START
	player.position = player.spawn_point
	player.state.position = player.position
	player.z_index = 5
	scenery = preload("res://scenes/legacy_scenery.gd").new() if legacy_campaign else Scenery.new()
	scenery.world = self
	scenery.z_index = -10
	add_child(scenery)
	camera = Camera2D.new()
	camera.position = Vector2(320, 324) if legacy_campaign else Vector2(320,1813)
	add_child(camera)
	arenas = preload("res://scenes/legacy_boss_arenas.gd").new() if legacy_campaign else preload("res://scenes/boss_arenas.gd").new()
	arenas.world = self
	add_child(arenas)
	if not platforms.is_empty() and not enemies.filter(func(e: Dictionary) -> bool: return e.id == "warden").is_empty():
		arenas.build()
	rooms = preload("res://scenes/legacy_world_rooms.gd").new() if legacy_campaign else preload("res://scenes/world_rooms.gd").new()
	rooms.world = self
	add_child(rooms)
	if not legacy_campaign or ((not layout or layout.platforms.is_empty()) and platforms.size() >= 36):
		rooms.build()
	var art := preload("res://scenes/world_art.gd").new()
	art.world = self
	art.z_index = 2
	add_child(art)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	hud.world = self
	layer.add_child(hud)
	audio = Audio.new()
	add_child(audio)

func _setup_input() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var interact := InputEventKey.new()
		interact.physical_keycode = KEY_E
		InputMap.action_add_event("interact",interact)
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "look_up": [KEY_W, KEY_UP], "look_down": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE, KEY_Z], "dash": [KEY_SHIFT, KEY_X], "fire_key": [KEY_J, KEY_C], "pause_game": [KEY_ESCAPE, KEY_P], "mute": [KEY_M]}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", click)
	if not InputMap.has_action("slash"):
		InputMap.add_action("slash")
		var slash_key := InputEventKey.new()
		slash_key.physical_keycode = KEY_K
		InputMap.action_add_event("slash",slash_key)
		var slash_click := InputEventMouseButton.new()
		slash_click.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("slash",slash_click)
	if not InputMap.has_action("map"):
		InputMap.add_action("map")
		var map_key := InputEventKey.new()
		map_key.physical_keycode = KEY_TAB
		InputMap.action_add_event("map",map_key)

func _unhandled_input(event: InputEvent) -> void:
	if not started and ((event is InputEventMouseButton and event.pressed) or event.is_action_pressed("jump") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER)):
		started = true
		player.active = true
		notify("WRECK ORCHARD / Find your cutter in the torn bow. TAB opens the map.", 6)
		sound("save")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and started and not finished:
		map_open = not map_open
		paused = map_open
		player.active = not paused
	elif event.is_action_pressed("pause_game") and started and not finished:
		map_open = false
		paused = not paused
		player.active = not paused
	elif event.is_action_pressed("mute"):
		muted = not muted
		audio.set_muted(muted)
	elif finished and event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		get_tree().reload_current_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started and not finished:
		paused = true
		player.active = false

func _build_level() -> void:
	if legacy_campaign:
		Level.build(self)
	else:
		campaign = CampaignLayout.new()
		campaign.build(self)

func add_enemy(kind: String,p: Vector2,id: String,hp: int,left: float = 0,right: float = 0) -> void:
	enemies.append({"p":p,"home":p,"kind":kind,"id":id,"uid":"%s_%d" % [kind,enemies.size()],"hp":hp,"max_hp":hp,"left":left,"right":right,"dir":1.0,"t":0.0,"hit":0.0,"stun":0.0,"cooldown":1.5,"volley":0,"engaged":false})

func _fill(x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			tiles[Vector2i(x,y)] = true

func _physics_process(delta: float) -> void:
	time += delta
	if started and not paused and not finished:
		elapsed += delta
		combat_time += delta
		message_time = maxf(0, message_time - delta)
		_update_pickups()
		arenas.update(delta)
		rooms.update(delta)
		_update_enemies(delta)
		_update_bullets(delta)
		_update_hostile(delta)
		_update_challenges(delta)
		_update_dangers()
		if not legacy_campaign and player.position.distance_to(CampaignLayout.origin(5)+Vector2(512,276))<60:
			notify("E / TRANSMIT THE RESCUE SIGNAL",0.2)
		if locks.get("crown",false) and player.position.distance_to(Vector2(256,SUMMIT-10) if legacy_campaign else CampaignLayout.origin(5)+Vector2(512,276)) < 42 and Input.is_action_just_pressed("interact"):
			finished = true
			player.active = false
			sound("save")
			burst(player.position, Color("ffe3a1"), 45)
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life -= delta
		p.p += p.v * delta
		p.v.y += 80 * delta
		if p.life <= 0:
			particles.remove_at(i)
	var target := Vector2(320, clampf(player.position.y - 48, SUMMIT, 324))
	if not arenas.active_room.is_empty():
		target = Vector2(960,arenas.active_room.floor-140)
	elif rooms and not rooms.active_room.is_empty():
		target = rooms.active_room.bounds.get_center() + Vector2(0,-70)
	if not started:
		target = Vector2(320,324)
	if not legacy_campaign:
		target = rooms.camera_target()
	camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 10))
	# Keep the complete sprite visible even during rapid falls and long dashes.
	if not legacy_campaign:
		camera.position.x = clampf(camera.position.x,player.position.x-260,player.position.x+260)
		camera.position.y = clampf(camera.position.y,player.position.y-140,player.position.y+140)
	shake = maxf(shake - delta * 15, 0)
	camera.offset = Vector2(rng.randf_range(-shake,shake), rng.randf_range(-shake,shake))
	scenery.queue_redraw()
	for child in get_children():
		if child.get_script() == preload("res://scenes/world_art.gd"):
			child.queue_redraw()
	hud.queue_redraw()
	queue_redraw()

func _update_pickups() -> void:
	for pickup: Dictionary in pickups:
		if pickup.taken or player.position.distance_to(pickup.p) > 21:
			continue
		if not pickup.lock.is_empty() and not locks.get(pickup.lock,false):
			continue
		pickup.taken = true
		match pickup.kind:
			"gun":
				player.gun_unlocked = true
				player.max_ammo = 1
				notify("PULSE CUTTER / Jump, then S + J near the apex. Land to recharge.",9)
			"ammo2":
				player.max_ammo = maxi(player.max_ammo,2)
				notify("TWIN MAGAZINE / Two recoil pulses per jump. Reach the Heartwood nest.",7)
			"boots":
				player.wall_unlocked = true
				notify("KICK BOOTS / SPACE at a wall. One kick per landing. No wall reloads.",8)
			"dash":
				player.dash_unlocked = true
				player.state.dash_available = true
				notify("SAIL THRUSTER / LEFT or RIGHT + SHIFT. A long horizontal dash.",8)
			"ammo3":
				player.max_ammo = 3
				notify("TRIPLE MAGAZINE / Three airborne shots can overload a relay core.",8)
			"fragment":
				suit_fragments += 1
				player.max_health = 3 + int(suit_fragments >= 2)
				notify("SUIT FRAGMENT %d/2 / %s" % [suit_fragments,"Integrity increased." if suit_fragments >= 2 else "Find the matching fragment."],6)
			"core":
				locks.core = true
				notify("HEARTWOOD RESTORED / Repair the root pump to wake the upper winds.",6)
		player.health = player.max_health
		player.ammo = player.max_ammo
		burst(pickup.p,Color("80f2d2"),30)
		sound("save")
	for i in range(checkpoints.size()):
		if (i != checkpoint_index or Input.is_action_just_pressed("interact")) and player.position.distance_to(checkpoints[i]) < 25 and player.state.on_floor:
			checkpoint_index = i
			if not legacy_campaign:
				rooms.visited_anchors[i] = true
			player.spawn_point = checkpoints[i]
			player.health = player.max_health
			notify("SIGNAL ANCHOR / Suit restored. R retries this section.",4)
			burst(checkpoints[i],Color("80f2d2"),20)
			sound("save")

func _update_enemies(delta: float) -> void:
	boss_name = ""
	for e: Dictionary in enemies:
		if e.hp <= 0:
			continue
		if not legacy_campaign and (e.get("room",0) != rooms.active_room.get("id",0) or rooms.entry_grace > 0):
			continue
		e.hit = maxf(0,e.hit-delta)
		e.stun = maxf(0,float(e.get("stun",0))-delta)
		if e.stun > 0:
			continue
		if e.kind == "boss" and not arenas.rooms.is_empty():
			arenas.tick_boss(e,delta)
			continue
		if not arenas.active_room.is_empty():
			continue
		if absf(e.home.y-player.position.y) > 260:
			continue
		e.t += delta
		if e.kind == "crawler":
			var hunting := absf(player.position.y-e.p.y) < 36 and absf(player.position.x-e.p.x) < 145
			if hunting:
				e.dir = signf(player.position.x-e.p.x)
			e.p.x += e.dir*(78 if hunting else 31)*delta
			if e.p.x < e.left or e.p.x > e.right:
				e.dir *= -1
				e.p.x = clampf(e.p.x,e.left,e.right)
		elif e.kind == "hunter":
			e.cooldown -= delta
			if e.cooldown <= 0:
				e.charge = (player.position-e.p).normalized()*185
				e.cooldown = 1.8
			if e.cooldown > 1.28:
				var next: Vector2 = e.p + e.charge*delta
				if not tiles.has(Vector2i(floori(next.x/16),floori(next.y/16))):
					e.p = next
			else:
				e.p = e.p.move_toward(e.home,45*delta)
		else:
			# Drifters never chase. A shot only aims when it is spawned.
			e.p = e.home + Vector2(sin(e.t*TAU/3)*24, sin(e.t*2)*5)
			var in_range: bool = player.position.distance_to(e.home) < (200 if e.kind == "boss" else 235)
			if in_range:
				e.engaged = true
				e.cooldown -= delta
				if e.kind == "boss":
					boss_name = {"warden":"THE HOLLOW WARDEN","sentinel":"THE GLASS SENTINEL","reservoir":"ROOTHEART","crown":"THE CROWN"}.get(e.id,"GUARDIAN")
					boss_hp = e.hp
					boss_max = e.max_hp
				if e.cooldown <= 0:
					var direction: Vector2 = (player.position-e.p).normalized()
					var count := 1 if e.kind == "sentry" else (3 if e.kind == "drifter" else 5)
					for shot in range(count):
						spawn_hostile(e.p,direction.rotated(deg_to_rad((shot-(count-1)/2.0)*20)),210 if e.kind == "sentry" else (105 if e.kind == "drifter" else 66))
					e.volley += 1
					if e.kind == "boss" and e.volley%3 == 0:
						for shot in range(10):
							spawn_hostile(e.p,Vector2.RIGHT.rotated(shot*TAU/10+e.volley*0.15),54)
					e.cooldown = 1.6 if e.kind == "drifter" else (1.75 if e.kind == "sentry" else (1.45 if e.hp > e.max_hp/2 else 1.15))
		if player.position.distance_to(e.p) < (23 if e.kind == "boss" else 14):
			player.hurt(e.p)

func spawn_hostile(p: Vector2,dir: Vector2,speed: float) -> void:
	hostile.append({"p":p+dir*14,"v":dir*speed,"life":7.0,"damage":1})

func resolve_player_gates(body: Player, from: Vector2, dashed: bool) -> void:
	var collider := body.config.collider_size
	for gate: Dictionary in gates:
		if gate.get("breached",false) or (gate.kind == "seal" and locks.get(gate.lock,false)):
			continue
		var touches := GateCollision.swept_touches(from,body.position,gate.rect,collider)
		if not touches:
			continue
		if gate.kind == "phase" and body.dash_unlocked and dashed:
			gate.breached = true
			burst(body.position,Color("83cbea"),18)
			notify("MEMBRANE BREACHED / Passage remains open.",3)
			sound("save")
			continue
		var resolved := GateCollision.nearest_clear_position(body.position,gate.rect,collider,body.state.velocity)
		body.position = resolved
		body.state.position = resolved
		if absf(body.state.velocity.x) > absf(body.state.velocity.y):
			body.state.velocity.x = 0
		else:
			body.state.velocity.y = 0

func _within_slash_arc(origin: Vector2, direction: Vector2, target: Vector2, radius: float, degrees: float) -> bool:
	var offset := target-origin
	if offset.length() > radius:
		return false
	return offset.length() < 0.1 or direction.dot(offset.normalized()) >= cos(deg_to_rad(degrees*0.5))

func resolve_slash(body: Player) -> void:
	for i in range(hostile.size()-1,-1,-1):
		var hostile_shot: Dictionary = hostile[i]
		if not body.parry_is_active() or not _within_slash_arc(body.position,body.slash_direction,hostile_shot.p,42,120):
			continue
		hostile.remove_at(i)
		fire(hostile_shot.p,body.slash_direction,true,body.flight_id,body.combat_config.parry_damage)
		body.ammo = body.max_ammo
		body.shot_timer = 0
		burst(hostile_shot.p,Color("baffde"),12)
	for enemy: Dictionary in enemies:
		if enemy.hp <= 0 or body.slash_hits.has(enemy.get("uid",enemy.id)):
			continue
		if enemy.kind == "boss" and (arenas.active_room.is_empty() or arenas.active_room.id != enemy.id):
			continue
		if _within_slash_arc(body.position,body.slash_direction,enemy.p,body.combat_config.slash_range,body.combat_config.slash_arc_degrees):
			body.slash_hits[enemy.get("uid",enemy.id)] = true
			damage_enemy(enemy,body.combat_config.slash_damage,true)
			if not body.slash_refund:
				body.ammo = mini(body.max_ammo,body.ammo+1)
				body.slash_refund = true
			if not body.state.on_floor and body.slash_direction.y > 0.45:
				body.state.velocity.y = minf(body.state.velocity.y,-5.8)

func _update_hostile(delta: float) -> void:
	for i in range(hostile.size()-1,-1,-1):
		var b: Dictionary = hostile[i]
		b.p += b.v*delta
		b.life -= delta
		if tiles.has(Vector2i(floori(b.p.x/16),floori(b.p.y/16))):
			b.life = 0
		if player.parry_is_active() and _within_slash_arc(player.position,player.slash_direction,b.p,42,120):
			b.life = 0
			fire(b.p,player.slash_direction,true,player.flight_id,player.combat_config.parry_damage)
			player.ammo = player.max_ammo
			player.shot_timer = 0
			burst(b.p,Color("baffde"),12)
		var hit: bool = b.p.distance_to(player.position) < 8
		if b.life <= 0 or hit:
			hostile.remove_at(i)
		if hit:
			var recoveries := deaths
			player.hurt(b.p)
			if deaths != recoveries:
				return # Recovery clears all remaining bullets.


func fire(p: Vector2,direction: Vector2,airborne: bool = false,flight: int = -1,damage: int = 1) -> void:
	bullets.append({"p":p,"v":direction*520,"life":0.8,"airborne":airborne,"flight":flight,"damage":damage})
	burst(p,Color("ffe6a3"),4)
	shake = maxf(shake,0.8)

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size()-1,-1,-1):
		var b: Dictionary = bullets[i]
		b.life -= delta
		for step in range(3):
			b.p += b.v*delta/3.0
			if tiles.has(Vector2i(floori(b.p.x/16),floori(b.p.y/16))):
				b.life = 0
				burst(b.p,Color("efbd78"),5)
				break
			# Friendly pulses cancel hostile bullets, including boss volleys.
			for j in range(hostile.size()-1,-1,-1):
				if b.p.distance_to(hostile[j].p) < 8:
					burst(hostile[j].p,Color("f3c6a1"),6)
					hostile.remove_at(j)
					b.life = 0
					break
			if b.life <= 0:
				break
			for relay: Dictionary in switches:
				if b.p.distance_to(relay.p) < 10:
					relay.lit = true
					relay.timer = 5.0
					b.life = 0
					burst(relay.p,Color("80f2d2"),8)
			if not capacitor.is_empty() and not locks.get("airlock",false) and b.p.distance_to(capacitor.p) < 13:
				if b.airborne and not player.state.on_floor and b.flight == player.flight_id:
					if capacitor.flight != b.flight:
						capacitor.hits = 0
						capacitor.flight = b.flight
					capacitor.hits += 1
					if capacitor.hits >= 3:
						locks.airlock = true
						notify("CORE OVERLOADED / The upper canopy is open.",5)
						sound("save")
				b.life = 0
			for e: Dictionary in enemies:
				if e.kind == "boss" and not arenas.rooms.is_empty() and (arenas.active_room.is_empty() or arenas.active_room.id != e.id):
					continue
				if b.life > 0 and e.hp > 0 and b.p.distance_to(e.p) < (22 if e.kind == "boss" else 12):
					damage_enemy(e,int(b.get("damage",1)),false)
					b.life = 0
					break
			if b.life <= 0:
				break
		if b.life <= 0:
			bullets.remove_at(i)

func _update_challenges(delta: float) -> void:
	if not legacy_campaign:
		return
	var all_lit := true
	for relay: Dictionary in switches:
		relay.timer = maxf(0,relay.timer-delta)
		if relay.timer <= 0 and not locks.get("boots",false):
			relay.lit = false
		all_lit = all_lit and relay.lit
	if all_lit and not locks.get("boots",false):
		locks.boots = true
		notify("RELAY CIRCUIT LINKED / Kick boots released in the alcove.",6)
		sound("save")
	if player.state.on_floor and not locks.get("airlock",false):
		capacitor.hits = 0
		capacitor.flight = -1

func damage_enemy(enemy: Dictionary, amount: int, stagger: bool) -> void:
	if enemy.hp <= 0:
		return
	enemy.hp -= amount
	enemy.hit = 0.15
	if stagger and enemy.kind != "boss":
		enemy.stun = float(player.combat_config.normal_stagger_frames) / 60.0
	burst(enemy.p,Color("e9a878"),8)
	if enemy.hp <= 0:
		kills += 1
		burst(enemy.p,Color("d294ba"),24)
		sound("kill")
		if enemy.kind == "boss" and not enemy.id.is_empty():
			locks[enemy.id] = true
			hostile.clear()
			player.health = player.max_health
			notify("GUARDIAN QUIETED / The passage beyond is open.",6)

func wall_kicked(p: Vector2) -> void:
	for plate: Dictionary in kick_plates:
		if p.distance_to(plate.p) < 40:
			locks[plate.lock] = true
			notify("KICK LATCH RELEASED / Upper passage open.",4)
			sound("save")

func _update_dangers() -> void:
	# Gate collision is resolved immediately in Player after movement.
	var body := Rect2(player.position-Vector2(4,7),Vector2(8,14))
	for hazard: Dictionary in hazards:
		var dangerous: bool = hazard.kind == "spikes" or fposmod(combat_time+hazard.phase,3.8)>2.8
		if dangerous and body.intersects(hazard.rect):
			player.hurt(hazard.rect.get_center())

func burst(p: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"p": p, "v": Vector2(rng.randf_range(-45,45), rng.randf_range(-55,15)), "color": color, "life": rng.randf_range(0.15,0.6)})

func notify(text: String, duration: float) -> void:
	message = text
	message_time = duration

func on_respawn() -> void:
	deaths += 1
	arenas.reset()
	bullets.clear()
	hostile.clear()
	# Unfinished encounters reset completely; completed vaults stay open.
	for e: Dictionary in enemies:
		if e.kind != "boss" and e.hp>0:
			e.hp = e.max_hp
			e.p = e.home
			e.stun = 0.0
			e.cooldown = 1.5
		if e.kind == "boss" and not locks.get(e.id,false):
			e.hp = e.max_hp
			e.cooldown = 1.5
			e.volley = 0
			e.t = 0.0
			e.p = e.home
			e.engaged = false
			e.erase("target")
	camera.position = Vector2(320,clampf(player.position.y-48,SUMMIT,324)) if legacy_campaign else rooms.camera_target()
	if not legacy_campaign:
		rooms.update_membership()
	notify("SUIT RECONSTRUCTED / Equipment retained. Unfinished guardians restored.",4)

func sound(kind: String) -> void:
	if audio and not muted:
		audio.play_effect(kind)

func zone() -> String:
	if not legacy_campaign and rooms and not rooms.active_room.is_empty():
		return rooms.active_room.name
	if player.position.y > 180:
		return "01 / THE SALVAGE TRAIL"
	if player.position.y > -600:
		return "02 / WARDEN'S HOLLOW"
	if player.position.y > -1300:
		return "03 / THE RELAY MINES"
	if player.position.y > -2000:
		return "04 / GLASS SANCTUARY"
	if player.position.y > -2900:
		return "05 / THE ROOTHEART"
	if player.position.y > -3700:
		return "06 / STORM CANOPY"
	return "07 / THE CROWN"

func _draw() -> void:
	for checkpoint in checkpoints:
		var lit: bool = checkpoints.find(checkpoint) <= checkpoint_index if legacy_campaign else rooms.visited_anchors.has(checkpoints.find(checkpoint))
		draw_rect(Rect2(checkpoint + Vector2(-6,-18),Vector2(12,26)),Color("354e59"))
		draw_rect(Rect2(checkpoint + Vector2(-3,-16),Vector2(6,18)),Color("78eac5") if lit else Color("587b80"))
		draw_circle(checkpoint + Vector2(0,-20),3,Color("c5ffe3") if lit else Color("9caeaa"))
	for e: Dictionary in enemies:
		if e.hp <= 0:
			continue
		var p: Vector2 = e.p.round()
		var color := Color("eaa489") if e.hit > 0 else Color("a86d8e")
		if e.kind == "crawler":
			for n in range(3):
				var x := -7 + n * 6
				draw_line(p+Vector2(x,2),p+Vector2(x+sin(e.t*12+n)*3,7),Color("57495f"),2)
			draw_rect(Rect2(p+Vector2(-9,-4),Vector2(18,8)),Color("54445f"))
			draw_rect(Rect2(p+Vector2(-7,-7),Vector2(14,8)),color)
			draw_rect(Rect2(p+Vector2(-4,-8),Vector2(8,3)),Color("c792a5"))
			draw_rect(Rect2(p+Vector2(e.dir*5-1,-3),Vector2(3,2)),Color("ffe8a3"))
		elif e.kind == "boss":
			var radius := 20.0
			var boss_color: Color = {"warden":Color("d3a46c"),"sentinel":Color("8edeea"),"reservoir":Color("a1ce87"),"crown":Color("d6a0e8")}.get(e.id,color)
			if e.hit <= 0:
				color = boss_color
			draw_circle(p,25,Color("263848"))
			var limbs: int = {"warden":4,"sentinel":3,"reservoir":7,"crown":12}.get(e.id,8)
			for n in range(limbs):
				var d := Vector2.RIGHT.rotated(n*TAU/limbs+e.t*0.25)
				draw_line(p+d*10,p+d*(radius+sin(e.t*3+n)*5),boss_color,5 if e.id == "warden" else 3)
			if e.id == "sentinel":
				draw_arc(p,30,e.t,e.t+PI,3,boss_color,2)
			elif e.id == "crown":
				draw_arc(p,31,0,TAU,12,boss_color,1)
			draw_circle(p,13,color)
			draw_circle(p,7,Color("ecd39a"))
			draw_circle(p,3,Color("473953"))
		else:
			var wing := sin(e.t * 20) * 6
			draw_colored_polygon(PackedVector2Array([p+Vector2(-3,0),p+Vector2(-17,-8+wing),p+Vector2(-12,5),p+Vector2(0,5)]),color)
			draw_colored_polygon(PackedVector2Array([p+Vector2(3,0),p+Vector2(17,-8+wing),p+Vector2(12,5),p+Vector2(0,5)]),color)
			draw_rect(Rect2(p+Vector2(-4,-5),Vector2(8,11)),Color("474960"))
			draw_rect(Rect2(p+Vector2(-3,-3),Vector2(6,2)),Color("ffcc84"))
	for e: Dictionary in enemies:
		if e.hp > 0 and e.kind != "crawler" and e.cooldown < 0.42:
			draw_arc(e.p,19+(0.42-e.cooldown)*12,0,TAU,16,Color("efab8b"),1)
	for b: Dictionary in hostile:
		draw_circle(b.p,5,Color("613d51"))
		draw_circle(b.p,3,Color("f49379"))
		draw_rect(Rect2(b.p-Vector2(1,2),Vector2(2,2)),Color("ffedc4"))
	for b: Dictionary in bullets:
		draw_line(b.p - b.v.normalized() * 9, b.p, Color("fff0b1"),2)
	for p: Dictionary in particles:
		var color: Color = p.color
		color.a = minf(1,p.life * 4)
		draw_rect(Rect2(p.p.round(),Vector2(2,2)),color)
	# Transmitter is physically on Beacon's upper branch.
	var beacon := Vector2(256,SUMMIT) if legacy_campaign else CampaignLayout.origin(5)+Vector2(512,288)
	draw_rect(Rect2(beacon+Vector2(-3,-46),Vector2(6,46)),Color("afc5bf"))
	draw_rect(Rect2(beacon+Vector2(-12,-6),Vector2(24,6)),Color("637f80"))
	draw_circle(beacon+Vector2(0,-47),4,Color("ffdf98"))
	for i in range(3):
		var radius := fmod(time * 18 + i * 14,42)
		draw_arc(beacon+Vector2(0,-47),radius,PI,TAU,24,Color(0.7,1,0.85,(1-radius/42)*0.45),1)
