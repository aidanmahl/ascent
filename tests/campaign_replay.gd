extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time=110
	watchdog.one_shot=true
	watchdog.timeout.connect(func() -> void: quit(1))
	root.add_child(watchdog)
	watchdog.start()
	var w = load("res://scenes/main.tscn").instantiate()
	root.add_child(w)
	w.muted=true
	w.set_physics_process(false)
	w.player.set_physics_process(false)
	var nav = load("res://tests/campaign_navigator.gd").new(w)
	var pos: Vector2=w.player.position
	var itinerary := [[16,Vector2(352,356),[16]],[17,Vector2(368,344),[16,17]],[22,Vector2(224,356),[17,22]],[21,Vector2(224,356),[22,21]],[17,Vector2(240,356),[21,22,17]],[12,Vector2(240,356),[17,12]],[11,Vector2(192,216),[12,11]],[6,Vector2(96,456),[11,6]],[6,Vector2(320,456),[6]],[6,Vector2(544,328),[6]],[7,Vector2(240,340),[6,7]],[7,Vector2(128,88),[7]],[7,Vector2(480,88),[7]],[2,Vector2(352,424),[7,2]],[2,Vector2(240,292),[2]],
	[7,Vector2(352,420),[2,7]],[12,Vector2(112,392),[7,12]],[13,Vector2(496,392),[12,13]],
	[8,Vector2(320,132),[13,8]],[13,Vector2(496,392),[8,13]],[18,Vector2(112,344),[13,18]],
	[23,Vector2(352,392),[18,23]],[24,Vector2(240,388),[23,24]],[19,Vector2(112,376),[24,19]],
	[19,Vector2(408,392),[19]],[14,Vector2(240,360),[14]],[14,Vector2(512,88),[14]],[14,Vector2(192,24),[14]],[9,Vector2(368,392),[14,9]],
	[8,Vector2(152,392),[9,8]],[3,Vector2(352,344),[3]],[4,Vector2(528,344),[3,4]],
	[5,Vector2(512,276),[4,5]]]
	var all_frames: Array=[]
	var start_index := 0
	if "--resume" in OS.get_cmdline_user_args():
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/campaign_resume.json"))
		start_index=int(saved.next)
		pos=Vector2(saved.pos[0],saved.pos[1])
		w.player.position=pos
		w.player.state.position=pos
		w.player.state.on_floor=true
		w.player.gun_unlocked=true
		w.player.wall_unlocked=saved.boots
		w.player.dash_unlocked=saved.dash
		w.player.max_ammo=int(saved.cells)
		w.locks=saved.locks
		for item in w.pickups:
			if item.kind in saved.taken: item.taken=true
		all_frames=JSON.parse_string(FileAccess.get_file_as_string("res://tools/campaign_route.json"))
	for index in range(start_index,itinerary.size()):
		var entry: Array=itinerary[index]
		var goal: Vector2 = CampaignLayout.origin(entry[0])+entry[1]
		var result: Dictionary=nav.navigate(pos,goal,w.player.max_ammo,w.player.dash_unlocked,w.player.wall_unlocked,entry[2])
		if result.is_empty():
			printerr("NO ROUTE to ",entry[0]," from ",pos," goal ",goal," calls ",nav.calls)
			quit(1)
			return
		pos=result.state.position
		w.player.position=pos
		w.player.state=result.state
		w._update_pickups()
		w.rooms.update_membership()
		w.rooms.update(0)
		if entry[0] in [23,3]:
			# This replay proves traversal/progression. Combat has a separate check.
			for enemy: Dictionary in w.enemies:
				if enemy.kind=="boss" and enemy.room==entry[0]:
					w.damage_enemy(enemy,enemy.max_hp,false)
					result.trace.append({"defeat":enemy.id})
			w.arenas.update(0)
		if entry[0]==19 and entry[1].x==408 or entry[0]==8 and entry[1].x==152:
			var lift: Dictionary = w.campaign.lifts[0]
			for candidate: Dictionary in w.campaign.lifts:
				if absf(candidate.x-(pos.x+40))<20 and absf(candidate.bottom-(pos.y+8))<32: lift=candidate
			lift.phase=0.0
			lift.y=lift.bottom
			for frame in range(295):
				w.player.state.move_left=false
				w.player.state.move_right=false
				w.player.state.jump_pressed=false
				w.player.state.dash_pressed=false
				w.rooms.update(1.0/60)
				PlayerMovement.process(w.player.state,w.player.config,w.tiles)
				w.player.position=w.player.state.position
			pos=w.player.position
			print("LIFT ARRIVAL ",pos)
			if CampaignLayout.room_at(pos)!=CampaignLayout.room_at(Vector2(lift.x,lift.top-8)):
				printerr("Lift did not carry player into the upper room")
				quit(1)
				return

		all_frames.append_array(result.trace)
		var partial:=FileAccess.open("res://tools/campaign_route.json",FileAccess.WRITE)
		partial.store_string(JSON.stringify(all_frames))
		partial.close()
		var taken: Array=[]
		for item in w.pickups:
			if item.taken: taken.append(item.kind)
		var save:=FileAccess.open("res://tools/campaign_resume.json",FileAccess.WRITE)
		save.store_string(JSON.stringify({"next":index+1,"pos":[pos.x,pos.y],"cells":w.player.max_ammo,"boots":w.player.wall_unlocked,"dash":w.player.dash_unlocked,"locks":w.locks,"taken":taken}))
		save.close()
		print("ROUTE ",entry[0]," frames ",result.trace.size()," cells ",w.player.max_ammo," boots ",w.player.wall_unlocked," dash ",w.player.dash_unlocked," end ",pos)
		await process_frame
		if index-start_index>=2 and index+1<itinerary.size():
			print("BATCH COMPLETE / resume at ",index+1)
			quit(2)
			return
	w.started=true
	w.player.active=false
	Input.action_press("interact")
	w._physics_process(1.0/60)
	Input.action_release("interact")
	if not w.finished:
		printerr("Beacon interaction did not finish the campaign")
		quit(1)
		return
	print("CAMPAIGN PROGRESSION REACHED BEACON / combat defeats supplied by harness")
	var file:=FileAccess.open("res://tools/campaign_route.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(all_frames))
	file.close()
	quit(0)
