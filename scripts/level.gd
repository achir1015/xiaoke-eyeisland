class_name Level
extends Node3D
## 所有小遊戲的共同基底：3D 場景、鏡頭、視線選取（停留）、回合流程、示範、評估紀錄。
##
## 子類別要實作：
##   build()                 一次性的背景佈置（加到 self，不要加到 round_root）
##   new_round(i)            產生第 i 回合（物件加到 round_root；可用 await 做動畫）
##                           準備好讓孩子作答時呼叫 ready_to_answer()
##   on_pick(node, data)     孩子選了某個物件 → 呼叫 good()/bad()，整回合完成呼叫 finish_round()
##   bot_target() -> Node3D  自動示範／測試時應該選哪一個（還不能選就回傳 null）
## 可呼叫：add_pickable、clear_pickables、set_prompt、set_target、good、bad、hint_used、set_coverage
## 座標：鏡頭在 (0,0,12) 看向 -Z；畫面中央 z=0 平面大約 x∈[-7.3,7.3]、y∈[-4.1,4.1]（16:9）。
## 左邊 x≈-5.7 是「目標卡」與小柯；遊戲區請用 AREA。

signal round_finished
signal finished(result: Dictionary)
signal pause_requested
signal hint_requested

const AREA := Rect2(-4.3, -3.75, 10.6, 6.35)
const TARGET_POS := Vector3(-5.75, 0.9, 0)

static var capturing := false

var game_id := ""
var park_id := ""
var level_id := ""
var title := ""
var diff := 0
var rounds := 5
var round_i := 0
var rng := RandomNumberGenerator.new()
var has_hint := false             # 這個遊戲有沒有「提示」按鈕
var park_color := Color("#4C9AFF")
var theme := {}                    # Pal.park(park_id)：由樂園主色相對推算的整組顏色

var cam: Camera3D
var round_root: Node3D
var robot: Node3D
var target_card: Node3D
var hud: CanvasLayer
var prompt_label: Label
var dots: HBoxContainer
var ring_layer: Control
var toast: Label
var hint_btn: GazeButton
var replay_btn: GazeButton
var pause_btn: GazeButton

var pickables: Array = []          # [{node, r, data}]
var answering := false
var paused := false
var demo := false
var autoplay := false
var wrong_rate := 0.0
var hover = null
var hover_t := 0.0
var _pick_cool := 0.0
var _prompt_voice: Array = []
var _bot_target = null
var _bot_wait := 0.0
var _lost_said := false

# 紀錄
var t_start := 0
var t_round := 0
var errors := 0
var hints := 0
var round_errors := 0
var round_hints := 0
var round_coverage := -1.0
var round_lost := 0.0
var records: Array = []
var shots: Array = []
var _aois: Array = []
var _finished := false


# ---------------------------------------------------------------- 給子類別覆寫
func build() -> void:
	pass


func new_round(_i: int) -> void:
	pass


func on_pick(_node: Node3D, _data: Dictionary) -> void:
	pass


func bot_target() -> Node3D:
	return null


func on_hint() -> void:
	pass


# ---------------------------------------------------------------- 建立
func setup(info: Dictionary, d: int) -> void:
	game_id = info.id
	park_id = info.park
	title = info.name
	diff = d
	level_id = "%s_%d" % [game_id, d]
	park_color = Pal.park_color(park_id)
	theme = Pal.park(park_id)
	rounds = int(info.get("rounds", 5))
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			rng.seed = int(a.get_slice("=", 1))


func _ready() -> void:
	cam = Camera3D.new()
	cam.position = Vector3(0, 0, 12)
	cam.fov = 38
	cam.current = true
	add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-30), 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-10), deg_to_rad(150), 0)
	fill.light_energy = 0.25
	add_child(fill)
	apply_theme()
	round_root = Node3D.new()
	round_root.name = "Round"
	add_child(round_root)
	robot = M.robot()
	robot.position = Vector3(-5.75, -2.55, 0.5)
	robot.scale = Vector3.ONE * 0.95
	add_child(robot)
	_build_hud()
	build()


## 依樂園主題色佈置背景：上淡下深的牆面＋地板＋柔和環境光（子類別不用再設天空或背板）
func apply_theme() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(theme.wall2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(theme.ambient)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	var wall := Node3D.new()
	wall.name = "Backdrop"
	add_child(wall)
	# 牆面：由上（淡）到下（主題色）漸層；不受光照，顏色才準確
	for i in 8:
		var c := Color(theme.wall2).lerp(Color(theme.wall), i / 7.0)
		var band := M.box(Vector3(46, 2.2, 0.2), c, Vector3(0, 8.0 - i * 2.0, -9.0))
		band.material_override = M.flat(c)
		wall.add_child(band)
	var fl := M.box(Vector3(46, 0.2, 14), Color(theme.floor), Vector3(0, -4.6, -2.0))
	wall.add_child(fl)


## 換掉背景牆的顏色（例如海底要更深）
func backdrop_color(c: Color) -> void:
	var w := get_node_or_null("Backdrop")
	if w:
		w.queue_free()
	var b := M.box(Vector3(46, 16, 0.2), c, Vector3(0, 1, -9.0))
	b.material_override = M.flat(c)
	add_child(b)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	ring_layer = Control.new()
	ring_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_layer.draw.connect(_draw_rings)
	root.add_child(ring_layer)
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(theme.get("bar", "#FFFFFF"))
	sb.bg_color.a = 0.94
	sb.set_corner_radius_all(0)
	sb.corner_radius_bottom_left = 30
	sb.corner_radius_bottom_right = 30
	sb.border_width_bottom = 6
	sb.border_color = park_color
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 120
	bar.offset_right = -120
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	bar.add_child(hb)
	replay_btn = GazeButton.make("🔊", park_color, 34, Vector2(84, 76))
	replay_btn.tooltip_text = "再聽一次"
	replay_btn.pressed.connect(replay_prompt)
	hb.add_child(replay_btn)
	prompt_label = Label.new()
	prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_label.add_theme_font_size_override("font_size", 34)
	prompt_label.add_theme_color_override("font_color", theme.text)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.custom_minimum_size.y = 76
	hb.add_child(prompt_label)
	dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	hb.add_child(dots)
	hint_btn = GazeButton.make("💡 提示", theme.comp, 26, Vector2(150, 76))
	hint_btn.visible = false
	hint_btn.dwell_scale = 1.2
	hint_btn.pressed.connect(func(): if answering: hint_used(); on_hint())
	hb.add_child(hint_btn)
	pause_btn = GazeButton.make("⏸", theme.dark, 34, Vector2(96, 96))
	pause_btn.dwell_scale = 1.6
	pause_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-108, 10)
	pause_btn.pressed.connect(func(): pause_requested.emit())
	root.add_child(pause_btn)
	toast = Label.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.add_theme_font_size_override("font_size", 64)
	toast.add_theme_color_override("font_color", Color.WHITE)
	toast.add_theme_color_override("font_outline_color", theme.dark)
	toast.add_theme_constant_override("outline_size", 14)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	toast.modulate.a = 0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast)
	_update_dots()


func _update_dots() -> void:
	for c in dots.get_children():
		c.queue_free()
	for i in rounds:
		var l := Label.new()
		l.text = "★" if i < round_i or (i == round_i and _finished) else "☆"
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", theme.comp if i < round_i else theme.wall)
		dots.add_child(l)


# ---------------------------------------------------------------- 對外流程
## demo_first：先由小柯示範一回合
func begin(demo_first: bool) -> void:
	hint_btn.visible = has_hint
	if demo_first:
		await _demo()
	t_start = Time.get_ticks_msec()
	errors = 0
	hints = 0
	records.clear()
	shots.clear()
	for i in rounds:
		round_i = i
		_update_dots()
		_reset_round()
		new_round(i)
		await round_finished
		await get_tree().create_timer(1.0).timeout
	round_i = rounds
	_finished = true
	_update_dots()
	_finish()


func _demo() -> void:
	demo = true
	show_toast("小柯示範一次", 1.6)
	Snd.say("demo_start")
	await get_tree().create_timer(1.6).timeout
	_reset_round()
	new_round(0)
	await round_finished
	await get_tree().create_timer(1.0).timeout
	demo = false
	if not autoplay:
		Gaze.bot_point = null
	show_toast("換你囉！", 1.4)
	Snd.say("your_turn")
	await get_tree().create_timer(1.6).timeout


func _reset_round() -> void:
	for c in round_root.get_children():
		c.queue_free()
	pickables.clear()
	hover = null
	hover_t = 0.0
	answering = false
	round_errors = 0
	round_hints = 0
	round_coverage = -1.0
	round_lost = 0.0
	_lost_said = false
	_bot_target = null


## 子類別在可以作答時呼叫（開始計時、開始錄視線、拍下這回合的畫面）
func ready_to_answer() -> void:
	if answering:
		return
	answering = true
	t_round = Time.get_ticks_msec()
	if demo:
		return
	Gaze.begin_record()
	_capture.call_deferred()


func _capture() -> void:
	await get_tree().process_frame
	_aois = current_aois()
	capturing = true
	GazeCursor_hide(true)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	capturing = false
	GazeCursor_hide(false)
	if img:
		var w := 960
		img.resize(w, int(img.get_height() * float(w) / img.get_width()), Image.INTERPOLATE_BILINEAR)
	shots.append(img)


func GazeCursor_hide(v: bool) -> void:
	GazeCursor.hidden_for_capture = v
	ring_layer.visible = not v


func current_aois() -> Array:
	var out: Array = []
	var vs := get_viewport().get_visible_rect().size
	for p in pickables:
		var n: Node3D = p.node
		if not is_instance_valid(n) or not n.is_visible_in_tree():
			continue
		var sp := screen_pos(p)
		out.append({"name": str(p.data.get("name", "")), "x": snappedf(sp.x / vs.x, 0.0001), "y": snappedf(sp.y / vs.y, 0.0001),
			"r": snappedf(screen_radius(p) / vs.x, 0.0001), "target": bool(p.data.get("target", false))})
	return out


## 子類別在整回合答完時呼叫
func finish_round() -> void:
	answering = false
	hover = null
	if not demo:
		var samples := Gaze.end_record()
		records.append({"round": round_i + 1, "time": snappedf((Time.get_ticks_msec() - t_round) / 1000.0, 0.01),
			"errors": round_errors, "hints": round_hints, "coverage": snappedf(round_coverage, 0.001),
			"lost": snappedf(round_lost, 0.01), "aois": _aois, "samples": samples})
		robot_cheer()
		var praise := ["good1", "good2", "good3", "good4", "good5"]
		Snd.say(praise[rng.randi() % praise.size()], false)
	round_finished.emit()


func _finish() -> void:
	print("LEVEL FINISH")
	var dur := (Time.get_ticks_msec() - t_start) / 1000.0
	var cov_sum := 0.0
	var cov_n := 0
	for r in records:
		if float(r.coverage) >= 0.0:
			cov_sum += float(r.coverage)
			cov_n += 1
	var rate := float(errors) / maxf(1, rounds)
	var st := 3 if rate <= 0.2 else (2 if rate <= 0.8 else 1)
	if hints > rounds:
		st = mini(st, 2)
	var vs := get_viewport().get_visible_rect().size
	var result := {
		"level": level_id, "game": game_id, "park": park_id, "title": title, "diff": diff,
		"profile": Game.pid(), "name": Game.pname(), "age": Game.current.get("age", 0),
		"date": Time.get_datetime_string_from_system(), "duration": snappedf(dur, 0.1),
		"errors": errors, "hints": hints, "stars": st, "rounds": records,
		"coverage": snappedf(cov_sum / cov_n, 0.001) if cov_n > 0 else -1.0,
		"gaze_source": Gaze.source, "dwell_ms": Game.settings.dwell_ms, "screen": [vs.x, vs.y], "version": Game.APP_VERSION,
	}
	finished.emit(result)


# ---------------------------------------------------------------- 選取物件
## 註冊可以被「看選」的物件（請在 pop_in 之前呼叫，才會記住原本大小）
## data 常用欄位：name（報告顯示）、target（是不是正確答案）、offset（中心偏移）、disabled
func add_pickable(node: Node3D, radius: float, data := {}) -> void:
	if not data.has("base_scale"):
		data["base_scale"] = node.scale
	pickables.append({"node": node, "r": radius, "data": data})


func remove_pickable(node: Node3D) -> void:
	for i in range(pickables.size() - 1, -1, -1):
		if pickables[i].node == node:
			pickables.remove_at(i)
	if hover and hover.node == node:
		hover = null


func clear_pickables() -> void:
	pickables.clear()
	hover = null


func screen_pos(p: Dictionary) -> Vector2:
	var n: Node3D = p.node
	var off: Vector3 = p.data.get("offset", Vector3.ZERO)
	return cam.unproject_position(n.global_position + off)


func screen_radius(p: Dictionary) -> float:
	var n: Node3D = p.node
	var off: Vector3 = p.data.get("offset", Vector3.ZERO)
	var c := n.global_position + off
	var s := n.global_transform.basis.get_scale().x
	return cam.unproject_position(c).distance_to(cam.unproject_position(c + cam.global_transform.basis.x * p.r * s))


func pick_at(pt: Vector2):
	var best = null
	var best_d := INF
	var magnet := 1.35 if bool(Game.settings.magnet) else 1.0
	for p in pickables:
		var n: Node3D = p.node
		if not is_instance_valid(n) or not n.is_visible_in_tree() or p.data.get("disabled", false):
			continue
		var d := screen_pos(p).distance_to(pt)
		var r := screen_radius(p)
		var score := d / maxf(r, 1.0)
		if d <= r * magnet and score < best_d:
			best_d = score
			best = p
	return best


func _process(delta: float) -> void:
	_pick_cool = maxf(0.0, _pick_cool - delta)
	_drive_bot(delta)
	if robot:
		var head := robot.get_node("Head") as Node3D
		head.rotation.z = sin(Time.get_ticks_msec() / 700.0) * 0.06
		robot.position.y = -2.55 + sin(Time.get_ticks_msec() / 500.0) * 0.05
	if target_card:
		target_card.get_child(-1).rotation.y = sin(Time.get_ticks_msec() / 900.0) * 0.35
	if answering and not paused and not demo and Gaze.source == "eyemouse" and not Gaze.valid:
		round_lost += delta
		if Gaze.lost_for > 2.5 and not _lost_said:
			_lost_said = true
			show_toast("小柯看不到你的眼睛囉", 2.0)
			Snd.say("gaze_lost")
	elif Gaze.valid:
		_lost_said = false
	var old = hover
	if not answering or paused or _pick_cool > 0.0 or not Gaze.valid:
		hover = null
	else:
		var h = pick_at(Gaze.point)
		if h != hover:
			hover = h
			hover_t = 0.0
			if h:
				Snd.play("tick", 0.4)
		elif hover:
			hover_t += delta
	if old and old != hover and is_instance_valid(old.node):
		_set_glow(old, false)
	if hover:
		_set_glow(hover, true)
		var prog := hover_t / maxf(0.3, Game.dwell_s())
		GazeCursor.level_progress = prog
		GazeCursor.level_frame = Engine.get_process_frames()
		if prog >= 1.0:
			_fire(hover)
	ring_layer.queue_redraw()


func _fire(p: Dictionary) -> void:
	_pick_cool = 0.6
	hover_t = 0.0
	var node: Node3D = p.node
	_set_glow(p, false)
	hover = null
	_bot_target = null          # 自動示範／測試：選完一次就重新決定目標（答錯後不會一直看同一個）
	Snd.play("pop")
	on_pick(node, p.data)


func _set_glow(p: Dictionary, on: bool) -> void:
	var n: Node3D = p.node
	if not is_instance_valid(n):
		return
	var base: Vector3 = p.data.get("base_scale", n.scale)
	n.scale = n.scale.lerp(base * (1.12 if on else 1.0), 0.25) if on else base


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if answering and not paused and bool(Game.settings.click_ok) and _pick_cool <= 0.0:
			var p = pick_at(get_viewport().get_mouse_position())
			if p:
				_fire(p)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pause_requested.emit()


func _draw_rings() -> void:
	if capturing:
		return
	if hover and is_instance_valid(hover.node):
		var c := screen_pos(hover)
		var r := screen_radius(hover) * 1.05 + 10
		var prog := clampf(hover_t / maxf(0.3, Game.dwell_s()), 0, 1)
		ring_layer.draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.75), 6, true)
		ring_layer.draw_arc(c, r, -PI / 2, -PI / 2 + TAU * prog, 64, theme.comp, 10, true)


# ---------------------------------------------------------------- 自動示範／測試
func _drive_bot(delta: float) -> void:
	if not (demo or autoplay):
		return
	if not answering:
		_bot_target = null
		_bot_wait = 0.0
		return
	if _bot_target == null or not is_instance_valid(_bot_target) or pick_entry(_bot_target) == null:
		_bot_wait += delta
		if _bot_wait < (0.6 if demo else 0.25):
			return
		_bot_wait = 0.0
		var t := bot_target()
		if t and not demo and wrong_rate > 0.0 and rng.randf() < wrong_rate:
			var others: Array = []
			for p in pickables:
				if p.node != t and not p.data.get("target", false) and not p.data.get("disabled", false):
					others.append(p.node)
			if not others.is_empty():
				t = others[rng.randi() % others.size()]
		_bot_target = t
	if _bot_target == null:
		return
	var pe = pick_entry(_bot_target)
	if pe == null:
		_bot_target = null
		return
	var goal := screen_pos(pe)
	var cur: Vector2 = Gaze.bot_point if Gaze.bot_point != null else get_viewport().get_visible_rect().size / 2
	var step := (500.0 if demo else 1600.0) * delta
	Gaze.bot_point = cur.move_toward(goal, step)


func pick_entry(node: Node3D):
	for p in pickables:
		if p.node == node:
			return p
	return null


# ---------------------------------------------------------------- 回饋與提示
func set_prompt(text: String, voice := []) -> void:
	prompt_label.text = text
	_prompt_voice = voice
	if not voice.is_empty():
		Snd.say(voice)


func replay_prompt() -> void:
	if not _prompt_voice.is_empty():
		Snd.say(_prompt_voice)


## 左邊的目標卡（要找的東西）
func set_target(node: Node3D, fit := 1.7) -> void:
	clear_target()
	target_card = Node3D.new()
	target_card.position = TARGET_POS
	var card := M.box(Vector3(2.3, 2.5, 0.15), Color(theme.get("bar", "#FFFFFF")), Vector3(0, 0, -0.6))
	target_card.add_child(card)
	var frame := M.box(Vector3(2.5, 2.7, 0.1), theme.comp, Vector3(0, 0, -0.7))
	target_card.add_child(frame)
	var holder := Node3D.new()
	holder.add_child(node)
	holder.scale = Vector3.ONE * fit / 2.0
	target_card.add_child(holder)
	_no_shadow(target_card)
	add_child(target_card)
	target_card.scale = Vector3.ONE * 0.01
	create_tween().tween_property(target_card, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


func clear_target() -> void:
	if target_card:
		target_card.queue_free()
		target_card = null


func good(node: Node3D, sound := true) -> void:
	if sound:
		Snd.play("good")
	_burst(node.global_position)
	var tw := create_tween()
	var s := node.scale
	tw.tween_property(node, "scale", s * 1.3, 0.12)
	tw.tween_property(node, "scale", s, 0.18)


func bad(node: Node3D) -> void:
	if not demo:
		errors += 1
		round_errors += 1
	Snd.play("bad")
	var tw := create_tween()
	var x := node.position.x
	for k in 4:
		tw.tween_property(node, "position:x", x + (0.15 if k % 2 == 0 else -0.15), 0.05)
	tw.tween_property(node, "position:x", x, 0.05)
	var hd := robot.get_node("Head") as Node3D
	var tw2 := create_tween()
	for k in 3:
		tw2.tween_property(hd, "rotation:y", 0.35 if k % 2 == 0 else -0.35, 0.1)
	tw2.tween_property(hd, "rotation:y", 0.0, 0.1)
	var lines := ["try1", "try2", "try3"]
	Snd.say(lines[rng.randi() % lines.size()])


func hint_used() -> void:
	if not demo:
		hints += 1
		round_hints += 1
	Snd.play("hint")


func set_coverage(v: float) -> void:
	round_coverage = clampf(v, 0.0, 1.0)


func robot_cheer() -> void:
	var tw := create_tween()
	tw.tween_property(robot, "position:y", -2.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(robot, "position:y", -2.55, 0.25).set_ease(Tween.EASE_IN)
	for arm_name in ["ArmL", "ArmR"]:
		var arm := robot.get_node(arm_name) as Node3D
		var t2 := create_tween()
		t2.tween_property(arm, "rotation:z", (2.4 if arm_name == "ArmR" else -2.4), 0.2)
		t2.tween_property(arm, "rotation:z", 0.0, 0.3)


func show_toast(text: String, secs := 1.2) -> void:
	toast.text = text
	toast.pivot_offset = toast.size / 2
	var tw := create_tween()
	toast.modulate.a = 0
	toast.scale = Vector2.ONE * 0.6
	tw.tween_property(toast, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(secs)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)


func _burst(at: Vector3) -> void:
	for i in 10:
		var acc: Array = theme.accent
		var s := M.star(5, 0.18, 0.08, 0.05, acc[i % acc.size()])
		s.position = at + Vector3(0, 0, 1.0)
		add_child(s)
		var a := TAU * i / 10.0
		var tw := create_tween()
		tw.tween_property(s, "position", at + Vector3(cos(a) * 1.4, sin(a) * 1.4, 1.2), 0.45).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "rotation:z", 3.0, 0.45)
		tw.parallel().tween_property(s, "scale", Vector3.ONE * 0.1, 0.45)
		tw.tween_callback(s.queue_free)


# ---------------------------------------------------------------- 排版工具
## 在矩形裡排成格子，回傳中心點
func grid(n: int, rect: Rect2 = AREA, cols := 0) -> Array:
	if cols <= 0:
		cols = int(ceil(sqrt(n * rect.size.x / rect.size.y)))
	var rows := int(ceil(float(n) / cols))
	var out: Array = []
	for i in n:
		var r := i / cols
		var c := i % cols
		var in_row := mini(cols, n - r * cols)
		var cw := rect.size.x / cols
		var x := rect.position.x + cw * (c + 0.5) + (cols - in_row) * cw / 2.0
		var y := rect.end.y - rect.size.y / rows * (r + 0.5)
		out.append(Vector3(x, y, 0))
	return out


## 在矩形裡隨機散佈（盡量保持距離）
func scatter(n: int, min_d: float, rect: Rect2 = AREA) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < n and tries < 4000:
		tries += 1
		var p := Vector3(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y), 0)
		var ok := true
		var md := min_d * (1.0 - tries / 5000.0)
		for q in out:
			if Vector2(p.x, p.y).distance_to(Vector2(q.x, q.y)) < md:
				ok = false
				break
		if ok:
			out.append(p)
	return out


func pick_n(arr: Array, n: int) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a.slice(0, mini(n, a.size()))


func shuffled(arr: Array) -> Array:
	return pick_n(arr, arr.size())


## 把物件由小變大地出現
func pop_in(n: Node3D, delay := 0.0) -> void:
	var s := n.scale
	n.scale = s * 0.01
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(n, "scale", s, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout
