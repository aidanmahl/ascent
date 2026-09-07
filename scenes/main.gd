extends Node2D

const Scenery = preload("res://scenes/scenery.gd")
const HUD = preload("res://scenes/hud.gd")
const Audio = preload("res://scenes/sound.gd")
const START := Vector2(120, 472)
const SUMMIT := -1504.0
var tiles: Dictionary = {}
var platforms: Array[Rect2] = []
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
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
		notify("SURVIVED THE IMPACT.  Find your equipment beside the wreck.", 6)
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
	_fill(0, 39, 30, 34)
	_fill(0, 1, -100, 30)
	_fill(38, 39, -100, 30)
	# Overlapping switchbacks keep the next landing visible. Later rises
	# expand from 48 to 80/96 pixels as suit upgrades become available.
	var route := [Vector2i(13,27), Vector2i(20,24), Vector2i(27,21), Vector2i(23,18), Vector2i(16,15), Vector2i(8,12), Vector2i(4,9), Vector2i(10,6), Vector2i(17,1), Vector2i(24,-4), Vector2i(28,-9), Vector2i(21,-14), Vector2i(13,-19), Vector2i(5,-24), Vector2i(8,-29), Vector2i(16,-34), Vector2i(25,-40), Vector2i(28,-46), Vector2i(20,-52), Vector2i(11,-58), Vector2i(4,-64), Vector2i(11,-70), Vector2i(20,-76), Vector2i(28,-82), Vector2i(21,-88), Vector2i(13,-94)]
	for i in range(route.size()):
		var p: Vector2i = route[i]
		var width := 7 if i < 8 else 6
		_fill(p.x, p.x + width - 1, p.y, p.y + 1)
		platforms.append(Rect2(p.x * 16, p.y * 16, width * 16, 32))
	# Safe rest ledges off the main path, with vertical faces for wall jumps.
	_fill(2, 5, -8, -7)
	_fill(34, 37, -28, -27)
	_fill(2, 5, -48, -47)
	_fill(34, 37, -68, -67)
	checkpoints = [Vector2(288,232), Vector2(368,-232), Vector2(352,-840)]
	pickups = [{"p": Vector2(210,468), "kind": "gun", "taken": false}, {"p": Vector2(192,84), "kind": "jump", "taken": false}, {"p": Vector2(288,-556), "kind": "dash", "taken": false}]
	for i in [3, 6, 10, 13, 17, 20, 23]:
		var rect: Rect2 = platforms[i]
		enemies.append({"p": Vector2(rect.position.x + 40, rect.position.y - 7), "home": Vector2(rect.position.x + 40, rect.position.y - 7), "left": rect.position.x + 10, "right": rect.end.x - 10, "dir": 1.0, "kind": "crawler", "hp": 2, "t": float(i), "hit": 0.0})
	for i in [9, 12, 16, 19, 22, 24]:
		var rect: Rect2 = platforms[i]
		var p := Vector2(rect.position.x - 25, rect.position.y - 38)
		enemies.append({"p": p, "home": p, "dir": 1.0, "kind": "flyer", "hp": 2, "t": float(i), "hit": 0.0})

func _fill(x0: int, x1: int, y0: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			tiles[Vector2i(x,y)] = true

func _physics_process(delta: float) -> void:
	time += delta
	if started and not paused and not finished:
		elapsed += delta
		message_time = maxf(0, message_time - delta)
		_update_pickups()
		_update_enemies(delta)
		_update_bullets(delta)
		if player.position.y < -1470 and player.position.distance_to(Vector2(256,-1515)) < 45:
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
	var target := Vector2(320, clampf(player.position.y - 48, -1500, 324))
	if not started:
		target = Vector2(320,324)
	camera.position = camera.position.lerp(target, 1.0 - exp(-delta * 7))
	shake = maxf(shake - delta * 15, 0)
	camera.offset = Vector2(rng.randf_range(-shake,shake), rng.randf_range(-shake,shake))
	scenery.queue_redraw()
	hud.queue_redraw()
	queue_redraw()

func _update_pickups() -> void:
	for pickup: Dictionary in pickups:
		if pickup.taken or player.position.distance_to(pickup.p) > 23:
			continue
		pickup.taken = true
		match pickup.kind:
			"gun":
				player.gun_unlocked = true
				notify("PULSE TOOL RECOVERED  /  Aim + click, or J. Fire DOWN in midair to rise.", 9)
			"jump":
				player.jump_unlocked = true
				player.state.double_jump_available = true
				notify("AIR JUMP ONLINE  /  Press SPACE again in the air. Reach the hanging gardens.", 8)
			"dash":
				player.dash_unlocked = true
				player.state.dash_available = true
				notify("VECTOR DRIVE ONLINE  /  Hold a direction + SHIFT to dash. The sky is close.", 8)
		player.health = 5
		burst(pickup.p, Color("80f2d2"), 30)
		sound("save")
	for i in range(checkpoints.size()):
		if i > checkpoint_index and player.position.distance_to(checkpoints[i]) < 25:
			checkpoint_index = i
			player.spawn_point = checkpoints[i]
			player.health = 5
			notify("SIGNAL ANCHOR LINKED  /  Health restored. Your climb resumes here.", 5)
			burst(checkpoints[i], Color("80f2d2"), 20)
			sound("save")

func _update_enemies(delta: float) -> void:
	for e: Dictionary in enemies:
		if e.hp <= 0:
			continue
		e.t += delta
		e.hit = maxf(0, e.hit - delta)
		if e.kind == "crawler":
			e.p.x += e.dir * 27 * delta
			if e.p.x < e.left or e.p.x > e.right:
				e.dir *= -1
				e.p.x = clampf(e.p.x, e.left, e.right)
		else:
			var home: Vector2 = e.home
			var target := home + Vector2(sin(e.t * 1.5) * 34, cos(e.t * 2) * 16)
			if player.position.distance_to(home) < 115:
				target = player.position + Vector2(0,-4)
			e.p = e.p.move_toward(target, delta * 38)
		if player.position.distance_to(e.p) < 15:
			player.hurt(e.p)

func fire(p: Vector2, direction: Vector2) -> void:
	bullets.append({"p": p, "v": direction * 520, "life": 0.8})
	burst(p, Color("ffe6a3"), 4)
	shake = maxf(shake, 0.8)

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.life -= delta
		# Substeps prevent fast projectiles skipping thin collision or enemies.
		for step in range(3):
			b.p += b.v * delta / 3.0
			if tiles.has(Vector2i(floori(b.p.x / 16), floori(b.p.y / 16))):
				b.life = 0
				burst(b.p, Color("efbd78"), 5)
				break
			for e: Dictionary in enemies:
				if e.hp > 0 and b.p.distance_to(e.p) < 12:
					e.hp -= 1
					e.hit = 0.15
					b.life = 0
					burst(e.p, Color("e9a878"), 8)
					if e.hp <= 0:
						kills += 1
						burst(e.p, Color("d294ba"), 16)
						sound("kill")
					break
			if b.life <= 0:
				break
		if b.life <= 0:
			bullets.remove_at(i)

func burst(p: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"p": p, "v": Vector2(rng.randf_range(-45,45), rng.randf_range(-55,15)), "color": color, "life": rng.randf_range(0.15,0.6)})

func notify(text: String, duration: float) -> void:
	message = text
	message_time = duration

func on_respawn() -> void:
	deaths += 1
	bullets.clear()
	camera.position = Vector2(320,clampf(player.position.y - 48,-1500,324))
	notify("SUIT RECONSTRUCTED  /  Equipment retained. Keep climbing.", 4)

func sound(kind: String) -> void:
	if audio and not muted:
		audio.play_effect(kind)

func zone() -> String:
	if player.position.y > 100:
		return "01 / THE IMPACT HOLLOW"
	if player.position.y > -570:
		return "02 / LUMEN GROTTO"
	if player.position.y > -1050:
		return "03 / THE HANGING GARDENS"
	return "04 / FIRST LIGHT"

func _draw() -> void:
	for checkpoint in checkpoints:
		var lit := checkpoints.find(checkpoint) <= checkpoint_index
		draw_rect(Rect2(checkpoint + Vector2(-6,-18),Vector2(12,26)),Color("354e59"))
		draw_rect(Rect2(checkpoint + Vector2(-3,-16),Vector2(6,18)),Color("78eac5") if lit else Color("587b80"))
		draw_circle(checkpoint + Vector2(0,-20),3,Color("c5ffe3") if lit else Color("9caeaa"))
	for pickup: Dictionary in pickups:
		if pickup.taken:
			continue
		var p: Vector2 = pickup.p + Vector2(0,sin(time * 3) * 3)
		draw_circle(p, 17, Color(0.4,0.95,0.8,0.07))
		draw_arc(p, 12, time, time + 4.5, 12, Color("5c9a96"),1)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7),p+Vector2(7,0),p+Vector2(0,7),p+Vector2(-7,0)]),Color("81efcd"))
		draw_rect(Rect2(p-Vector2(2,3),Vector2(4,6)),Color("f7f5c3"))
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
		else:
			var wing := sin(e.t * 20) * 6
			draw_colored_polygon(PackedVector2Array([p+Vector2(-3,0),p+Vector2(-17,-8+wing),p+Vector2(-12,5),p+Vector2(0,5)]),color)
			draw_colored_polygon(PackedVector2Array([p+Vector2(3,0),p+Vector2(17,-8+wing),p+Vector2(12,5),p+Vector2(0,5)]),color)
			draw_rect(Rect2(p+Vector2(-4,-5),Vector2(8,11)),Color("474960"))
			draw_rect(Rect2(p+Vector2(-3,-3),Vector2(6,2)),Color("ffcc84"))
	for b: Dictionary in bullets:
		draw_line(b.p - b.v.normalized() * 9, b.p, Color("fff0b1"),2)
	for p: Dictionary in particles:
		var color: Color = p.color
		color.a = minf(1,p.life * 4)
		draw_rect(Rect2(p.p.round(),Vector2(2,2)),color)
	# Rescue transmitter on the final island.
	draw_rect(Rect2(253,-1550,6,46),Color("afc5bf"))
	draw_rect(Rect2(244,-1510,24,6),Color("637f80"))
	draw_circle(Vector2(256,-1551),4,Color("ffdf98"))
	for i in range(3):
		var radius := fmod(time * 18 + i * 14,42)
		draw_arc(Vector2(256,-1551),radius,PI,TAU,24,Color(0.7,1,0.85,(1-radius/42)*0.45),1)
