extends Node
## 音樂、音效（tools/gen_audio.py 原創合成）與語音（tools/gen_voice.py，edge-tts 台灣華語）。

const TRACKS := [
	["m01_island", "探險島的早晨"], ["m02_rainbow", "彩虹遊樂場"], ["m03_blocks", "積木工坊"], ["m04_juice", "果汁吧派對"],
	["m05_ocean", "海底散步"], ["m06_forest", "森林捉迷藏"], ["m07_stars", "星星報告"], ["m08_lullaby", "休息一下"],
]
const SFX := ["click", "pop", "good", "bad", "star", "whoosh", "fanfare", "select", "tick", "bubble", "leaf", "blend", "cup", "drop", "chime", "hint"]

var music := AudioStreamPlayer.new()
var voice := AudioStreamPlayer.new()
var pool: Array = []
var streams: Dictionary = {}
var music_vol := 0.35
var sfx_vol := 0.8
var voice_vol := 1.0
var fullscreen := true
var _cur := ""
var _duck := 0.0
var _queue: Array = []
var _cooldown := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	add_child(voice)
	music.finished.connect(func(): if _cur != "": play_music(_cur, true))
	voice.finished.connect(_next_voice)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	for s in SFX:
		var path := "res://assets/sfx/%s.wav" % s
		if ResourceLoader.exists(path):
			streams[s] = load(path)
	_load_settings()


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://audio.cfg") == OK:
		music_vol = float(cf.get_value("audio", "music", music_vol))
		sfx_vol = float(cf.get_value("audio", "sfx", sfx_vol))
		voice_vol = float(cf.get_value("audio", "voice", voice_vol))
		fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	_apply()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_vol)
	cf.set_value("audio", "sfx", sfx_vol)
	cf.set_value("audio", "voice", voice_vol)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.save("user://audio.cfg")


func _apply() -> void:
	music.volume_db = linear_to_db(maxf(music_vol, 0.001)) - 6.0 - _duck
	music.stream_paused = music_vol <= 0.001


func set_music_vol(v: float) -> void:
	music_vol = v
	_apply()
	if not music.playing and v > 0.001 and _cur != "":
		play_music(_cur, true)


func play_music(name: String, force := false) -> void:
	if name == _cur and music.playing and not force:
		return
	var path := "res://assets/music/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	_cur = name
	music.stream = load(path)
	if music_vol > 0.001:
		music.play()


func track_name() -> String:
	for t in TRACKS:
		if t[0] == _cur:
			return t[1]
	return ""


func play(name: String, vol := 1.0, pitch := 1.0) -> void:
	if sfx_vol <= 0.001 or not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_cooldown.get(name, 0)) < 60:
		return
	_cooldown[name] = now
	for p in pool:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = streams[name]
			ap.volume_db = linear_to_db(maxf(sfx_vol * vol, 0.001))
			ap.pitch_scale = pitch
			ap.play()
			return


func has_voice(id: String) -> bool:
	return ResourceLoader.exists("res://assets/voice/%s.ogg" % id)


## 立刻說一句（中斷正在說的）；ids 可以是一個或多個語音片段，依序播放
func say(ids, interrupt := true) -> void:
	var list: Array = ids if ids is Array else [ids]
	if interrupt:
		_queue.clear()
		voice.stop()
	for id in list:
		if has_voice(str(id)):
			_queue.append(str(id))
		elif str(id) != "":
			print("MISSING_VOICE ", id)
	if not voice.playing:
		_next_voice()


func _next_voice() -> void:
	if _queue.is_empty() or voice_vol <= 0.001:
		_queue.clear()
		return
	var id: String = _queue.pop_front()
	voice.stream = load("res://assets/voice/%s.ogg" % id)
	voice.volume_db = linear_to_db(maxf(voice_vol, 0.001))
	voice.play()


func stop_voice() -> void:
	_queue.clear()
	voice.stop()


func speaking() -> bool:
	return voice.playing or not _queue.is_empty()


func stop_all() -> void:
	stop_voice()
	music.stop()
	for p in pool:
		(p as AudioStreamPlayer).stop()


func _process(delta: float) -> void:
	var want := 14.0 if voice.playing else 0.0
	if absf(_duck - want) > 0.05:
		_duck = move_toward(_duck, want, delta * 30.0)
		_apply()
