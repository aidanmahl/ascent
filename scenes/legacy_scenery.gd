extends Node2D

var world: Node2D
var stars: Array[Vector3] = []
var decorations: Array[Dictionary] = []
var rock_shapes: Array[PackedVector2Array] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 4207
	for i in range(260):
		stars.append(Vector3(rng.randf_range(25,615),rng.randf_range(-4300,550),rng.randf_range(1,3)))
	for coord: Vector2i in world.tiles:
		if not world.tiles.has(coord + Vector2i.UP) and coord.x > 1 and coord.x < 38:
			decorations.append({"p": Vector2(coord * 16), "kind": rng.randi_range(0,7), "n": rng.randi_range(3,9)})
	for i in range(130):
		var x := rng.randf_range(0,640)
		var y := rng.randf_range(-4300,500)
		var w := rng.randf_range(25,100)
		var h := rng.randf_range(45,150)
		rock_shapes.append(PackedVector2Array([Vector2(x,y),Vector2(x+w*0.2,y-h*0.8),Vector2(x+w*0.65,y-h),Vector2(x+w,y-h*0.3),Vector2(x+w,y+30)]))

func _draw() -> void:
	var cy: float = world.camera.position.y if world.camera else 324.0
	var top := cy - 190
	var bottom := cy + 190
	# Stepped palette transitions from ink-blue caves to pale morning sky.
	for y in range(int(top/16)*16-16,int(bottom)+32,16):
		var daylight := clampf((-float(y)-2400)/1750,0,1)
		var c := Color("101e2c").lerp(Color("7aa5ac"),daylight)
		draw_rect(Rect2(world.camera.position.x-330,y,660,16),c)
	# Distant walls move more slowly than the foreground.
	for shape in rock_shapes:
		var shifted := PackedVector2Array()
		for p in shape:
			shifted.append(Vector2(p.x,(p.y-cy)*0.75+cy))
		if shifted[0].y > top-40 and shifted[2].y < bottom+130:
			draw_colored_polygon(shifted,Color("203443") if cy > -2700 else Color("557e8b"))
	if cy < -2700:
		_draw_surface(cy)
	for star in stars:
		var y := (star.y-cy)*0.9+cy
		if y > top and y < bottom:
			var alpha := 0.18 + (sin(world.time * 1.5 + star.x) + 1) * 0.15
			draw_rect(Rect2(star.x,y,1,star.z),Color(0.45,0.9,0.82,alpha))
	# A waterfall behind the route gives scale without hiding collision.
	for x in [110,115,119]:
		draw_rect(Rect2(x,-1040,2,1150),Color(0.29,0.63,0.67,0.13))
		for i in range(24):
			var y := -1040 + fmod(i*49 + world.time*65,1150)
			if y > top and y < bottom:
				draw_rect(Rect2(x,y,1,12),Color(0.54,0.86,0.8,0.24))
	for coord: Vector2i in world.tiles:
		var p := Vector2(coord * 16)
		if p.y < top-32 or p.y > bottom+16:
			continue
		var n := posmod(coord.x * 71 + coord.y * 31, 7)
		var is_top: bool = not world.tiles.has(coord+Vector2i.UP)
		var surface := coord.y < -165
		var base := Color("34404e") if not surface else Color("48565a")
		base = base.lightened(n * 0.012)
		draw_rect(Rect2(p,Vector2(16,16)),base)
		draw_rect(Rect2(p+Vector2(1,2),Vector2(14,1)),Color("4b5260") if not surface else Color("647065"))
		draw_rect(Rect2(p+Vector2(2+n,6),Vector2(6,2)),base.lightened(0.055))
		draw_rect(Rect2(p+Vector2(10-n,12),Vector2(4,2)),base.darkened(0.18))
		if n % 3 == 0:
			draw_line(p+Vector2(3,3),p+Vector2(5,9),base.darkened(0.3),1)
		if is_top:
			draw_rect(Rect2(p,Vector2(16,3)),Color("77a57a") if surface else Color("578d83"))
			draw_rect(Rect2(p+Vector2(1,0),Vector2(13,1)),Color("b4c98c") if surface else Color("8cbaa0"))
			draw_rect(Rect2(p+Vector2(n+2,3),Vector2(3,3+n)),Color("496f63"))
		if not world.tiles.has(coord+Vector2i.DOWN):
			draw_rect(Rect2(p+Vector2(0,14),Vector2(16,2)),Color("202d3a"))
			if n < 3:
				draw_colored_polygon(PackedVector2Array([p+Vector2(2,16),p+Vector2(8,16),p+Vector2(5,24+n*3)]),base.darkened(0.1))
	for decor in decorations:
		var p: Vector2 = decor.p
		if p.y < top-30 or p.y > bottom+30:
			continue
		if decor.kind < 3:
			_draw_grass(p,decor.n)
		elif decor.kind < 5 and p.y > -2600:
			_draw_mushroom(p+Vector2(8,0),decor.n)
		elif decor.kind == 5:
			_draw_crystal(p+Vector2(7,0),decor.n)
		elif decor.kind == 6:
			_draw_vine(p+Vector2(14,16),decor.n)
	# Hanging roots and stone teeth frame the crash chamber.
	if bottom > 180:
		for i in range(12):
			var x := float(i*57)
			var y := 192.0 + sin(i*4.0)*13
			draw_colored_polygon(PackedVector2Array([Vector2(x,y-80),Vector2(x+43,y-80),Vector2(x+25,y+float(i%3)*16)]),Color("172c39"))
		_draw_ship()
		# The wreck is readable without a caption.

	# Upper-canopy foliage, distant rain and hanging fronds.
	if cy < -2200:
		for i in range(20):
			var x := float(posmod(i*137,640))
			var y := top+fposmod(world.time*85+i*47,390)
			draw_line(Vector2(x,y),Vector2(x-3,y+9),Color(0.7,0.88,0.8,0.16),1)
	for decor in decorations:
		var p: Vector2 = decor.p
		if p.y > top and p.y < bottom and int(decor.kind) == 7:
			for i in range(5):
				var stem := p+Vector2(8,-i*4)
				draw_line(p+Vector2(8,0),stem,Color("668f7b"),1)
				draw_line(stem,stem+Vector2(-10+i,-5),Color("659e7c"),2)
				draw_line(stem,stem+Vector2(10-i,-5),Color("83b18c"),2)
	# Small environmental route arrows, pointing toward the next ledge.
	for index in range(world.platforms.size()-1):
		var r: Rect2 = world.platforms[index]
		if r.position.y < top or r.position.y > bottom:
			continue
		var next: Rect2 = world.platforms[index+1]
		var dir := signf(next.get_center().x-r.get_center().x)
		var p := Vector2(r.get_center().x,r.position.y+12)
		draw_line(p+Vector2(-dir*3,3),p+Vector2(dir*3,-3),Color("9aae85"),1)
		draw_line(p+Vector2(dir*3,-3),p+Vector2(-dir*2,-3),Color("9aae85"),1)

func _draw_grass(p: Vector2, n: int) -> void:
	for i in range(4):
		var x := 2.0+i*4
		var h := 3.0+posmod(n+i*7,8)
		var sway := roundf(sin(world.time*1.8+p.x+i)*1.3)
		draw_line(p+Vector2(x,0),p+Vector2(x+sway,-h),Color("63997c"),1)
		draw_line(p+Vector2(x,-2),p+Vector2(x-3,-h+2),Color("91b18a"),1)

func _draw_mushroom(p: Vector2, n: int) -> void:
	var h := float(n+3)
	draw_rect(Rect2(p+Vector2(-1,-h),Vector2(2,h)),Color("8ab3aa"))
	draw_rect(Rect2(p+Vector2(-5,-h),Vector2(10,3)),Color("3d7279"))
	draw_rect(Rect2(p+Vector2(-3,-h-3),Vector2(6,3)),Color("79d6ba"))
	draw_rect(Rect2(p+Vector2(-2,-h-3),Vector2(2,1)),Color("c6f0cd"))
	draw_circle(p+Vector2(0,-h),12,Color(0.3,0.95,0.74,0.035))

func _draw_crystal(p: Vector2, n: int) -> void:
	var h := float(7+n)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-3,0),p+Vector2(-4,-h+4),p+Vector2(0,-h),p+Vector2(4,-h+5),p+Vector2(3,0)]),Color("527f9c"))
	draw_line(p+Vector2(0,-h+2),p+Vector2(0,-2),Color("92c5c5"),2)

func _draw_vine(p: Vector2, n: int) -> void:
	for i in range(n*3):
		var x := roundf(sin(float(i)*0.35+p.x)*3)
		draw_rect(Rect2(p+Vector2(x,i*3),Vector2(1,3)),Color("365f59"))
		if i%3==0:
			draw_rect(Rect2(p+Vector2(x-3 if i%2==0 else x,i*3),Vector2(4,2)),Color("4f8170"))

func _draw_ship() -> void:
	var p := Vector2(104,463)
	draw_ellipse_shadow(p+Vector2(0,12),63)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-57,0),p+Vector2(-36,-22),p+Vector2(16,-20),p+Vector2(54,2),p+Vector2(32,15),p+Vector2(-42,14)]),Color("3c4d60"))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-51,-1),p+Vector2(-31,-25),p+Vector2(8,-24),p+Vector2(40,-2),p+Vector2(28,6),p+Vector2(-40,5)]),Color("a0afb0"))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-22,-22),p+Vector2(4,-21),p+Vector2(25,-7),p+Vector2(-27,-7)]),Color("304e60"))
	draw_line(p+Vector2(-20,-19),p+Vector2(2,-18),Color("79b2bc"),2)
	draw_line(p+Vector2(-4,-22),p+Vector2(-12,-8),Color("a0afb0"),2)
	draw_rect(Rect2(p+Vector2(-45,5),Vector2(70,4)),Color("c87959"))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-39,5),p+Vector2(-57,15),p+Vector2(-68,14),p+Vector2(-51,-5)]),Color("71888e"))
	draw_rect(Rect2(p+Vector2(34,-3),Vector2(17,10)),Color("283642"))
	for i in range(4):
		draw_rect(Rect2(p+Vector2(35+i*4,-1),Vector2(2,6)),Color("edb475"))
	for i in range(7):
		var t := fmod(world.time*13+i*8,52)
		draw_rect(Rect2(p+Vector2(43+sin(i*3.0+t*0.09)*6,-8-t),Vector2(5+t/5,4+t/6)),Color(0.45,0.56,0.58,(1-t/52)*0.14))
	for i in range(8):
		draw_rect(Rect2(155+i*7,476-(i%3)*2,4,2),Color("7a8890"))

func draw_ellipse_shadow(p: Vector2, width: float) -> void:
	draw_rect(Rect2(p-Vector2(width,0),Vector2(width*2,4)),Color("152b32"))

func _draw_surface(cy: float) -> void:
	var sun := Vector2(495,cy-110)
	draw_circle(sun,33,Color("c7d3b3"))
	draw_circle(sun,25,Color("eee2b4"))
	for layer in range(3):
		var pts := PackedVector2Array([Vector2(0,cy+220)])
		for i in range(12):
			pts.append(Vector2(i*64,cy+10+layer*48+sin(i*2.3+layer)*45))
		pts.append(Vector2(704,cy+220))
		draw_colored_polygon(pts,[Color("689196"),Color("4c7680"),Color("345967")][layer])
	for i in range(9):
		var x := float(i*83+17)
		var y := cy+110+sin(i*2.4)*27
		draw_rect(Rect2(x,y-54,3,100),Color("30515e"))
		for j in range(3):
			draw_colored_polygon(PackedVector2Array([Vector2(x+1,y-73+j*19),Vector2(x-18-j*4,y-29+j*19),Vector2(x+20+j*4,y-29+j*19)]),Color("30515e"))

func _world_text(p: Vector2, text: String, color: Color, size: int) -> void:
	draw_string(ThemeDB.fallback_font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
