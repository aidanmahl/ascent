extends Node2D
var world: Node2D
const MINT := Color("8ee4c3")

func _draw() -> void:
	var top: float = world.camera.position.y-200
	var bottom: float = world.camera.position.y+200
	for gate: Dictionary in world.gates:
		var r: Rect2 = gate.rect
		if r.end.y < top or r.position.y > bottom:
			continue
		if gate.kind == "seal" and world.locks.get(gate.lock,false):
			continue
		var c := Color("83cbea") if gate.kind == "phase" else Color("d18d91")
		draw_rect(r,Color(c,0.18))
		for x in range(int(r.position.x),int(r.end.x),8):
			var y := r.position.y+8+sin(world.time*4+x)*3
			draw_line(Vector2(x,r.position.y),Vector2(x+4,y),c,1)
			draw_line(Vector2(x+4,y),Vector2(x,r.end.y),c,1)
		draw_line(r.position,r.position+Vector2(r.size.x,0),c,2)
	for hazard: Dictionary in world.hazards:
		var r: Rect2 = hazard.rect
		if r.end.y < top or r.position.y > bottom:
			continue
		if hazard.kind == "spikes":
			for x in range(int(r.position.x),int(r.end.x),8):
				draw_colored_polygon(PackedVector2Array([Vector2(x,r.end.y),Vector2(x+4,r.position.y),Vector2(x+8,r.end.y)]),Color("e69b91"))
				draw_line(Vector2(x+4,r.position.y),Vector2(x+8,r.end.y),Color("905d72"),1)
		else:
			var t := fposmod(world.combat_time+hazard.phase,3.8)
			draw_rect(Rect2(r.position.x-3,r.end.y-4,r.size.x+6,5),Color("634d57"))
			if t > 2.15:
				for i in range(4):
					draw_rect(Rect2(r.position.x+3*i,r.end.y-8-(i%2)*4,2,4),Color("edb278"))
			if t > 2.8:
				draw_rect(r,Color(0.92,0.45,0.37,0.22))
				for i in range(6):
					var y := r.end.y-fposmod(world.time*170+i*13,r.size.y)
					draw_rect(Rect2(r.position.x+3+i%3*4,y,4,13),Color("eea479"))
	for item: Dictionary in world.pickups:
		if item.taken or item.p.y < top or item.p.y > bottom:
			continue
		var p: Vector2 = item.p+Vector2(0,sin(world.time*2.5)*2)
		var locked: bool = not item.lock.is_empty() and not world.locks.get(item.lock,false)
		draw_rect(Rect2(p+Vector2(-14,10),Vector2(28,4)),Color("3c555b"))
		draw_circle(p,20,Color(0.4,0.9,0.75,0.055))
		match item.kind:
			"gun":
				draw_rect(Rect2(p+Vector2(-10,-5),Vector2(22,7)),Color("9eb9b5"))
				draw_rect(Rect2(p+Vector2(-6,1),Vector2(5,7)),Color("687989"))
				draw_rect(Rect2(p+Vector2(10,-4),Vector2(5,5)),Color("49586a"))
				draw_rect(Rect2(p+Vector2(-5,-4),Vector2(4,3)),MINT)
			"ammo2","ammo3":
				var count := 2 if item.kind == "ammo2" else 3
				draw_rect(Rect2(p+Vector2(-12,-7),Vector2(24,17)),Color("475b6b"))
				for i in range(count):
					draw_rect(Rect2(p+Vector2(-9+i*7,-5),Vector2(5,13)),Color("d3a865"))
					draw_rect(Rect2(p+Vector2(-8+i*7,-6),Vector2(3,3)),Color("fff0b5"))
			"boots":
				for i in range(2):
					draw_rect(Rect2(p+Vector2(-11+i*13,-7),Vector2(7,13)),Color("c6bec6"))
					draw_rect(Rect2(p+Vector2(-11+i*13,3),Vector2(11,5)),Color("a280ac"))
					draw_rect(Rect2(p+Vector2(-10+i*13,7),Vector2(9,2)),Color("e2c2d8"))
			"dash":
				draw_rect(Rect2(p+Vector2(-6,-9),Vector2(12,19)),Color("9ebdb8"))
				for side in [-1,1]:
					draw_rect(Rect2(p+Vector2(side*8-3,-6),Vector2(6,14)),Color("568e9e"))
					draw_rect(Rect2(p+Vector2(side*8-2,-4),Vector2(4,8)),MINT)
		if locked:
			draw_rect(Rect2(p-Vector2(17,14),Vector2(34,29)),Color(0.32,0.5,0.58,0.17))
			draw_rect(Rect2(p-Vector2(17,14),Vector2(34,29)),Color("869eac"),false,1)
			for x in [-11,0,11]:
				draw_line(p+Vector2(x,-13),p+Vector2(x,14),Color("6b7b8c"),1)
		var label: String = item.label
		draw_string(ThemeDB.fallback_font,p+Vector2(-label.length()*2.05,25),label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,MINT)
	for relay: Dictionary in world.switches:
		var p: Vector2 = relay.p
		draw_rect(Rect2(p-Vector2(7,7),Vector2(14,14)),Color("3b4e61"))
		draw_circle(p,4,MINT if relay.lit else Color("cb967f"))
		if relay.lit:
			draw_arc(p,10,-PI/2,-PI/2+TAU*relay.timer/5,16,MINT,1)
	var core: Vector2 = world.capacitor.p
	if core.y > top and core.y < bottom:
		draw_circle(core,15,Color("3e5565"))
		for i in range(3):
			draw_rect(Rect2(core+Vector2(-9+i*7,-6),Vector2(5,12)),MINT if world.locks.get("airlock",false) or i < world.capacitor.hits else Color("cc9779"))
	for sign in world.signs:
		var p: Vector2 = sign[0]
		if p.y > top and p.y < bottom:
			draw_string(ThemeDB.fallback_font,p,sign[1],HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("acc6b7"))
