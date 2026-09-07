extends Node
# Small synthesized effects and a quiet, evolving ambient chord. No external assets.
var effects: Dictionary = {}
var ambient: AudioStreamPlayer

func _ready() -> void:
	for kind in ["shot","jump","dash","hurt","kill","save"]:
		effects[kind] = _effect(kind)
	ambient = AudioStreamPlayer.new()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 4 * 2)
	for i in range(22050*4):
		var t := float(i)/22050
		var v := (sin(TAU*55*t)+sin(TAU*82.5*t)*0.45+sin(TAU*110*t)*0.3)*0.035
		data.encode_s16(i*2,int(v*32767))
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050*4
	ambient.stream = stream
	ambient.volume_db = -15
	add_child(ambient)

func set_muted(value: bool) -> void:
	ambient.volume_db = -80 if value else -15

func play_effect(kind: String) -> void:
	if not ambient.playing:
		ambient.play()
	var player := AudioStreamPlayer.new()
	player.stream = effects.get(kind,effects.shot)
	player.volume_db = -13
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _effect(kind: String) -> AudioStreamWAV:
	var duration := 0.12
	var start := 440.0
	var end := 180.0
	match kind:
		"shot": start = 220; end = 55; duration = 0.10
		"jump": start = 240; end = 620; duration = 0.12
		"dash": start = 420; end = 100; duration = 0.18
		"hurt": start = 120; end = 40; duration = 0.25
		"kill": start = 220; end = 50; duration = 0.19
		"save": start = 440; end = 880; duration = 0.55
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(duration*22050)
	var data := PackedByteArray()
	data.resize(count*2)
	var phase := 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 17
	for i in range(count):
		var t := float(i)/count
		phase += lerpf(start,end,t)/22050
		var v := sin(phase*TAU)
		if kind == "shot" or kind == "hurt" or kind == "dash":
			v = v*0.5+random.randf_range(-1,1)*0.5
		if kind == "save":
			v = sin(TAU*float(i)/22050*[440.0,554.37,659.25,880.0][mini(3,int(t*4))])
		v *= minf(t*35,1)*pow(1-t,1.5)*0.45
		data.encode_s16(i*2,int(v*32767))
	stream.data = data
	return stream
