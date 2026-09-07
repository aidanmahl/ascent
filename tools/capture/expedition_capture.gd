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
	world.player.jump_unlocked = true
	world.player.dash_unlocked = true
	for entry in [["cave",Vector2(243,423)],["grotto",Vector2(400,-73)],["surface",Vector2(340,-1225)]]:
		world.player.position = entry[1]
		world.camera.position = Vector2(320,entry[1].y-48)
		for i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/screenshots/"+entry[0]+".png")
	quit()
