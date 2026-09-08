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
			text(Vector2(275,116),"EXPEDITION MAP",18)
			text(Vector2(185,151),"WRECK -- HOLLOW -- RELAY -- GLASS -- CANOPY",10,MINT)
			text(Vector2(185,174),"WARDEN  >  BOOTS  >  SENTINEL  >  ROOTHEART  >  CROWN",10,CREAM)
			text(Vector2(220,219),"TAB / ESC TO CLOSE",12,MINT)
		else:
			text(Vector2(258,126),"SIGNAL HELD",22)
			text(Vector2(176,175),"RMB / K SLASH + PARRY   TAB MAP",11,MINT)
			text(Vector2(226,211),"ESC / P TO RESUME",12,MINT)
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
