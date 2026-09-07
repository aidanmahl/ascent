extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		print("[PASS] ",label)
	else:
		printerr("[FAIL] ",label)
		failures += 1

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.muted = true
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var config: MovementConfig = world.player.config
	var route: Array[Rect2] = [Rect2(80,480,190,16)]
	route.append_array(world.platforms)
	for i in range(route.size()-1):
		var found := false
		var source: Rect2 = route[i]
		var target: Rect2 = route[i+1]
		for x in range(int(source.position.x)+6,int(source.end.x)-5,8):
			if found:
				break
			for double_frame in [-1,14,22,30]:
				if double_frame >= 0 and i < 8:
					continue
				var s := MovementState.new()
				s.position = Vector2(x,source.position.y-8)
				s.on_floor = true
				s.double_jump_available = i >= 8
				for frame in range(100):
					var dx := target.get_center().x-s.position.x
					s.move_left = dx < -4
					s.move_right = dx > 4
					s.jump_pressed = frame == 0 or frame == double_frame
					if i < 8:
						s.double_jump_available = false
					PlayerMovement.process(s,config,world.tiles)
					if s.on_floor and absf(s.position.y+8-target.position.y)<0.2 and s.position.x > target.position.x-2 and s.position.x < target.end.x+2:
						found = true
						break
				if found:
					break
		check(found,"route landing %02d reachable with available equipment" % (i+1))
	var player: Player = world.player
	player.gun_unlocked = true
	player.state.on_floor = false
	player.state.velocity = Vector2(0,4)
	player.aim = Vector2.DOWN
	player.shoot()
	check(player.state.velocity.y < 0 and player.ammo == 2,"downward recoil reverses falling velocity and consumes one charge")
	check(world.bullets.size() == 1,"gun creates a live projectile")
	player.shot_timer = 0
	player.ammo = 0
	player.shoot()
	check(world.bullets.size() == 1,"empty gun cannot create projectiles")
	world.bullets.clear()
	var enemy: Dictionary = world.enemies[0]
	for hit in range(2):
		world.fire(enemy.p-Vector2(10,0),Vector2.RIGHT)
		world._update_bullets(1.0/60)
	check(enemy.hp == 0 and world.kills == 1,"two pulse hits defeat a crawler")
	player.position = world.pickups[1].p
	world._update_pickups()
	check(player.jump_unlocked,"air jump module unlocks the ability")
	player.position = world.pickups[2].p
	world._update_pickups()
	check(player.dash_unlocked,"vector module unlocks dash")
	player.position = world.checkpoints[1]
	world._update_pickups()
	check(player.spawn_point == world.checkpoints[1],"checkpoint updates recovery location")
	player.health = 1
	player.respawn()
	check(player.health == 5 and player.ammo == 3 and player.jump_unlocked and player.dash_unlocked,"recovery restores suit and preserves equipment")
	world.bullets.clear()
	world.fire(Vector2(20,400),Vector2.LEFT)
	world._update_bullets(1.0/60)
	check(world.bullets.is_empty(),"terrain blocks pulse projectiles")
	player.ammo = 3
	player.shot_timer = 0
	player.state.on_floor = false
	player.state.velocity = Vector2.ZERO
	player.aim = Vector2.RIGHT
	player.shoot()
	check(player.state.velocity.x < 0,"horizontal fire imparts opposite recoil")
	player.shoot()
	check(player.ammo == 2,"fire cooldown prevents multiple shots in one frame")
	player.active = true
	player.invincible = 0
	player.health = 5
	player.hurt(player.position-Vector2(10,0))
	player.hurt(player.position-Vector2(10,0))
	check(player.health == 4,"damage grants an invulnerability window")
	player.gun_unlocked = false
	player.jump_unlocked = false
	player.dash_unlocked = false
	player.state = MovementState.new()
	player.position = Vector2(330,200)
	player.state.double_jump_available = true
	player.state.dash_available = true
	Input.action_press("jump")
	Input.action_press("dash")
	player._physics_process(1.0/60)
	Input.action_release("jump")
	Input.action_release("dash")
	check(player.state.velocity.y >= 0 and int(player.state.timers.get("dash_timer",0)) == 0,"shell prevents air jump and dash before module recovery")
	world.free()
	quit(1 if failures else 0)
