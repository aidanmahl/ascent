extends Node2D
var world: Node2D
const INK := Color("0e202c")
const CREAM := Color("e5ead6")
const MINT := Color("91d4b6")

func text(p: Vector2, value: String, size: int = 11, color: Color = CREAM) -> void:
	draw_string(ThemeDB.fallback_font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(rect: Rect2) -> void:
	draw_rect(rect,Color(0.035,0.085,0.12,0.9))
	draw_rect(rect,Color("38525a"),false,1)

func _draw() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if world.started and not world.paused and not world.finished else Input.MOUSE_MODE_VISIBLE
	if world.started and not world.paused and not world.finished:
		var cursor := get_global_mouse_position()
		var ready: bool = world.player.ammo > 0 and world.player.shot_timer <= 0
		var tint := MINT if ready else Color("e2a078")
		draw_arc(cursor,10,0,TAU,24,INK,3)
		var cells := maxi(1,world.player.max_ammo)
		for i in range(cells):
			var start := -PI/2 + TAU*float(i)/cells + 0.08
			var finish := -PI/2 + TAU*float(i+1)/cells - 0.08
			var loaded: bool = world.player.gun_unlocked and i < world.player.ammo
			draw_arc(cursor,10,start,finish,10,tint if loaded else Color("435962"),2)
		if world.player.state.on_floor and world.player.recharge_timer > 0 and world.player.max_ammo > 0:
			var fill: float = 1.0-world.player.recharge_timer/(float(world.player.combat_config.ground_recharge_frames)/60.0)
			draw_arc(cursor,6,-PI/2,-PI/2+TAU*fill,12,Color("e8c789"),1)
		for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			draw_line(cursor+direction*8,cursor+direction*11,tint,1)
		draw_circle(cursor,1,CREAM)
	if not world.started:
		_title()
		return
	for i in range(world.player.health):
		draw_rect(Rect2(12+i*13,12,9,4),MINT)
	if world.message_time > 0:
		panel(Rect2(55,279,530,26))
		text(Vector2(67,296),world.message,10,MINT)
	if not world.boss_name.is_empty():
		panel(Rect2(182,61,276,30))
		text(Vector2(196,73),world.boss_name,9,Color("e3baa0"))
		draw_rect(Rect2(196,79,246,4),Color("473d4f"))
		draw_rect(Rect2(196,79,246*float(world.boss_hp)/world.boss_max,4),Color("d59b97"))
	if world.paused:
		draw_rect(Rect2(0,0,640,360),Color(0.03,0.08,0.11,0.78))
		panel(Rect2(140,92,360,174))
		if world.map_open:
			_draw_map()
		else:
			text(Vector2(258,126),"SIGNAL HELD",22)
			text(Vector2(161,157),"A/D MOVE   SPACE JUMP   SHIFT HORIZONTAL DASH",10,MINT)
			text(Vector2(161,179),"LMB FIRE   S+J RECOIL   RMB/K SLASH + PARRY",10,MINT)
			text(Vector2(161,201),"TAB MAP   E REST / SIGNAL   R RETRY",10,MINT)
			text(Vector2(226,239),"ESC / P TO RESUME",12,MINT)
	if world.finished:
		draw_rect(Rect2(0,0,640,360),Color(0.03,0.08,0.11,0.8))
		panel(Rect2(124,74,392,218))
		text(Vector2(225,107),"TRANSMISSION RECEIVED",11,MINT)
		text(Vector2(196,151),"A SKY WORTH FINDING",24)
		text(Vector2(192,178),"You made it out. This is only the first ascent.",12)
		text(Vector2(199,213),"%02d:%02d   /   %d creatures   /   %d recoveries" % [int(world.elapsed)/60,int(world.elapsed)%60,world.kills,world.deaths],12,MINT)
		text(Vector2(231,263),"ENTER  /  CLIMB AGAIN",13)

func _title() -> void:
	draw_rect(Rect2(0,0,640,360),Color(0.02,0.055,0.09,0.38))
	for i in range(32):
		draw_rect(Rect2(i*16,0,16,360),Color(0.025,0.06,0.085,0.55*(1.0-float(i)/32)))
	text(Vector2(39,39),"VESSEL 07     /     UNKNOWN WORLD",10,MINT)
	text(Vector2(39,102),"A S C E N T",49)
	draw_rect(Rect2(42,116,38,2),Color("d7b77c"))
	text(Vector2(42,145),"THE ONLY WAY HOME IS UP.",14,Color("e2c997"))
	text(Vector2(42,169),"A broken ship. A living world. One signal above the clouds.",11,Color("a8bcba"))
	panel(Rect2(41,189,221,36))
	text(Vector2(66,212),"ENTER / CLICK TO BEGIN",14,MINT)
	text(Vector2(42,267),"CHAPTER ONE  /  FIRST LIGHT",10,MINT)

func _draw_map() -> void:
	panel(Rect2(22,22,596,316))
	text(Vector2(40,47),"THE ORBITAL GARDEN",18,MINT)
	text(Vector2(440,46),"TAB / ESC  CLOSE",10)
	if world.legacy_campaign:
		text(Vector2(60,90),"Legacy traversal fixture",12)
		return
	var base := Vector2(68,70)
	var cell := Vector2(100,46)
	for edge: Dictionary in world.campaign.edges:
		if not edge.seen:
			continue
		var a: int = edge.a-1
		var b: int = edge.b-1
		var pa := base+Vector2(a%5,a/5)*cell+Vector2(44,18)
		var pb := base+Vector2(b%5,b/5)*cell+Vector2(44,18)
		var unlocked: bool = edge.requires.is_empty() or world.locks.get(edge.requires,false)
		if edge.requires=="boots": unlocked = world.player.wall_unlocked
		if edge.requires=="dash": unlocked = world.player.dash_unlocked
		if edge.requires=="cells": unlocked = world.player.max_ammo>=2
		draw_line(pa,pb,MINT if unlocked else Color("b69c70"),2)
		if not unlocked:
			draw_circle((pa+pb)/2,3,Color("d9b580"))
	for room: Dictionary in world.campaign.rooms:
		var id: int = room.id
		var p := base+Vector2((id-1)%5,(id-1)/5)*cell
		var known: bool = world.rooms.discovered.has(id)
		var seen := known
		for edge: Dictionary in world.campaign.edges:
			if edge.seen and (edge.a==id or edge.b==id): seen = true
		if not seen: continue
		draw_rect(Rect2(p,Vector2(88,36)),Color("244b50") if known else Color("132c37"))
		draw_rect(Rect2(p,Vector2(88,36)),MINT if known else Color("446069"),false,1)
		if known:
			text(p+Vector2(5,14),"Observatory" if id==10 else room.name,9)
			for item: Dictionary in world.pickups:
				if item.get("room",0)==id:
					draw_circle(p+Vector2(73,27),2,Color("5e7974") if item.taken else Color("efc784"))
			for checkpoint: Vector2 in world.checkpoints:
				if CampaignLayout.room_at(checkpoint)==id:
					draw_rect(Rect2(p+Vector2(7,24),Vector2(4,4)),MINT)
		if world.rooms.active_room.get("id",0)==id:
			var local: Vector2 = (world.player.position-room.origin)/CampaignLayout.CELL
			draw_circle(p+local*Vector2(88,36),3,Color("fff1bf"))
	text(Vector2(44,318),"MINT  explored    GOLD  obstacle / salvage    SQUARE  anchor",10,MINT)
	text(Vector2(374,318),"PUMP %s   CORE %s" % ["ON" if world.locks.get("pump",false) else "--","ON" if world.locks.get("core",false) else "--"],10)
