extends Node2D
## Original vector/pixel scenery. Geometry is authoritative; every exposed tile
## gets a bright lip while background forms stay low-contrast behind the player.
var world: Node2D
const PALETTES := [
	["142a36","284a52","5f9991","a4d7ad"], # canopy
	["102934","214951","487f7c","b7d6a0"], # high garden
	["102733","1c4147","3e716b","90c5a0"], # lake/court
	["101f2c","23333f","45645f","82bbaa"], # wreck
	["121e2b","2b3546","52666f","a6cbb5"]] # roots

func _draw() -> void:
	if not world.camera or not world.campaign:
		return
	var view := Rect2(world.camera.position-Vector2(352,212),Vector2(704,424))
	draw_rect(view,Color("102431"))
	for room: Dictionary in world.campaign.rooms:
		if not room.bounds.intersects(view):
			continue
		_room(room)
	# All backgrounds precede all terrain so neighboring illustrations cannot
	# accidentally paint over a seam's walkable surface.
	for cell: Vector2i in world.tiles:
		var p := Vector2(cell*16)
		if not view.grow(24).has_point(p):
			continue
		var row := clampi(cell.y/30,0,4)
		var pal: Array = PALETTES[row]
		var n := posmod(cell.x*71+cell.y*31,9)
		var base := Color(pal[1]).lightened(float(n)*0.009)
		draw_rect(Rect2(p,Vector2(16,16)),base)
		draw_line(p+Vector2(1,12),p+Vector2(14,12-n%3),base.darkened(0.17),1)
		if not world.tiles.has(cell+Vector2i.UP):
			draw_rect(Rect2(p,Vector2(16,3)),Color(pal[2]))
			draw_line(p,p+Vector2(16,0),Color(pal[3]),1)
			if n<5:
				_fern(p+Vector2(8,0),5+n,Color(pal[2]))
			if n==7:
				draw_line(p+Vector2(6,0),p+Vector2(6,-8),Color(pal[3]),1)
				draw_circle(p+Vector2(6,-9),3,Color("ddd9a2"))
		if not world.tiles.has(cell+Vector2i.DOWN):
			draw_line(p+Vector2(0,15),p+Vector2(16,15),Color("0b202a"),2)
			if n<3:
				var vine := PackedVector2Array([p+Vector2(9,16),p+Vector2(7,24),p+Vector2(11,31+n*3)])
				draw_polyline(vine,Color(pal[2]).darkened(0.25),1)
	# Drifting seed lights are faint and never obscure collision.
	for n in range(40):
		var x := view.position.x+fposmod(n*83.7+sin(world.time*0.4+n)*18,704)
		var y := view.position.y+fposmod(n*41.3-world.time*6,424)
		var alpha := 0.15+(sin(world.time+n)+1)*0.1
		draw_circle(Vector2(x,y),1,Color(0.7,0.95,0.75,alpha))

func _room(room: Dictionary) -> void:
	var id: int = room.id
	var o: Vector2 = room.origin
	var row := (id-1)/5
	var pal: Array = PALETTES[row]
	draw_rect(room.bounds,Color(pal[0]))
	# Layered fern and root silhouettes, varied deterministically per chamber.
	for i in range(6):
		var x := o.x+40+posmod(i*113+id*37,560)
		var points := PackedVector2Array([Vector2(x-32,o.y+480),Vector2(x-12,o.y+330),Vector2(x+18,o.y+220),Vector2(x+22,o.y+72),Vector2(x+48,o.y),Vector2(x+64,o.y),Vector2(x+40,o.y+240),Vector2(x+9,o.y+360),Vector2(x+7,o.y+480)])
		draw_colored_polygon(points,Color(pal[1]).darkened(0.42))
		if row<3:
			_leaf(Vector2(x+26,o.y+110),Vector2(-70,-38),Color(pal[1]).darkened(0.18))
			_leaf(Vector2(x+30,o.y+188),Vector2(86,-33),Color(pal[1]).darkened(0.1))
	match id:
		16: _ship(o+Vector2(265,322))
		6:
			var center := o+Vector2(330,222)
			draw_line(o+Vector2(320,16),center-Vector2(0,130),Color("627b76"),5)
			var bell := PackedVector2Array([center+Vector2(-92,66),center+Vector2(-64,20),center+Vector2(-51,-84),center+Vector2(-22,-112),center+Vector2(25,-108),center+Vector2(58,-74),center+Vector2(62,17),center+Vector2(104,62),center+Vector2(12,82),center+Vector2(-9,43),center+Vector2(-31,76)])
			draw_colored_polygon(bell,Color("465e60"))
			draw_polyline(bell,Color("79918a"),3)
			draw_arc(center+Vector2(0,55),85,0.1,3.0,32,Color("a29d78"),3)
			draw_circle(center+Vector2(0,36),13,Color("8c9879"))
		7,2:
			for n in range(4):
				var p := o+Vector2(90+n*144,64+(n%2)*28)
				draw_line(p-Vector2(0,70),p+Vector2(5,180),Color("647f78"),2)
				if id==7:
					draw_colored_polygon(PackedVector2Array([p,p+Vector2(88,22),p+Vector2(55,147),p+Vector2(4,171)]),Color("567e78"))
					draw_line(p,p+Vector2(55,147),Color("9daf89"),2)
				else:
					draw_arc(p+Vector2(26,96),77,-PI/2,PI/2,24,Color("6d8e80"),6)
					for k in range(5):
						draw_line(p+Vector2(12+k*10,30),p+Vector2(12+k*10,150),Color("8b9972"),1)
		13,8:
			var p := o+Vector2(320,218)
			draw_arc(p,152,0,TAU,48,Color("274e4f"),54)
			draw_arc(p,146,0.4,5.5,48,Color("426a5d"),9)
			for n in range(8):
				var d := Vector2.RIGHT.rotated(float(n)*TAU/8)
				draw_line(p+d*120,p+d*180,Color("4f7965"),5)
			if id==8:
				for r in [62,43,25]:
					draw_circle(p,r,Color(0.46,0.85,0.61,0.06))
				draw_arc(p,33,world.time*0.2,world.time*0.2+5.1,36,Color("a2c695"),2)
		14,15,20:
			var y := o.y+430
			draw_rect(Rect2(o+Vector2(16,420),Vector2(608,44)),Color("244a58"))
			for n in range(15):
				var x := o.x+24+posmod(n*91,570)
				draw_line(Vector2(x,y+n%4*8),Vector2(x+20+sin(world.time+n)*8,y+n%4*8),Color("517e84"),1)
			if id==15:
				for k in range(12):
					var x := o.x+270+k*6
					draw_line(Vector2(x,o.y+20),Vector2(x-15,o.y+420),Color(0.38,0.73,0.74,0.12),3)
					draw_line(Vector2(x,o.y+fposmod(world.time*120+k*37,360)),Vector2(x-2,o.y+fposmod(world.time*120+k*37,360)+26),Color(0.66,0.87,0.84,0.28),1)
		19,24:
			_wheel(o+Vector2(340,238),112,world.locks.get("pump",false))
			for k in [0,1]:
				draw_polyline(PackedVector2Array([o+Vector2(32,90+k*34),o+Vector2(176,90+k*34),o+Vector2(176,300),o+Vector2(260,300)]),Color("3d6063"),10)
		25:
			var p := o+Vector2(336,152)
			for x in [-85,85]:
				draw_line(p+Vector2(x,-152),p+Vector2(x,-12),Color("607f7b"),3)
			draw_rect(Rect2(p-Vector2(104,34),Vector2(208,134)),Color("38555e"))
			draw_arc(p+Vector2(0,95),104,0,PI,32,Color("637d7b"),5)
			for k in range(6):
				draw_rect(Rect2(p+Vector2(-84+k*32,-20),Vector2(18,76)),Color("233f50"))
				draw_circle(p+Vector2(-75+k*32,62),3,Color("c4c994"))
		1,21:
			var p := o+Vector2(322,302)
			for k in range(9):
				draw_arc(p+Vector2(k*2,k*3),120-k*6,0.1,3.0,30,Color("597468").darkened(k*0.035),4)
			for n in range(4):
				_leaf(p+Vector2(-80+n*50,-20),Vector2(12,-86),Color("41645e"))
		11:
			for n in range(5):
				var p := o+Vector2(110+n*104,198)
				draw_rect(Rect2(p,Vector2(58,123)),Color("334955"))
				for k in range(6):
					draw_rect(Rect2(p+Vector2(7+k*8,16+k%2*8),Vector2(4,88)),Color("70867a"))
		10:
			var p := o+Vector2(366,150)
			draw_line(p+Vector2(-40,136),p+Vector2(0,50),Color("627c7b"),8)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-120,48),p+Vector2(-104,82),p+Vector2(106,-12),p+Vector2(88,-64)]),Color("486a72"))
			draw_line(p+Vector2(-120,48),p+Vector2(88,-64),Color("9baea0"),3)
			draw_arc(p+Vector2(100,-38),27,-PI/2,PI/2,20,Color("84c4bf"),4)
		3,4,5,9:
			for n in range(3):
				var p := o+Vector2(90+n*198,130+n%2*44)
				draw_arc(p,74,PI,TAU,28,Color("517c7c"),4)
				_leaf(p,Vector2(120,-54),Color("35595c"))
			if id==5:
				draw_circle(o+Vector2(490,95),43,Color("a7c4ac"))
				draw_circle(o+Vector2(476,84),40,Color(PALETTES[0][0]))
		_:
			for n in range(4):
				var p := o+Vector2(90+n*138,240+n%2*48)
				_leaf(p,Vector2(-62,-92),Color("36594f"))
				_leaf(p,Vector2(69,-55),Color("3c6657"))
	# Small atmospheric region inscription, never used as an exit button.
	draw_string(ThemeDB.fallback_font,o+Vector2(36,64),room.name.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(pal[2]))

func _leaf(p: Vector2,d: Vector2,c: Color) -> void:
	var side := d.orthogonal()*0.28
	draw_colored_polygon(PackedVector2Array([p,p+d*0.45+side,p+d,p+d*0.55-side]),c)
	draw_line(p,p+d,c.lightened(0.07),1)

func _fern(p: Vector2,h: float,c: Color) -> void:
	var tip := p+Vector2(sin(world.time*1.4+p.x)*2,-h)
	draw_line(p,tip,c,1)
	for n in range(1,4):
		var q := p.lerp(tip,float(n)/4)
		draw_line(q,q+Vector2(-5+n,-3),c,1)
		draw_line(q,q+Vector2(5-n,-3),c,1)

func _wheel(p: Vector2,r: float,moving: bool) -> void:
	draw_arc(p,r,0,TAU,48,Color("597a75"),9)
	draw_arc(p,r-14,0,TAU,48,Color("375958"),5)
	for n in range(12):
		var d := Vector2.RIGHT.rotated(n*TAU/12+world.time*(0.2 if moving else 0))
		draw_line(p+d*18,p+d*(r-8),Color("52706b"),5)
		draw_circle(p+d*r,4,Color("93a18a"))
	draw_circle(p,22,Color("729686"))
	draw_circle(p,9,Color("bfd1a5") if moving else Color("365456"))

func _ship(p: Vector2) -> void:
	var hull := PackedVector2Array([p+Vector2(-150,-12),p+Vector2(-112,-68),p+Vector2(44,-52),p+Vector2(117,2),p+Vector2(76,28),p+Vector2(-127,32)])
	draw_colored_polygon(hull,Color("647d83"))
	draw_polyline(hull,Color("a7b4a3"),3)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-43,-49),p+Vector2(33,-41),p+Vector2(74,-8),p+Vector2(-53,-8)]),Color("254b5c"))
	draw_line(p+Vector2(-43,-44),p+Vector2(30,-37),Color("90c2b8"),2)
	draw_rect(Rect2(p+Vector2(-117,-10),Vector2(57,8)),Color("c8a079"))
	for n in range(4):
		draw_line(p+Vector2(-101+n*19,12),p+Vector2(-93+n*19,22),Color("384f5b"),3)
	_leaf(p+Vector2(-145,31),Vector2(26,-78),Color("527b63"))
