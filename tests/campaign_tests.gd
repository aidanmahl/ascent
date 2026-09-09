extends SceneTree
var failures := 0
var w: Node2D
var traces: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("[PASS] " if ok else "[FAIL] ",label)
	if not ok: failures += 1
func run() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 50
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void: quit(1))
	root.add_child(watchdog)
	watchdog.start()
	w = load("res://scenes/main.tscn").instantiate()
	root.add_child(w)
	w.muted = true
	w.set_physics_process(false)
	w.player.set_physics_process(false)
	check(w.campaign.rooms.size()==25 and w.campaign.edges.size()==37,"25 physical rooms and 37 shared seams")
	check(w.player.position==CampaignLayout.START,"campaign starts in Wreck Orchard")
	for edge: Dictionary in w.campaign.edges:
		var delta: Vector2 = CampaignLayout.origin(edge.b)-CampaignLayout.origin(edge.a)
		check(delta==Vector2(640,0) or delta==Vector2(0,480),"adjacent seam %d-%d"%[edge.a,edge.b])
	for point: Vector2 in [Vector2(636,1832),Vector2(644,1832),Vector2(1088,1916),Vector2(1088,1924)]:
		w.player.position=point
		w.player.state.position=point
		w.player.state.velocity=Vector2(8,2)
		w.player.state.timers["dash_timer"]=7
		w.player.ammo=0
		w.player.health=2
		w.rooms.update_membership()
		check(w.player.position==point and w.player.state.velocity==Vector2(8,2) and w.player.ammo==0 and w.player.health==2 and w.player.state.timers.dash_timer==7,"seam discovery preserves position, momentum and resources")
	w.player.position=CampaignLayout.START
	w.player.state.position=w.player.position
	w.player.health=3
	for anchor: Vector2 in w.checkpoints:
		var supported: bool = w.tiles.has(Vector2i(floori(anchor.x/16),floori((anchor.y+9)/16)))
		check(supported,"anchor in room %d has supporting terrain"%CampaignLayout.room_at(anchor))
		w.player.position=anchor
		var camera_position: Vector2=w.rooms.camera_target()
		check(Rect2(camera_position-Vector2(310,170),Vector2(620,340)).has_point(anchor),"anchor camera contains the complete player")
	w.player.position=CampaignLayout.START
	var spawn_body := TileCollision.resolve(w.player.position,Vector2(0,1),w.player.config.collider_size,w.tiles,16,2.0)
	check(spawn_body.position.distance_to(w.player.position)<2,"start anchor has clear collider and supporting terrain")
	for item: Dictionary in w.pickups:
		var clear := true
		for cell: Vector2i in w.tiles:
			if Rect2(Vector2(cell*16),Vector2(16,16)).intersects(Rect2(item.p-Vector2(4,7),Vector2(8,14))): clear=false
		check(clear,"pickup %s in room %d is body-clear"%[item.kind,item.room])
		if item.kind=="fragment":
			w.player.position = item.p
			w._update_pickups()
	check(w.suit_fragments==2 and w.player.max_health==4,"two fragments, in either order, grant exactly one health")
	w._update_pickups()
	check(w.player.max_health==4,"fragment collection is idempotent")
	for path: Dictionary in w.campaign.paths:
		if path.kind not in ["boots","cells","dash"]: continue
		var cells := 2 if path.kind=="cells" else 1
		var reached := reach(path.from,path.to,cells,path.kind=="dash",path.kind=="boots")
		check(reached,"physical %s transfer in room %d"%[path.kind,path.room])
		if path.kind=="boots" and path.room==11:
			check(not reach(path.from,path.to,1,false,false),"western boot well cannot be jumped with one recoil cell")
		if path.kind=="dash" and path.room==7:
			check(not reach(path.from,path.to,1,false,true),"Harp gallery cannot be crossed before dash")
	w.player.position = CampaignLayout.origin(8)+Vector2(368,296)
	check(reach(CampaignLayout.origin(8)+Vector2(368,304),CampaignLayout.origin(8)+Vector2(320,144),2,true,true),"two-cell core nest is reachable")
	check(not reach(CampaignLayout.origin(8)+Vector2(368,304),CampaignLayout.origin(8)+Vector2(320,144),1,true,true),"core nest needs second cell")
	check(reach(Vector2(96,944),Vector2(320,944),1,false,true),"Bell floor gap return")
	for edge: Dictionary in w.campaign.edges:
		if edge.axis=="NS" and edge.requires.is_empty():
			var lower := CampaignLayout.origin(edge.b)+Vector2(edge.offset+64,48)
			var upper := CampaignLayout.origin(edge.a)+Vector2(edge.offset-96,432)
			var catch_ledge := CampaignLayout.origin(edge.a)+Vector2(edge.offset-48,448)
			check(reach(lower,catch_ledge,1,false,false) and reach(catch_ledge,upper,1,false,false),"free shaft %d-%d has a one-cell return before boots"%[edge.a,edge.b])
	# Restoration state is independent of objective order.
	for core_first in [true,false]:
		w.locks.core=false
		w.locks.pump=false
		w.locks.reservoir=false
		w.player.position=CampaignLayout.origin(24)+Vector2(240,388)
		w.rooms.update(0)
		check(not w.locks.pump,"pump cannot activate before Rootheart")
		if core_first: w.locks.core=true
		w.locks.reservoir=true
		w.rooms.update(0)
		if not core_first: w.locks.core=true
		w.rooms.update(0)
		check(w.locks.pump and w.locks.wind,"pump/core restoration works in either order")
	var lift: Dictionary=w.campaign.lifts[0]
	lift.phase=0.0
	lift.y=lift.bottom
	w.player.position=Vector2(lift.x-40,lift.bottom-8)
	w.player.state=MovementState.new()
	w.player.state.position=w.player.position
	w.player.state.on_floor=true
	w.player.state.double_jump_enabled=false
	var minimum_y: float=w.player.position.y
	var max_step := 0.0
	for frame in range(290):
		var old_y: float=w.player.position.y
		w.rooms.update(1.0/60)
		PlayerMovement.process(w.player.state,w.player.config,w.tiles)
		w.player.position=w.player.state.position
		minimum_y=minf(minimum_y,w.player.position.y)
		max_step=maxf(max_step,absf(w.player.position.y-old_y))
	check(lift.bottom-8-minimum_y>450 and max_step<4,"pump lift carries player physically between adjacent rooms")
	for arena: Dictionary in w.arenas.rooms:
		w.arenas.active_room=arena
		w.player.position=arena.center+Vector2(0,48)
		var bounds := Rect2(CampaignLayout.origin(arena.room),CampaignLayout.CELL)
		for enemy: Dictionary in w.enemies:
			if enemy.id!=arena.id: continue
			for volley in range(6):
				enemy.cooldown=0
				w.arenas.tick_boss(enemy,1.0/60)
		check(not w.arenas.attacks.is_empty(),"%s schedules attacks in its physical room"%arena.id)
		var contained := true
		for attack: Dictionary in w.arenas.attacks:
			if not bounds.encloses(attack.rect): contained=false
		check(contained,"%s attacks stay inside room bounds"%arena.id)
		w.arenas.reset()
		w.hostile.clear()
	# A retreat from the optional alcove cannot block later boss activation.
	w.locks.warden=false
	w.arenas.active_room=w.arenas.rooms[0]
	w.player.position=CampaignLayout.START
	w.arenas.update(0)
	check(w.arenas.active_room.is_empty(),"retreating from Warden releases encounter state")
	var file := FileAccess.open("res://tools/campaign_traces.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(traces))
	print("CAMPAIGN FAILURES: ",failures)
	quit(0 if failures==0 else 1)

func reach(a: Vector2,b: Vector2,cells: int,dash: bool,boots: bool) -> bool:
	var best := INF
	var best_p := a
	for offset in [-48,-32,0,32,48]:
		for shot_at in [-1,1,6,10,16,22,28,34,40]:
			for dash_at in ([-1,4,10,18,26] if dash else [-1]):
				for mode in ([0,1,2,3,4,5] if boots else [0,2]):
					var s := MovementState.new()
					s.position = a+Vector2(offset,-8)
					var embedded := false
					for tx in range(floori((s.position.x-4)/16),ceili((s.position.x+4)/16)):
						for ty in range(floori((s.position.y-7)/16),ceili((s.position.y+7)/16)):
							if w.tiles.has(Vector2i(tx,ty)): embedded=true
					if embedded: continue
					s.on_floor = true
					s.double_jump_enabled = false
					s.wall_jump_enabled = boots
					s.ground_refill_only = true
					s.dash_available = dash
					var ammo := cells
					var trace: Array = []
					for frame in range(140):
						var dx := b.x-s.position.x
						if mode in [1,4] and s.wall_kick_available: dx=100
						if mode==4 and not s.wall_kick_available and s.position.y+8>b.y: dx=0
						if mode==5 and s.position.y+8>b.y: dx=100
						if mode==3 and s.wall_kick_available: dx=-100
						if mode==2 and s.position.y+8>b.y: dx=0
						s.move_left = dx < -4
						s.move_right = dx > 4
						s.jump_pressed = frame==0
						if boots and frame>0 and s.wall_kick_available and (s.on_wall_left or s.on_wall_right) and s.velocity.y>-1:
							s.jump_pressed=true
							s.move_left=s.on_wall_right
							s.move_right=s.on_wall_left
						s.dash_pressed=frame==dash_at
						PlayerMovement.process(s,w.player.config,w.tiles)
						if shot_at>=0 and frame>=shot_at and (frame-shot_at)%12==0 and ammo>0 and not s.on_floor:
							Player.apply_recoil(s,Vector2.DOWN)
							ammo-=1
						if s.position.distance_to(b-Vector2(0,8))<best:
							best=s.position.distance_to(b-Vector2(0,8))
							best_p=s.position
						trace.append([s.position.x,s.position.y])
						if s.on_floor and s.position.y+8<=b.y+1 and s.position.y+8>=b.y-64 and absf(s.position.x-b.x)<46:
							traces.append({"a":[a.x,a.y],"b":[b.x,b.y],"positions":trace})
							return true
						if s.position.y>a.y+130: break
	# Unsuccessful schedules are expected for negative ability checks.
	return false
