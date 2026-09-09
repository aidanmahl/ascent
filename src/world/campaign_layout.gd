class_name CampaignLayout
extends RefCounted

const CELL := Vector2(640,480)
const START := Vector2(112,1848)
const NAMES := ["Moss Roost","Wind Harp","Crown Nest","Launch Bough","Beacon","Bell Cavern","Sail Garden","Heartwood","Stormwalk","Sentinel Observatory","Archive Roots","Fern Court","Hollow Tree","Mirror Lake","Spillway","Wreck Orchard","Root Market","Root Loom","Pumpworks","Glass Run","Boot Nest","Underroot","Rootheart Basin","Sluice Engine","Cistern Lanterns"]
# [a,b,axis,opening center,requirement]. Geometry and map share this ledger.
const LINKS := [
	[16,17,"EW",352,""],[16,11,"NS",480,"boots"],[17,12,"NS",192,""],
	[17,18,"EW",304,""],[17,22,"NS",448,""],[22,21,"EW",352,""],
	[22,23,"EW",224,"boots"],[18,23,"NS",192,"boots"],[18,19,"EW",336,""],
	[18,13,"NS",352,"boots"],[19,24,"NS",224,""],[19,20,"EW",192,"dash"],
	[19,14,"NS",448,"pump"],[23,24,"EW",352,"reservoir"],[24,25,"EW",352,""],
	[25,20,"NS",448,"dash"],[12,11,"EW",320,""],[12,13,"EW",352,""],
	[11,6,"NS",192,"boots"],[12,7,"NS",448,"garden"],[6,7,"EW",304,"boots"],
	[6,1,"NS",192,"dash"],[7,2,"NS",448,"dash"],[13,8,"NS",192,"cells"],
	[13,14,"EW",352,"dash"],[14,9,"NS",192,"dash"],[14,15,"EW",224,"dash"],
	[15,10,"NS",448,"boots"],[15,20,"NS",192,"spillway"],[10,9,"EW",304,"sentinel"],
	[9,8,"EW",352,""],[9,4,"NS",448,"wind"],[8,3,"NS",192,"wind"],
	[1,2,"EW",304,"dash"],[2,3,"EW",352,"wind"],[3,4,"EW",304,"wind"],
	[4,5,"EW",304,"crown"]]
# Authored interior spines: floor locations, not teleport anchors. Each room has
# a distinct contour; port approaches join these walkable routes.
const SPINES := [
	[[128,384],[256,352],[368,304],[480,256]],
	[[112,352],[240,304],[352,352],[496,304]],
	[[112,352],[256,352],[384,352],[528,352]],
	[[112,352],[256,384],[400,352],[528,352]],
	[[112,352],[256,320],[384,288],[512,288]],
	[[112,400],[208,336],[320,272],[432,304],[528,352]],
	[[112,352],[240,352],[352,320],[496,352]],
	[[112,400],[256,368],[368,304],[496,352]],
	[[112,400],[240,400],[368,400],[528,352]],
	[[112,352],[240,352],[384,352],[528,352]],
	[[112,368],[240,368],[368,336],[496,368]],
	[[112,400],[240,368],[352,400],[496,400]],
	[[112,400],[240,400],[352,368],[496,400]],
	[[112,400],[240,368],[368,400],[496,320]],
	[[112,400],[224,336],[352,272],[496,320]],
	[[112,416],[224,400],[352,368],[496,400]],
	[[112,400],[240,368],[368,352],[496,352]],
	[[112,352],[224,320],[352,352],[496,384]],
	[[112,384],[224,416],[368,384],[496,320]],
	[[112,256],[240,320],[368,384],[496,320]],
	[[112,400],[224,368],[352,352],[496,400]],
	[[112,400],[224,368],[352,320],[496,272]],
	[[112,400],[240,400],[384,400],[528,400]],
	[[112,400],[240,400],[368,368],[496,400]],
	[[112,400],[224,368],[352,320],[496,256]]]

var rooms: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var paths: Array[Dictionary] = []
var lifts: Array[Dictionary] = []
var mechanisms: Array[Dictionary] = []
var world: Node2D

static func origin(id: int) -> Vector2:
	return Vector2((id-1)%5, (id-1)/5) * CELL

static func room_at(p: Vector2) -> int:
	if p.x < 0 or p.y < 0 or p.x >= 3200 or p.y >= 2400:
		return 0
	return floori(p.y/480)*5 + floori(p.x/640) + 1

func build(w: Node2D) -> void:
	world = w
	for id in range(1,26):
		var o := origin(id)
		rooms.append({"id":id,"name":NAMES[id-1],"bounds":Rect2(o,CELL),"origin":o})
		# Closed outer shell, opened only at authored seams below.
		solid(Rect2(o,Vector2(640,16)))
		solid(Rect2(o+Vector2(0,464),Vector2(640,16)))
		solid(Rect2(o,Vector2(16,480)))
		solid(Rect2(o+Vector2(624,0),Vector2(16,480)))
		var spine: Array = SPINES[id-1]
		for n in range(spine.size()):
			var p := Vector2(spine[n][0],spine[n][1])+o
			shelf(p,96)
			if n > 0:
				var prev := Vector2(spine[n-1][0],spine[n-1][1])+o
				stair(prev,p,id)
	for link in LINKS:
		_connect(link)
	# Open real drop shafts through the upper room's terraces. A shared
	# boundary alone is insufficient when a continuous shelf roofs the exit.
	for edge: Dictionary in edges:
		if edge.axis == "NS":
			var half_width := 64 if edge.requires in ["pump","wind"] else 48
			clear(Rect2(origin(edge.a)+Vector2(edge.offset-half_width,320),Vector2(half_width*2,160)))
			if edge.requires.is_empty():
				shelf(origin(edge.a)+Vector2(edge.offset-64,448),64)
	_natural_gates()
	# Wind shafts contain lifts, not a hidden staircase around the core gate.
	for lift: Dictionary in lifts:
		if lift.flag == "wind":
			clear(Rect2(Vector2(lift.x-80,lift.bottom-384),Vector2(160,336)))
	for lift: Dictionary in lifts:
		shelf(Vector2(lift.x-64,lift.bottom),64)
	_landmarks_and_rewards()
	# Keep platforms as actual authored surfaces for debug/capture tools.
	world.player.kill_plane_y = 2420

func solid(rect: Rect2) -> void:
	world._fill(floori(rect.position.x/16),ceili(rect.end.x/16)-1,floori(rect.position.y/16),ceili(rect.end.y/16)-1)

func clear(rect: Rect2) -> void:
	for x in range(floori(rect.position.x/16),ceili(rect.end.x/16)):
		for y in range(floori(rect.position.y/16),ceili(rect.end.y/16)):
			world.tiles.erase(Vector2i(x,y))

func shelf(p: Vector2,width: int = 96) -> Rect2:
	var r := Rect2(Vector2(floorf((p.x-width/2.0)/16)*16,p.y),Vector2(width,16))
	solid(r)
	world.platforms.append(r)
	return r

func stair(a: Vector2,b: Vector2,id: int,stagger: bool = true) -> void:
	var steps := maxi(1,ceili(maxf(absf(a.x-b.x)/72,absf(a.y-b.y)/32)))
	var prev := a
	for n in range(1,steps+1):
		var p := a.lerp(b,float(n)/steps).snapped(Vector2(16,16))
		if stagger and absf(a.x-b.x)<48 and absf(a.y-b.y)>40 and n<steps:
			p.x = clampf(p.x+(64 if n%2==1 else -64),origin(id).x+64,origin(id).x+576)
		shelf(p,64 if absf(a.y-b.y)>64 else 96)
		paths.append({"room":id,"from":prev,"to":p,"kind":"free"})
		prev = p

func nearest(id: int,p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var distance := INF
	for point in SPINES[id-1]:
		var v := origin(id)+Vector2(point[0],point[1])
		if v.distance_squared_to(p)<distance:
			distance = v.distance_squared_to(p)
			best = v
	return best

func _connect(link: Array) -> void:
	var a: int = mini(link[0],link[1])
	var b: int = maxi(link[0],link[1])
	var offset: int = link[3]
	var requirement: String = link[4]
	var oa := origin(a)
	var ob := origin(b)
	var seam: Rect2
	var pa: Vector2
	var pb: Vector2
	if link[2] == "EW":
		seam = Rect2(oa+Vector2(624,offset-48),Vector2(32,96))
		pa = oa+Vector2(592,offset+48)
		pb = ob+Vector2(48,offset+48)
		stair(nearest(a,pa),pa,a)
		stair(pb,nearest(b,pb),b)
		shelf(pa,96)
		shelf(pb,96)
	else:
		seam = Rect2(oa+Vector2(offset-64,464),Vector2(128,32))
		# Lower room climbs beside an open shaft, with alternating resting ledges.
		pa = oa+Vector2(offset-96,432)
		pb = ob+Vector2(offset+64,48)
		stair(nearest(a,pa),pa,a)
		var foot := ob+Vector2(offset+64,384)
		stair(nearest(b,foot),foot,b)
		for y in range(384,47,-32):
			var x := offset+64 if (y/32)%2==0 else offset-16
			shelf(ob+Vector2(x,y),64)
		shelf(pb,96)
		paths.append({"room":b,"from":pb,"to":pa,"kind":"seam"})
	clear(seam)
	edges.append({"a":a,"b":b,"axis":link[2],"offset":offset,"rect":seam,"requires":requirement,"seen":false})
	if requirement in ["pump","wind","garden","spillway","crown","reservoir","sentinel"]:
		var flag := requirement
		# Mechanical grates are confined to repaired machinery / boss arena exits.
		var closed_rect := seam
		world.gates.append({"id":"%d_%d"%[a,b],"rect":closed_rect,"kind":"seal","lock":flag,"breached":false})
		if requirement in ["pump","wind"] and link[2]=="NS":
			lifts.append({"x":ob.x+offset,"top":oa.y+400,"bottom":ob.y+400,"y":ob.y+400,"last_y":ob.y+400,"flag":flag,"phase":0.0})
	if requirement == "garden":
		mechanisms.append({"p":pa+Vector2(0,-12),"flag":"garden","needs":"","label":"RETURN LADDER LOWERED"})
	if requirement == "spillway":
		mechanisms.append({"p":pa+Vector2(0,-12),"flag":"spillway","needs":"","label":"SPILLWAY COUNTERWEIGHT LOWERED"})

func pickup(id: int,kind: String,p: Vector2,lock: String = "") -> void:
	world.pickups.append({"p":origin(id)+p,"kind":kind,"lock":lock,"label":kind.to_upper(),"taken":false,"room":id})

func anchor(id: int,p: Vector2) -> void:
	world.checkpoints.append(origin(id)+p)

func _landmarks_and_rewards() -> void:
	pickup(16,"gun",Vector2(352,356))
	pickup(21,"boots",Vector2(224,356))
	pickup(7,"dash",Vector2(240,340))
	pickup(2,"ammo2",Vector2(240,292))
	pickup(10,"ammo3",Vector2(528,340),"sentinel")
	pickup(25,"fragment",Vector2(352,308))
	pickup(1,"fragment",Vector2(368,292))
	# The core is on its own recoil nest; its visual and collision use the same origin.
	shelf(origin(8)+Vector2(320,144),128)
	pickup(8,"core",Vector2(320,132))
	mechanisms.append({"p":origin(24)+Vector2(240,388),"flag":"pump","needs":"reservoir","label":"PUMP REPAIRED / THE LAKE LIFT IS RUNNING"})
	for row in [[16,112,408],[17,240,360],[12,112,392],[13,496,392],[19,112,376],[7,112,344],[8,112,392],[9,368,392],[23,112,392],[3,112,344]]:
		anchor(row[0],Vector2(row[1],row[2]))
	for row in [[17,"crawler",112,392],[18,"sentry",496,360],[20,"hunter",368,352],[6,"drifter",320,240],[14,"drifter",368,350],[15,"crawler",224,328],[22,"crawler",224,360],[20,"sentry",496,292],[9,"sentry",528,328],[11,"drifter",416,280],[18,"crawler",112,344],[24,"drifter",496,352],[1,"drifter",480,216],[2,"sentry",496,280]]:
		var id: int = row[0]
		var p := origin(id)+Vector2(row[2],row[3])
		world.add_enemy(row[1],p,"room_%d"%id,2,p.x-30,p.x+30)
		world.enemies[-1]["room"] = id
	for row in [[11,"warden",18],[23,"reservoir",28],[10,"sentinel",24],[3,"crown",36]]:
		var id: int = row[0]
		world.add_enemy("boss",origin(id)+Vector2(352,280),row[1],row[2])
		world.enemies[-1]["room"] = id

func _natural_gates() -> void:
	# Western boots gate: an open jump well, with a useful kick wall but no
	# intermediate landing. One cell alone cannot reach its upper perch.
	for edge: Dictionary in edges:
		if edge.axis != "NS":
			continue
		var id: int = edge.b
		var o := origin(id)
		var x: float = edge.offset
		if edge.requires in ["boots","cells"]:
			clear(Rect2(o+Vector2(16,16),Vector2(608,208)))
			var rise := 144 if edge.requires=="cells" else 128
			var base := o+Vector2(x,224)
			shelf(base,128)
			stair(nearest(id,base),base,id,false)
			var top := o+Vector2(x-64,224-rise)
			shelf(top,96)
			if edge.requires=="boots":
				solid(Rect2(o+Vector2(x+48,112),Vector2(16,128)))
			stair(top,o+Vector2(x-64,32),id,false)
			paths.append({"room":id,"from":base,"to":top,"kind":edge.requires})
		elif edge.requires=="dash":
			# A suspended upper gallery crosses a 224px opening. Its far pier
			# has no low footholds: jumping up from below cannot bypass it.
			clear(Rect2(o+Vector2(16,16),Vector2(608,272)))
			var target_right := x>320
			var approach_x := 128.0 if target_right else 512.0
			var target_x := 480.0 if target_right else 160.0
			var a := o+Vector2(approach_x,96)
			var b := o+Vector2(target_x,96)
			stair(nearest(id,o+Vector2(approach_x,400)),o+Vector2(approach_x,400),id)
			# Return ledges hug the approach wall, never span the long gap.
			for y in range(400,95,-32):
				var shift := -32 if (y/32)%2==0 else 32
				shelf(o+Vector2(approach_x+shift,y),64)
			shelf(a,128)
			solid(Rect2(o+Vector2(target_x-48,96),Vector2(96,272)))
			stair(b,o+Vector2(x,32),id,false)
			paths.append({"room":id,"from":a,"to":b,"kind":"dash"})
	# Bell's lower route winds under the bell and up its eastern rim. Keep
	# these broad terraces clear of the upper gallery's approach supports.
	var bell_o := origin(6)
	clear(Rect2(bell_o+Vector2(400,288),Vector2(224,176)))
	for p in [Vector2(448,400),Vector2(544,336),Vector2(448,288)]:
		shelf(bell_o+p,96)
	# Rootheart's west entrance is a boot transfer over a thick root wall.
	var root_o := origin(23)
	solid(Rect2(root_o+Vector2(160,272),Vector2(32,192)))
	shelf(root_o+Vector2(112,400),96)
	paths.append({"room":23,"from":root_o+Vector2(112,400),"to":root_o+Vector2(176,272),"kind":"boots"})
	# Eastern aqueduct: the only right exit is high on the detached pier.
	# Replace its previous staircase, preserving the dry route to the pump.
	var o := origin(19)
	clear(Rect2(o+Vector2(352,16),Vector2(272,384)))
	solid(Rect2(o+Vector2(576,240),Vector2(48,208)))
	var approach := o+Vector2(320,240)
	stair(o+Vector2(224,416),approach,19)
	shelf(approach,128)
	paths.append({"room":19,"from":approach,"to":o+Vector2(600,240),"kind":"dash"})
