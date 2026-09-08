class_name ExpeditionLevel
extends RefCounted

# Authored landings, not a generated staircase. Each row is x, y, width in
# tiles; the repeated launch ledges describe detours back to the main climb.
const ROUTE := [
	# Ordinary jump: one 32 px opener followed by 16 px rises. The shallow
	# lips and broad tops make the first lesson deliberately forgiving.
	Vector3i(6,28,5), Vector3i(12,27,5), Vector3i(18,26,5),
	Vector3i(24,25,5), Vector3i(30,24,7),
	# One-cell recoil: 80 px rises against a measured 111.3 px ceiling.
	Vector3i(18,19,6), Vector3i(9,14,6), Vector3i(18,9,6),
	Vector3i(9,4,6), Vector3i(18,-1,6), Vector3i(9,-6,6),
	Vector3i(18,-11,7),
	# Two-cell recoil: 112 px rises against a measured 174.5 px ceiling.
	Vector3i(8,-20,7), Vector3i(21,-27,7), Vector3i(8,-34,7),
	Vector3i(21,-41,7), Vector3i(8,-48,7), Vector3i(21,-55,7),
	Vector3i(8,-60,8),
	# Boot chimney: use the seal's landing, recoil up the wall, then kick
	# onto the high shelf. Short transfers follow the tall climb.
	Vector3i(18,-78,7), Vector3i(10,-80,7), Vector3i(18,-82,7),
	Vector3i(10,-84,7), Vector3i(18,-85,8),
	# Dash section: 112 px rises, below the measured 160.9 px jump-dash.
	Vector3i(8,-92,7), Vector3i(20,-99,7), Vector3i(8,-106,7),
	Vector3i(20,-113,8), Vector3i(8,-120,7), Vector3i(20,-127,8),
	# Three-cell recoil: 160 px rises against a measured 241.6 px ceiling.
	# The first 192 px rise is the strict three-cell check (67% margin use).
	Vector3i(7,-139,7), Vector3i(23,-149,7), Vector3i(7,-159,7),
	Vector3i(23,-169,7), Vector3i(7,-179,7), Vector3i(23,-189,7),
	Vector3i(7,-199,7), Vector3i(23,-209,7), Vector3i(7,-219,7),
	Vector3i(23,-229,7), Vector3i(7,-239,7), Vector3i(20,-247,9),
	Vector3i(10,-249,9)
]

static func build(w: Node2D) -> void:
	if w.layout and not w.layout.platforms.is_empty():
		build_from_layout(w)
		return
	w._fill(0,39,30,34)
	w._fill(0,1,-260,30)
	w._fill(38,39,-260,30)
	for i in ROUTE.size():
		var p: Vector3i = ROUTE[i]
		# Thin stone shelves keep the opening staircase from forming tall lips.
		# Later challenge platforms remain two tiles thick for visual weight.
		var tile_height := 1 if i < 5 else 2
		w._fill(p.x,p.x+p.z-1,p.y,p.y+tile_height-1)
		w.platforms.append(Rect2(p.x*16,p.y*16,p.z*16,tile_height*16))
	# Tall kick chimney, followed later by a kick-operated mechanical latch.
	w._fill(26,26,-80,-60)
	w._fill(28,28,-119,-113)
	w.kick_plates.append({"p":Vector2(448,-1840),"lock":"kick_latch"})
	_barrier(w,-118,14,27,"seal","kick_latch")
	_barrier(w,-14,18,25,"seal","warden")
	_barrier(w,-63,8,15,"seal","boots")
	_barrier(w,-88,18,25,"phase","")
	_barrier(w,-97,14,27,"phase","")
	_barrier(w,-111,12,25,"phase","")
	_barrier(w,-125,14,27,"phase","")
	_barrier(w,-132,17,24,"seal","reservoir")
	_barrier(w,-153,23,30,"seal","airlock")
	_barrier(w,-213,17,24,"phase","")
	_barrier(w,-183,14,27,"phase","")
	_barrier(w,-233,14,27,"phase","")
	_barrier(w,-90,18,25,"seal","sentinel")
	# The Crown chamber entrance must be below its progress seal.
	_barrier(w,-251,14,27,"seal","crown")
	w.checkpoints.assign([
		_point(w,4), _point(w,8), _point(w,11), _point(w,15),
		_point(w,18), _point(w,23), _point(w,27), _point(w,29),
		_point(w,33), _point(w,37), _point(w,40)])
	w.pickups.assign([
		_item(_point(w,4),"gun","","PULSE CUTTER / 1 CELL"),
		_item(_point(w,11),"ammo2","warden","TWIN-CELL MAGAZINE"),
		_item(_point(w,18),"boots","boots","MAGNETIC KICK BOOTS"),
		_item(_point(w,23),"dash","sentinel","VECTOR THRUSTER"),
		_item(_point(w,29),"ammo3","reservoir","TRIPLE-CELL MAGAZINE")])
	w.switches.assign([
		{"p":_point(w,17)+Vector2(-24,-26),"group":"boots","lit":false,"timer":0.0},
		{"p":_point(w,18)+Vector2(28,-42),"group":"boots","lit":false,"timer":0.0}])
	w.capacitor = {"p":_point(w,31)+Vector2(0,-45),"hits":0,"flight":-1}
	# Warm red is always dangerous. Spikes have actual tips above stone.
	# The opening runway is a safe read of the jump arc. Hazards begin after
	# the first landing so the player can learn the climb before being asked
	# to thread a jump over damage.
	# Leave the first three landings clean; the first hazard begins after the
	# player has had room to learn the normal jump arc.
	for i in [9,15,22,27,34,38]:
		var ledge: Rect2 = w.platforms[i]
		var x := ledge.position.x if i%2 == 0 else ledge.end.x-12
		w.hazards.append({"rect":Rect2(x,ledge.position.y-8,12,8),"kind":"spikes","phase":0.0})
	# Geysers telegraph before erupting. Their mouths sit on actual ledges.
	for i in [16,26,35,39]:
		var ledge: Rect2 = w.platforms[i]
		var p := Vector2(ledge.end.x-28,ledge.position.y)
		w.hazards.append({"rect":Rect2(p-Vector2(8,76),Vector2(16,76)),"kind":"vent","phase":fposmod(float(i),3.8)})
	for i in [9,14,21,27,34,38]:
		var r: Rect2 = w.platforms[i]
		w.add_enemy("crawler",Vector2(r.position.x+32,r.position.y-7),"",2,r.position.x+12,r.end.x-12)
	for i in [7,13,16,22,26,32,36,39]:
		var r: Rect2 = w.platforms[i]
		w.add_enemy("drifter",Vector2(r.position.x-26,r.position.y-32),"",1)
	w.add_enemy("boss",_point(w,11)+Vector2(0,-48),"warden",7)
	w.add_enemy("boss",_point(w,23)+Vector2(0,-48),"sentinel",10)
	w.add_enemy("boss",_point(w,29)+Vector2(0,-48),"reservoir",12)
	w.add_enemy("boss",_point(w,41)+Vector2(0,-48),"crown",16)
	w.signs = []

static func build_from_layout(w: Node2D) -> void:
	var bounds: Rect2 = w.layout.bounds
	w._fill(floori(bounds.position.x / 16.0), ceili(bounds.end.x / 16.0) - 1, floori(bounds.end.y / 16.0) - 1, ceili(bounds.end.y / 16.0) - 1)
	for rect: Rect2 in w.layout.platforms:
		w._fill(floori(rect.position.x / 16.0), ceili(rect.end.x / 16.0) - 1, floori(rect.position.y / 16.0), ceili(rect.end.y / 16.0) - 1)
		w.platforms.append(rect)
	for rect: Rect2 in w.layout.spike_strips:
		w.hazards.append({"rect": rect, "kind": "spikes", "phase": 0.0})
	for spawn: Vector4 in w.layout.enemy_spawns:
		var kind := "crawler" if int(spawn.z) == 0 else ("drifter" if int(spawn.z) == 1 else "boss")
		var hp := maxi(1, int(spawn.w))
		var p := Vector2(spawn.x, spawn.y)
		if kind == "crawler":
			w.add_enemy(kind, p, "", hp, p.x - 40, p.x + 40)
		elif kind == "drifter":
			w.add_enemy(kind, p, "", hp)
		else:
			w.add_enemy(kind, p, "guardian_%d" % w.enemies.size(), hp)

static func _item(p: Vector2,kind: String,lock: String,label: String) -> Dictionary:
	return {"p":p,"kind":kind,"lock":lock,"label":label,"taken":false}

static func _point(w: Node2D,index: int) -> Vector2:
	var rect: Rect2 = w.platforms[index]
	return Vector2(rect.get_center().x,rect.position.y-12)

static func _barrier(w: Node2D,row: int,left: int,right: int,kind: String,lock: String) -> void:
	w._fill(2,left-1,row,row)
	w._fill(right+1,37,row,row)
	w.gates.append({"rect":Rect2(left*16,row*16,(right-left+1)*16,16),"kind":kind,"lock":lock})
