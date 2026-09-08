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
	if not world.started:
		_title()
		return
	panel(Rect2(12,12,180,42))
	text(Vector2(22,28),"A S C E N T",13)
	text(Vector2(22,44),world.zone(),9,MINT)
	panel(Rect2(456,12,172,42))
	text(Vector2(468,28),"SUIT",9,Color("9bb0ac"))
	for i in range(3):
		draw_rect(Rect2(512+i*31,20,23,6),MINT if i < world.player.health else Color("344750"))
	text(Vector2(468,44),"PULSE",9,Color("9bb0ac"))
	for i in range(world.player.max_ammo):
		draw_rect(Rect2(508+i*31,37,23,5),Color("e8c789") if world.player.gun_unlocked and i < world.player.ammo else Color("344750"))
	var altitude := maxi(0,int((472-world.player.position.y)/8))
	text(Vector2(296,26),"%03d m" % altitude,13)
	# Quiet altitude rail along the edge of the viewport.
	draw_rect(Rect2(621,77,2,200),Color("354d53"))
	var progress := clampf((472-world.player.position.y)/(472-world.SUMMIT),0,1)
	draw_rect(Rect2(619,274-progress*197,6,4),MINT)
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
		text(Vector2(258,126),"SIGNAL HELD",22)
		text(Vector2(226,197),"ESC / P TO RESUME",12,MINT)
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
