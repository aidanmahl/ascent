extends SceneTree
func _initialize() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 40
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void: quit(1))
	root.add_child(watchdog)
	watchdog.autostart = true
	call_deferred("run")
func run() -> void:
	var w = load("res://scenes/main.tscn").instantiate()
	root.add_child(w)
	w.muted = true
	w.set_physics_process(false)
	w.player.set_physics_process(false)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://tools/screenshots/campaign")
	for id in range(1,26):
		w.started = true
		var spine: Array = CampaignLayout.SPINES[id-1]
		w.player.position = CampaignLayout.origin(id)+Vector2(spine[1][0],spine[1][1]-8)
		for item: Dictionary in w.pickups:
			if item.room == id:
				w.player.position = item.p+Vector2(0,4)
				break
		w.player.state.position = w.player.position
		w.player.invincible = 0
		w.rooms.update_membership()
		w.camera.position = w.rooms.camera_target()
		w.player.queue_redraw()
		w.scenery.queue_redraw()
		w.hud.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/screenshots/campaign/room_%02d.png"%id)
	for id in [1,25]:
		var item: Dictionary={}
		for candidate: Dictionary in w.pickups:
			if candidate.room==id and candidate.kind=="fragment": item=candidate
		for phase in ["before","collected","retry"]:
			w.player.position=item.p+Vector2(-32,4) if phase=="before" else item.p+Vector2(0,4)
			w.player.state.position=w.player.position
			if phase=="collected": w._update_pickups()
			if phase=="retry": w.player.respawn()
			w.player.invincible=0
			w.rooms.update_membership()
			w.camera.position=w.rooms.camera_target()
			w.player.queue_redraw()
			w.scenery.queue_redraw()
			w.hud.queue_redraw()
			for child in w.get_children():
				if child is CanvasItem: child.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tools/screenshots/campaign/fragment_%d_%s.png"%[id,phase])
	w.paused = true
	w.map_open = true
	for id in range(1,26): w.rooms.discovered[id] = true
	for edge in w.campaign.edges: edge.seen = true
	w.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/screenshots/campaign/map.png")
	quit(0)
