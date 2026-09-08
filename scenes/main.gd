extends Node2D

const Scenery = preload("res://scenes/scenery.gd")
const HUD = preload("res://scenes/hud.gd")
const Audio = preload("res://scenes/sound.gd")
const START := Vector2(120, 472)
const SUMMIT := -4048.0
const Level = preload("res://src/world/expedition_level.gd")
var tiles: Dictionary = {}
var platforms: Array[Rect2] = []
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var hostile: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var switches: Array[Dictionary] = []
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
var rng := RandomNumberGenerator.new()
@onready var player: Player = $Player
@export_category("Level Authoring")
@export var layout: LevelLayout

func _ready() -> void:
	rng.seed = 8021
	_setup_input()
	_build_level()
	player.solid_tiles = tiles
	player.spawn_point = START
	player.position = START
	scenery = Scenery.new()
	scenery.world = self
	scenery.z_index = -10
	add_child(scenery)
	camera = Camera2D.new()
	camera.position = Vector2(320, 324)
	add_child(camera)
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

func _unhandled_input(event: InputEvent) -> void:
	if not started and ((event is InputEventMouseButton and event.pressed) or event.is_action_pressed("jump") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER)):
		started = true
		player.active = true
		notify("SALVAGE TRAIL / Follow the ledges to your lost cargo. Three suit integrity points.", 6)
		sound("save")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_game") and started and not finished:
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
	Level.build(self)

func add_enemy(kind: String,p: Vector2,id: String,hp: int,left: float = 0,right: float = 0) -> void:
	enemies.append({"p":p,"home":p,"kind":kind,"id":id,"hp":hp,"max_hp":hp,"left":left,"right":right,"dir":1.0,"t":0.0,"hit":0.0,"cooldown":1.5,"volley":0,"engaged":false})

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
		_update_enemies(delta)
		_update_bullets(delta)
		_update_hostile(delta)
		_update_challenges(delta)
		_update_dangers()
		if locks.get("crown",false) and player.position.distance_to(Vector2(256,SUMMIT-10)) < 42:
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
	if not started:
		target = Vector2(320,324)
	camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 7))
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
				player.max_ammo = 2
				notify("TWIN MAGAZINE / Two recoil pulses per jump. Taller shafts ahead.",7)
			"boots":
				player.wall_unlocked = true
				notify("KICK BOOTS / SPACE at a wall. One kick per landing. No wall reloads.",8)
			"dash":
				player.dash_unlocked = true
				player.state.dash_available = true
				notify("VECTOR THRUSTER / Direction + SHIFT. Dash through blue membranes.",8)
			"ammo3":
				player.max_ammo = 3
				notify("TRIPLE MAGAZINE / Three airborne shots can overload a relay core.",8)
		player.health = Player.MAX_HEALTH
		player.ammo = player.max_ammo
		burst(pickup.p,Color("80f2d2"),30)
		sound("save")
	for i in range(checkpoints.size()):
		if i > checkpoint_index and player.position.distance_to(checkpoints[i]) < 25 and player.state.on_floor:
			checkpoint_index = i
			player.spawn_point = checkpoints[i]
			player.health = Player.MAX_HEALTH
			notify("SIGNAL ANCHOR / Suit restored. R retries this section.",4)
			burst(checkpoints[i],Color("80f2d2"),20)
			sound("save")

func _update_enemies(delta: float) -> void:
	boss_name = ""
	for e: Dictionary in enemies:
		if e.hp <= 0:
			continue
		e.hit = maxf(0,e.hit-delta)
		if absf(e.home.y-player.position.y) > 260:
			continue
		e.t += delta
		if e.kind == "crawler":
			e.p.x += e.dir*29*delta
			if e.p.x < e.left or e.p.x > e.right:
				e.dir *= -1
				e.p.x = clampf(e.p.x,e.left,e.right)
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
					var count := 3 if e.kind == "drifter" else 5
					for shot in range(count):
						spawn_hostile(e.p,direction.rotated(deg_to_rad((shot-(count-1)/2.0)*20)),76 if e.kind == "drifter" else 66)
					e.volley += 1
					if e.kind == "boss" and e.volley%3 == 0:
						for shot in range(10):
							spawn_hostile(e.p,Vector2.RIGHT.rotated(shot*TAU/10+e.volley*0.15),54)
					e.cooldown = 1.65 if e.kind == "drifter" else (1.45 if e.hp > e.max_hp/2 else 1.15)
		if player.position.distance_to(e.p) < (23 if e.kind == "boss" else 14):
			player.hurt(e.p)

func spawn_hostile(p: Vector2,dir: Vector2,speed: float) -> void:
	hostile.append({"p":p+dir*14,"v":dir*speed,"life":7.0})

func _update_hostile(delta: float) -> void:
	for i in range(hostile.size()-1,-1,-1):
		var b: Dictionary = hostile[i]
		b.p += b.v*delta
		b.life -= delta
		if tiles.has(Vector2i(floori(b.p.x/16),floori(b.p.y/16))):
			b.life = 0
		var hit: bool = b.p.distance_to(player.position) < 8
		if b.life <= 0 or hit:
			hostile.remove_at(i)
		if hit:
			var recoveries := deaths
			player.hurt(b.p)
			if deaths != recoveries:
				return # Recovery clears all remaining bullets.


func fire(p: Vector2,direction: Vector2,airborne: bool = false,flight: int = -1) -> void:
	bullets.append({"p":p,"v":direction*520,"life":0.8,"airborne":airborne,"flight":flight})
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
			if not locks.get("airlock",false) and b.p.distance_to(capacitor.p) < 13:
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
				if b.life > 0 and e.hp > 0 and b.p.distance_to(e.p) < (22 if e.kind == "boss" else 12):
					e.hp -= 1
					e.hit = 0.15
					b.life = 0
					burst(e.p,Color("e9a878"),8)
					if e.hp <= 0:
						kills += 1
						burst(e.p,Color("d294ba"),24)
						sound("kill")
						if not e.id.is_empty():
							locks[e.id] = true
							hostile.clear()
							notify("GUARDIAN DEFEATED / Salvage released. Claim your upgrade.",6)
					break
			if b.life <= 0:
				break
		if b.life <= 0:
			bullets.remove_at(i)

func _update_challenges(delta: float) -> void:
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

func gate_open(gate: Dictionary) -> bool:
	if gate.kind == "phase":
		return player.dash_unlocked and int(player.state.timers.get("dash_timer",0)) > 0
	return locks.get(gate.lock,false)

func _update_dangers() -> void:
	var body := Rect2(player.position-Vector2(4,7),Vector2(8,14))
	for gate: Dictionary in gates:
		if not gate_open(gate) and body.intersects(gate.rect):
			player.position = player.previous_position
			player.state.position = player.position
			player.state.velocity.y = maxf(1,player.state.velocity.y)
			break
	body = Rect2(player.position-Vector2(4,7),Vector2(8,14))
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
	bullets.clear()
	hostile.clear()
	# Unfinished encounters reset completely; completed vaults stay open.
	for e: Dictionary in enemies:
		if e.kind == "boss" and not locks.get(e.id,false):
			e.hp = e.max_hp
			e.cooldown = 1.5
			e.volley = 0
			e.t = 0.0
			e.p = e.home
	camera.position = Vector2(320,clampf(player.position.y-48,SUMMIT,324))
	notify("SUIT RECONSTRUCTED / Equipment retained. Unfinished guardians restored.",4)

func sound(kind: String) -> void:
	if audio and not muted:
		audio.play_effect(kind)

func zone() -> String:
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
		var lit := checkpoints.find(checkpoint) <= checkpoint_index
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
			draw_circle(p,25,Color("263848"))
			for n in range(8):
				var d := Vector2.RIGHT.rotated(n*TAU/8+e.t*0.25)
				draw_line(p+d*10,p+d*(radius+sin(e.t*3+n)*3),Color("ab8f9e"),5)
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
	# Rescue transmitter on the final island.
	draw_rect(Rect2(253,SUMMIT-46,6,46),Color("afc5bf"))
	draw_rect(Rect2(244,SUMMIT-6,24,6),Color("637f80"))
	draw_circle(Vector2(256,SUMMIT-47),4,Color("ffdf98"))
	for i in range(3):
		var radius := fmod(time * 18 + i * 14,42)
		draw_arc(Vector2(256,SUMMIT-47),radius,PI,TAU,24,Color(0.7,1,0.85,(1-radius/42)*0.45),1)
