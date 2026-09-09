class_name CampaignNavigator
extends RefCounted
## Offline route verifier. Searches actual exposed tile surfaces, then validates
## edges by stepping production movement. Returned frames can be replayed intact.
var world: Node2D
var surfaces: Array[Rect2] = []
var calls := 0
var failures: Dictionary = {}
func _init(w: Node2D) -> void:
	world=w
	for cell: Vector2i in w.tiles:
		if w.tiles.has(cell+Vector2i.UP) or (w.tiles.has(cell+Vector2i.LEFT) and not w.tiles.has(cell+Vector2i.LEFT+Vector2i.UP)):
			continue
		var width := 0
		while w.tiles.has(cell+Vector2i(width,0)) and not w.tiles.has(cell+Vector2i(width,-1)):
			width+=1
		if width>=2:
			surfaces.append(Rect2(Vector2(cell*16),Vector2(width*16,16)))

func navigate(start: Vector2,goal: Vector2,cells: int,dash: bool,boots: bool,allowed: Array) -> Dictionary:
	failures.clear()
	var nodes: Array[Dictionary] = []
	var first: MovementState = world.player.state.clone()
	first.position=start
	first.double_jump_enabled=false
	first.wall_jump_enabled=boots
	first.ground_refill_only=true
	first.dash_available=dash
	first.move_left=false
	first.move_right=false
	first.jump_pressed=false
	first.dash_pressed=false
	var settling: Array=[]
	for frame in range(8):
		PlayerMovement.process(first,world.player.config,world.tiles)
		settling.append({"left":false,"right":false,"jump":false,"dash":false,"shot":false,"p":[first.position.x,first.position.y]})
	nodes.append({"state":first,"trace":settling,"cost":0.0,"key":-1})
	var visited: Dictionary = {}
	var attempt := 0
	var began := Time.get_ticks_msec()
	while not nodes.is_empty() and attempt<90:
		if Time.get_ticks_msec()-began>30000: break
		attempt+=1
		nodes.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.cost+a.state.position.distance_to(goal)*1.2<b.cost+b.state.position.distance_to(goal)*1.2)
		var current: Dictionary = nodes.pop_front()
		var state: MovementState = current.state
		if state.position.distance_to(goal)<18:
			return current
		if absf(state.position.y-goal.y)<6:
			var direct := transfer(state,Rect2(Vector2(goal.x-12,state.position.y+8),Vector2(24,16)),cells,dash,boots)
			if not direct.is_empty() and direct.state.position.distance_to(goal)<18:
				current.trace.append_array(direct.trace)
				current.state=direct.state
				return current
		if visited.has(current.key): continue
		visited[current.key]=true
		var candidates: Array[int] = []
		for i in range(surfaces.size()):
			var r := surfaces[i]
			if visited.has(i): continue
			var center := Vector2(clampf(state.position.x,r.position.x+8,r.end.x-8),r.position.y-8)
			if CampaignLayout.room_at(center) not in allowed: continue
			var dx := absf(center.x-state.position.x)
			var dy := state.position.y-center.y
			if dx>460 or dy>220 or dy < -400: continue
			candidates.append(i)
		candidates.sort_custom(func(a: int,b: int) -> bool: return surfaces[a].get_center().distance_to(goal)<surfaces[b].get_center().distance_to(goal))
		for index in candidates.slice(0,16):
			var r := surfaces[index]
			var key := "%s_%d_%d_%s_%s"%[current.key,index,cells,dash,boots]
			if failures.has(key): continue
			var result := transfer(state,r,cells,dash,boots)
			if result.is_empty():
				failures[key]=true
				continue
			var trace: Array = current.trace.duplicate()
			trace.append_array(result.trace)
			nodes.append({"state":result.state,"trace":trace,"cost":current.cost+result.trace.size()*1.3,"key":index})
	print("Search exhausted: ",visited.keys()," allowed ",allowed)
	for key in visited:
		if key>=0: print("  visited ",surfaces[key])
	return {}

func transfer(start: MovementState,target: Rect2,cells: int,dash: bool,boots: bool) -> Dictionary:
	calls+=1
	var target_x := target.get_center().x
	var leads := [_prepare(start,target,0),_prepare(start,target,1),_prepare(start,target,-1),_prepare(start,target,2)]
	# Approach a ledge's nearer edge; waiting until above a high ledge prevents
	# the solver from head-butting its underside and declaring a false failure.
	for style in range(7 if boots and start.position.y-target.position.y>100 else 2):
		var lead: Dictionary = leads[3 if style==6 else (1 if style in [2,4] else (2 if style in [3,5] else 0))]
		if lead.is_empty(): continue
		var launch: MovementState = lead.state
		var prefix: Array = lead.trace
		for shot in (([-1,1,6,10,16,22,28,34,40] if start.position.y-target.position.y>100 else [-1,6,18,30]) if cells>0 else [-1]):
			for dash_frame in ([-1,8,22] if dash else [-1]):
				var s := launch.clone()
				s.wall_jump_enabled=boots
				s.dash_available=dash
				s.wall_kick_available=true
				var ammo := cells
				var trace: Array = prefix.duplicate()
				for frame in range(125):
					var dx := target_x-s.position.x
					if style==1 and s.position.y+8>target.position.y and target.position.y<start.position.y-40: dx=0
					if style in [2,4,6] and s.wall_kick_available: dx=100
					if style in [4,5] and not s.wall_kick_available and s.position.y+8>target.position.y: dx=0
					if style in [3,5] and s.wall_kick_available: dx=-100
					s.move_left=dx < -3
					s.move_right=dx > 3
					s.jump_pressed=frame==0 and target.position.y<start.position.y+65
					if boots and frame>0 and s.wall_kick_available and (s.on_wall_left or s.on_wall_right) and s.velocity.y>-1:
						s.jump_pressed=true
						s.move_left=s.on_wall_right
						s.move_right=s.on_wall_left
					s.dash_pressed=frame==dash_frame
					var from := s.position
					var input := {"left":s.move_left,"right":s.move_right,"jump":s.jump_pressed,"dash":s.dash_pressed,"shot":false}
					PlayerMovement.process(s,world.player.config,world.tiles)
					var blocked := false
					for gate: Dictionary in world.gates:
						if not world.locks.get(gate.lock,false) and GateCollision.swept_touches(from,s.position,gate.rect,world.player.config.collider_size): blocked=true
					if blocked: break
					if shot>=0 and frame>=shot and (frame-shot)%12==0 and ammo>0 and not s.on_floor:
						Player.apply_recoil(s,Vector2.DOWN)
						ammo-=1
						input.shot=true
					input["p"]=[s.position.x,s.position.y]
					trace.append(input)
					if s.on_floor and absf(s.position.y+8-target.position.y)<1 and s.position.x>=target.position.x+3 and s.position.x<=target.end.x-3:
						return {"state":s,"trace":trace}
					if frame>0 and s.position.distance_to(from)<0.01: break
					if s.position.y>start.position.y+420: break
	return {}


func _prepare(start: MovementState,target: Rect2,side: int) -> Dictionary:
	var target_x := target.get_center().x
	var launch := start.clone()
	var prefix: Array = []
	for floor_rect: Rect2 in surfaces:
		if absf(start.position.y+8-floor_rect.position.y)<1 and start.position.x>=floor_rect.position.x and start.position.x<=floor_rect.end.x:
			var launch_x := clampf(target_x,floor_rect.position.x+10,floor_rect.end.x-10)
			if side != 0: launch_x = floor_rect.end.x-8 if side>0 else floor_rect.position.x+8
			if side==2: launch_x = floor_rect.position.x+32
			if target.position.y>floor_rect.position.y+24:
				launch_x = floor_rect.position.x-12 if absf(start.position.x-floor_rect.position.x)<absf(start.position.x-floor_rect.end.x) else floor_rect.end.x+12
			for step in range(100):
				var dx := launch_x-launch.position.x
				if absf(dx)<4: break
				launch.move_left=dx<0
				launch.move_right=dx>0
				launch.jump_pressed=false
				launch.dash_pressed=false
				var old := launch.position
				PlayerMovement.process(launch,world.player.config,world.tiles)
				for gate: Dictionary in world.gates:
					if not world.locks.get(gate.lock,false) and GateCollision.swept_touches(old,launch.position,gate.rect,world.player.config.collider_size): return {}
				prefix.append({"left":launch.move_left,"right":launch.move_right,"jump":false,"dash":false,"shot":false,"p":[launch.position.x,launch.position.y]})
				if not launch.on_floor or launch.position.distance_to(old)<0.01: break
			break
	return {"state":launch,"trace":prefix}
