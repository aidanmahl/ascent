extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://tools/screenshots")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/screenshots/title.png")
	world.started = true
	world.player.active = false
	world.player.gun_unlocked = true
	world.player.wall_unlocked = true
	world.player.max_ammo = 3
	world.player.ammo = 3
	world.player.dash_unlocked = true
	for entry in [["cave",Vector2(448,232)],["warden",Vector2(450,-216)],["relays",Vector2(112,-920)],["membrane",Vector2(425,-1544)],["core",Vector2(312,-2168)],["surface",Vector2(480,-3416)],["crown",Vector2(344,-3896)]]:
		world.player.position = entry[1]
		world.player.previous_position = entry[1]
		world.player.queue_redraw()
		world.camera.position = Vector2(320,entry[1].y-48)
		for i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/screenshots/"+entry[0]+".png")
	quit()
