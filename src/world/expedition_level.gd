class_name ExpeditionLevel
extends RefCounted

# Authored landings, not a generated staircase. Each row is x, y, width in
# tiles; the repeated launch ledges describe detours back to the main climb.
const ROUTE := [
	Vector3i(13,27,5), Vector3i(19,24,5), Vector3i(25,21,5),
	Vector3i(31,18,5), Vector3i(26,15,9), Vector3i(10,15,5),
	Vector3i(17,9,5), Vector3i(25,3,5), Vector3i(17,-3,5),
	Vector3i(9,-9,6), Vector3i(17,-13,5), Vector3i(25,-13,11),
	Vector3i(17,-13,5), Vector3i(10,-21,5), Vector3i(18,-32,5),
	Vector3i(26,-37,5), Vector3i(19,-45,5), Vector3i(11,-53,6),
	Vector3i(4,-57,9), Vector3i(17,-61,5), Vector3i(18,-73,4),
	Vector3i(11,-80,5), Vector3i(19,-88,5), Vector3i(27,-92,9),
	Vector3i(25,-96,5), Vector3i(19,-103,5), Vector3i(17,-111,5),
	Vector3i(9,-119,5), Vector3i(17,-127,5), Vector3i(26,-131,10),
	Vector3i(17,-135,6), Vector3i(17,-143,6),
	Vector3i(10,-153,5), Vector3i(22,-163,5), Vector3i(29,-173,5),
	Vector3i(17,-183,5), Vector3i(8,-193,5), Vector3i(19,-203,5),
	Vector3i(28,-213,7), Vector3i(20,-223,5), Vector3i(11,-233,6),
	Vector3i(19,-243,8), Vector3i(12,-253,8)
]

static func build(w: Node2D) -> void:
	if w.layout and not w.layout.platforms.is_empty():
		build_from_layout(w)
		return
	w._fill(0,39,30,34)
	w._fill(0,1,-260,30)
	w._fill(38,39,-260,30)
	for p: Vector3i in ROUTE:
		w._fill(p.x,p.x+p.z-1,p.y,p.y+1)
		w.platforms.append(Rect2(p.x*16,p.y*16,p.z*16,32))
	# Finite wall-kick transfer. There is no continuous wall ladder.
	w._fill(23,23,-77,-61)
	# The narrow transfer is sealed until the magnetic boots are earned.
	_barrier(w,-77,11,18,"seal","boots")
	# Relay divider: the second target requires moving above the partition.
	w._fill(8,8,-62,-58)
	# Stone diaphragms force travel through their visible openings.
	_barrier(w,-99,24,27,"phase", "")
	_barrier(w,-29,18,22,"seal", "warden")
	_barrier(w,-139,18,21,"seal", "airlock")
	_barrier(w,-187,8,12,"phase", "")
	_barrier(w,-247,12,27,"seal", "crown")
	w.checkpoints.assign([Vector2(472,232),Vector2(192,-152),Vector2(304,-216),Vector2(336,-728),Vector2(112,-920),Vector2(336,-1416),Vector2(424,-1544),Vector2(304,-2040),Vector2(312,-2168),Vector2(304,-2936),Vector2(480,-3416),Vector2(344,-3896)])
	w.pickups.assign([
		_item(Vector2(540,228),"gun","","PULSE CUTTER / 1 CELL"),
		_item(Vector2(546,-220),"ammo2","warden","TWIN-CELL MAGAZINE"),
		_item(Vector2(92,-924),"boots","boots","MAGNETIC KICK BOOTS"),
		_item(Vector2(548,-1484),"dash","sentinel","VECTOR THRUSTER"),
		_item(Vector2(544,-2108),"ammo3","reservoir","TRIPLE-CELL MAGAZINE")])
	w.switches.assign([
		{"p":Vector2(76,-966),"group":"boots","lit":false,"timer":0.0},
		{"p":Vector2(186,-1004),"group":"boots","lit":false,"timer":0.0}])
	w.capacitor = {"p":Vector2(392,-2128),"hits":0,"flight":-1}
	# Warm red is always dangerous. Spikes have actual tips above stone.
	# The opening runway is a safe read of the jump arc. Hazards begin after
	# the first landing so the player can learn the climb before being asked
	# to thread a jump over damage.
	# Leave the first three landings clean; the first hazard begins after the
	# player has had room to learn the normal jump arc.
	for i in [8,13,15,17,21,27,32,34,36,39,40]:
		var ledge: Rect2 = w.platforms[i]
		var x := ledge.position.x if i%2 == 0 else ledge.end.x-12
		w.hazards.append({"rect":Rect2(x,ledge.position.y-8,12,8),"kind":"spikes","phase":0.0})
	# Geysers telegraph before erupting. Their mouths sit on actual ledges.
	for i in [7,15,17,23,26,29,33,37,41]:
		var ledge: Rect2 = w.platforms[i]
		var p := Vector2(ledge.end.x-28,ledge.position.y)
		w.hazards.append({"rect":Rect2(p-Vector2(8,76),Vector2(16,76)),"kind":"vent","phase":fposmod(float(i),3.8)})
	for i in [8,14,17,21,27,32,36,39]:
		var r: Rect2 = w.platforms[i]
		w.add_enemy("crawler",Vector2(r.position.x+32,r.position.y-7),"",2,r.position.x+12,r.end.x-12)
	for i in [6,9,13,16,22,26,28,33,35,37,40]:
		var r: Rect2 = w.platforms[i]
		w.add_enemy("drifter",Vector2(r.position.x-26,r.position.y-32),"",1)
	w.add_enemy("boss",Vector2(500,-269),"warden",7)
	w.add_enemy("boss",Vector2(502,-1534),"sentinel",10)
	w.add_enemy("boss",Vector2(500,-2148),"reservoir",12)
	w.add_enemy("boss",Vector2(392,-3950),"crown",16)
	w.signs = [
		[Vector2(199,398),"SALVAGE TRAIL  >"],
		[Vector2(446,197),"CARGO CACHE"],
		[Vector2(273,207),"RECOIL SHAFT / FIRE DOWN TO RISE"],
		[Vector2(403,-178),"WARDEN'S NEST  >  MAGAZINE"],
		[Vector2(68,-1025),"SHOOT BOTH RELAYS / 5 SECONDS"],
		[Vector2(268,-953),"KICK OFF THE RIGHT WALL"],
		[Vector2(416,-1448),"THRUSTER VAULT / SENTINEL"],
		[Vector2(390,-1595),"DASH THROUGH THE BLUE MEMBRANE"],
		[Vector2(426,-2060),"ROOTHEART / FINAL MAGAZINE"],
		[Vector2(249,-2244),"DROP RIGHT. FIRE DOWN INTO CORE 3x."],
		[Vector2(326,-3854),"THE CROWN / BREAK THE LAST SEAL"]]

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

static func _barrier(w: Node2D,row: int,left: int,right: int,kind: String,lock: String) -> void:
	w._fill(2,left-1,row,row)
	w._fill(right+1,37,row,row)
	w.gates.append({"rect":Rect2(left*16,row*16,(right-left+1)*16,16),"kind":kind,"lock":lock})
