extends SceneTree
var failures := 0
var w: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	if ok:
		print("[PASS] ",label)
	else:
		printerr("[FAIL] ",label)
		failures += 1

# Search actual movement steps, including collision with the entire authored
# level, ammo cooldown, ground-only refills, optional dash and a single kick.
func reach(source: Rect2,target: Rect2,cells: int,dash: bool,boots: bool) -> bool:
	var cfg: MovementConfig = w.player.config
	for start_x in range(int(source.position.x)+8,int(source.end.x)-6,16):
		for shot_start in [-1,1,6,12,18,24]:
			if cells == 0 and shot_start != -1:
				continue
			for dash_at in ([-1,6,18,30,42] if dash else [-1]):
				for mode in ([0,1,2] if boots else [0,2]):
					var s := MovementState.new()
					s.double_jump_enabled = false
					s.wall_jump_enabled = boots
					s.ground_refill_only = true
					s.position = Vector2(start_x,source.position.y-8)
					s.on_floor = true
					s.dash_available = dash
					# Wide authored ledges allow a normal run-up. Test at full run speed
					# so both positive routes and sequence-break checks model play.
					var launch_slot := (start_x - (int(source.position.x) + 8)) / 16
					s.velocity.x = 0.0 if launch_slot % 2 == 0 else signf(target.get_center().x-source.get_center().x) * cfg.max_run_speed
					var remaining := cells
					for frame in range(160):
						var dx := target.get_center().x-s.position.x
						if mode == 1 and s.wall_kick_available and frame < 65:
							dx = 100
						if mode == 2 and s.position.y+8 > target.position.y:
							dx = 0
						s.move_left = dx < -5
						s.move_right = dx > 5
						s.jump_pressed = frame == 0 or (mode == 1 and s.on_wall_right and s.wall_kick_available and s.velocity.y > -1)
						if frame > 0 and s.jump_pressed:
							s.move_left = true
							s.move_right = false
						s.dash_pressed = frame == dash_at
						s.look_up = s.dash_pressed
						var previous := s.position
						PlayerMovement.process(s,cfg,w.tiles)
						for gate: Dictionary in w.gates:
							if gate.kind == "phase" and int(s.timers.get("dash_timer",0)) <= 0 and Rect2(s.position-Vector2(4,7),Vector2(8,14)).intersects(gate.rect):
								s.position = previous
								s.velocity.y = maxf(1,s.velocity.y)
						if shot_start >= 0 and frame >= shot_start and (frame-shot_start)%12 == 0 and remaining > 0 and not s.on_floor:
							Player.apply_recoil(s,Vector2.DOWN)
							remaining -= 1
						if s.on_floor and absf(s.position.y+8-target.position.y)<0.2 and s.position.x > target.position.x-2 and s.position.x < target.end.x+2:
							return true
						if s.position.y > source.position.y+100:
							break
	return false

func run() -> void:
	w = load("res://scenes/main.tscn").instantiate()
	root.add_child(w)
	w.muted = true
	w.set_physics_process(false)
	w.player.set_physics_process(false)
	var route: Array[Rect2] = [Rect2(80,480,190,16)]
	route.append_array(w.platforms)
	for i in range(route.size()-1):
		var cells := 0 if i < 5 else (1 if i < 12 else (2 if i < 30 else 3))
		if i == 19:
			var launch := Rect2(256,-1008,160,16)
			check(reach(route[i],launch,2,false,true) and reach(launch,route[i+1],2,false,true),"boot chimney via its lower landing is reachable")
			check(not reach(launch,route[i+1],2,false,false),"boot chimney upper transfer requires a kick")
			continue
		check(reach(route[i],route[i+1],cells,i>=24,i>=19),"route %02d with %d cells / dash %s / boots %s" % [i+1,cells,i>=24,i>=19])
	check(not reach(route[6],route[7],0,false,false),"first recoil shaft cannot be cleared without the gun")
	check(not reach(route[12],route[13],1,false,false),"two-cell hollow cannot be cleared with one cell")
	check(not reach(route[19],route[20],2,false,false),"boot chimney requires a wall kick even with both recoil cells")
	check(w.gates.filter(func(g: Dictionary) -> bool: return g.lock == "warden").size() > 0,"upper hollow is sealed until the second magazine guardian is defeated")
	check(w.gates.filter(func(g: Dictionary) -> bool: return g.lock == "boots").size() > 0,"wall transfer is sealed until kick boots are earned")
	check(not reach(route[24],route[25],3,false,true),"membrane route requires dash even with all three cells")
	var p: Player = w.player
	check(p.health == 3 and p.max_ammo == 0 and not p.wall_unlocked,"start with three health, no weapon and no wall kick")
	p.position = w.pickups[1].p
	w._update_pickups()
	check(p.max_ammo == 0 and not w.pickups[1].taken,"guardian cage prevents collecting magazine early")
	p.position = w.pickups[0].p
	w._update_pickups()
	check(p.gun_unlocked and p.max_ammo == 1,"salvage cutter begins with exactly one charge")
	w.locks.warden = true
	p.position = w.pickups[1].p
	w._update_pickups()
	check(p.max_ammo == 2,"first guardian awards the second cell")
	p.state.on_floor = false
	p.state.velocity = Vector2(0,4)
	p.aim = Vector2.DOWN
	p.shoot()
	check(p.state.velocity.y < 0 and p.ammo == 1,"downward shot lifts and consumes a cell")
	p.shoot()
	check(p.ammo == 1,"shot cooldown prevents a second immediate pulse")
	w.bullets.clear()
	w.hostile.clear()
	w.spawn_hostile(Vector2(290,200),Vector2.RIGHT,70)
	var before: Vector2 = w.hostile[0].p
	w._update_hostile(0.5)
	check(w.hostile[0].p.is_equal_approx(before+Vector2(35,0)),"hostile bullet follows constant straight-line velocity")
	var target: Vector2 = w.hostile[0].p
	w.fire(target-Vector2(9,0),Vector2.RIGHT)
	w._update_bullets(1.0/60)
	check(w.hostile.is_empty(),"player pulse destroys an enemy projectile")
	p.state = MovementState.new()
	p.state.ground_refill_only = true
	p.state.double_jump_enabled = false
	p.state.on_wall_right = true
	PlayerMovement._refill_abilities(p.state)
	check(not p.state.dash_available and not p.state.double_jump_available,"wall contact never refills dash or grants an air jump")
	p.active = true
	p.invincible = 0
	p.health = 3
	p.hurt(p.position-Vector2(10,0))
	p.hurt(p.position-Vector2(10,0))
	check(p.health == 2,"contact damage respects invulnerability window")
	for relay: Dictionary in w.switches:
		relay.lit = true
		relay.timer = 1
	w._update_challenges(0.1)
	check(w.locks.get("boots",false),"two timed relay hits unlock the boot cage")
	w.locks.reservoir = true
	p.position = w.pickups[4].p
	w._update_pickups()
	check(p.max_ammo == 3,"last magazine raises capacity to three")
	p.state.on_floor = false
	p.flight_id = 7
	for i in range(3):
		w.fire(w.capacitor.p-Vector2(0,9),Vector2.DOWN,true,7)
		w._update_bullets(1.0/60)
	check(w.locks.get("airlock",false),"three shots in one flight unlock the upper canopy")
	w.locks.erase("airlock")
	w.capacitor.hits = 0
	p.state = MovementState.new()
	p.state.double_jump_enabled = false
	p.state.wall_jump_enabled = true
	p.state.ground_refill_only = true
	# The traversal puzzle is solved from above: fire downward through the
	# core while recoil carries the same airborne flight into the airlock.
	p.state.position = w.capacitor.p - Vector2(0, 45)
	p.state.velocity = Vector2(0,-5.2)
	p.ammo = 3
	p.flight_id = 9
	p.aim = Vector2.DOWN
	p.shot_timer = 0
	for frame in range(80):
		PlayerMovement.process(p.state,p.config,w.tiles)
		p.position = p.state.position
		p.shot_timer = maxf(0,p.shot_timer-1.0/60)
		if frame in [0,12,24]:
			p.shoot()
		w._update_bullets(1.0/60)
		w._update_challenges(1.0/60)
	check(w.locks.get("airlock",false),"core puzzle works with actual three-shot recoil and projectile travel")
	w.locks.erase("airlock")
	w.capacitor.hits = 0
	p.state.on_floor = true
	for i in range(3):
		w.fire(w.capacitor.p-Vector2(0,9),Vector2.DOWN,false,9)
		w._update_bullets(1.0/60)
	check(not w.locks.get("airlock",false),"ground fire cannot bypass the three-cell airborne core")
	w.capacitor.hits = 2
	w._update_challenges(0.1)
	check(w.capacitor.hits == 0,"landing resets incomplete airborne core progress")
	w.locks.erase("boots")
	for relay: Dictionary in w.switches:
		relay.lit = true
		relay.timer = 0.01
	w._update_challenges(0.1)
	check(not w.locks.get("boots",false),"expired relay timers do not unlock equipment")
	var kick := MovementState.new()
	kick.wall_jump_enabled = true
	kick.double_jump_enabled = false
	kick.ground_refill_only = true
	kick.on_wall_right = true
	kick.jump_pressed = true
	kick.move_left = true
	PlayerMovement._apply_jump(kick,p.config,false)
	check(not kick.wall_kick_available and kick.velocity.y == p.config.wall_jump_velocity.y,"first wall kick consumes the single airborne charge")
	kick.velocity = Vector2.ZERO
	kick.on_wall_right = true
	PlayerMovement._apply_jump(kick,p.config,false)
	check(kick.velocity == Vector2.ZERO,"repeated wall contact cannot chain a second wall kick")
	kick.on_floor = true
	PlayerMovement._refill_abilities(kick)
	check(kick.wall_kick_available,"landing restores the wall kick")
	kick.wall_jump_enabled = false
	kick.on_floor = false
	kick.on_wall_right = true
	kick.velocity = Vector2.ZERO
	kick.timers.clear()
	PlayerMovement._apply_jump(kick,p.config,false)
	check(kick.velocity == Vector2.ZERO,"wall jumping is unavailable before obtaining boots")
	for e: Dictionary in w.enemies:
		if e.id == "sentinel":
			e.hp = 1
	p.respawn()
	var reset_ok: bool = w.hostile.is_empty()
	for e: Dictionary in w.enemies:
		if e.id == "sentinel":
			reset_ok = reset_ok and e.hp == e.max_hp
	check(reset_ok and p.health == 3 and p.max_ammo == 3,"recovery resets unfinished bosses and restores health without losing equipment")
	var s_clone := kick.clone()
	check(s_clone.ground_refill_only and not s_clone.double_jump_enabled and not s_clone.wall_jump_enabled,"movement snapshots preserve progression restrictions")
	p.active = true
	p.invincible = 0
	p.health = 1
	w.hostile.clear()
	w.hostile.append({"p":p.position,"v":Vector2.ZERO,"life":2.0})
	w.hostile.append({"p":p.position,"v":Vector2.ZERO,"life":2.0})
	w._update_hostile(1.0/60)
	check(w.hostile.is_empty() and p.health == 3,"lethal bullet safely clears an entire volley during recovery")
	# Exercise the live input path: W is dash direction, mouse fire retains aim.
	p.position = Vector2(120,472)
	PlayerMovement._reset(p.state,p.position)
	p.state.on_floor = true
	p.active = true
	p.max_ammo = 1
	p.ammo = 1
	p.shot_timer = 0
	w.bullets.clear()
	Input.action_press("look_up")
	Input.action_press("fire")
	p._physics_process(1.0/60)
	var mouse_direction := (p.get_global_mouse_position()-p.position).normalized()
	check(p.aim.is_equal_approx(mouse_direction),"mouse fire ignores held vertical dash input")
	Input.action_release("look_up")
	for frame in range(180):
		p._physics_process(1.0/60)
	Input.action_release("fire")
	check(w.bullets.size() <= 5,"three seconds of grounded fire is limited by recharge and shot cadence")
	Input.action_press("look_down")
	Input.action_press("fire_key")
	p._physics_process(1.0/60)
	check(p.aim == Vector2.DOWN,"keyboard downward recoil shortcut remains available")
	Input.action_release("fire_key")
	p._physics_process(1.0/60)
	check(p.aim.is_equal_approx((p.get_global_mouse_position()-p.position).normalized()),"mouse aim resumes without cursor movement when keyboard fire ends")
	Input.action_release("look_down")
	check(w.arenas.rooms.size() == 4,"four separate boss chambers are built")
	for room: Dictionary in w.arenas.rooms:
		w.arenas.active_room = room
		p.position = room.spawn
		w.arenas.attacks.clear()
		w.hostile.clear()
		for e: Dictionary in w.enemies:
			if e.id != room.id:
				continue
			e.hp = e.max_hp
			for volley in range(4):
				if volley == 2:
					e.hp = e.max_hp/2
				e.cooldown = 0
				w.arenas.tick_boss(e,1.0/60)
			check(not w.arenas.attacks.is_empty(),room.id+" produces telegraphed arena hazards")
			check(not w.hostile.is_empty(),room.id+" produces projectile patterns")
			check(e.p.x > 640,room.id+" stays in its separate room")
	w.arenas.reset()
	for room: Dictionary in w.arenas.rooms:
		var progress_gates: Array = w.gates.filter(func(g: Dictionary) -> bool: return g.lock == room.id)
		check(not progress_gates.is_empty() and progress_gates[0].rect.position.y < room.door.y-16,room.id+" entrance is below its progress seal")
	var entry: Dictionary = w.arenas.rooms[0]
	p.position = entry.door
	w.arenas.enter_room(entry)
	check(p.position == entry.spawn and w.arenas.active_room.id == "warden","entering chamber sets player and arena camera")
	w.locks.warden = true
	w.arenas.leave_room()
	check(p.position == entry.door and w.arenas.active_room.is_empty(),"return to the climb after a boss victory")
	w.locks.erase("warden")
	p.position = entry.door
	w.arenas.enter_room(entry)
	w.arenas.leave_room()
	check(not w.arenas.active_room.is_empty(),"unfinished encounter seals the arena exit")
	p.respawn()
	check(p.position == entry.door and w.arenas.active_room.is_empty(),"arena death returns to its entrance for a quick retry")
	w.wall_kicked(Vector2(440,-1840))
	check(w.locks.get("kick_latch",false),"wall kick releases the second traversal latch")
	w.free()
	quit(1 if failures else 0)
