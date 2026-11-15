extends Node
## 主流程：標題 → 小朋友 → 探險島地圖 → 樂園（6 關）→ 關卡說明 → 遊戲 → 結果 → 評估報告。
## 測試旗標（Godot 參數 -- 之後）：
##   --test --play=遊戲:難度 [--autoplay] [--demo] [--wrong=0.3] [--save-records] [--then=report]
##   --screen=title|profiles|map|park:ID|help:N|settings|report|about  --shots=資料夾  --quit

const ISLAND_POS := {"rainbow": Vector3(-4.6, 0.6, 0.6), "blocks": Vector3(-2.4, 0.6, -2.6), "juice": Vector3(2.4, 0.6, -2.6),
	"ocean": Vector3(4.6, 0.4, 0.6), "forest": Vector3(0.0, 0.6, 2.0)}

var world: Node3D
var ui: CanvasLayer
var screen: Control
var modal_layer: Control
var cursor: GazeCursor
var level: Level
var menu3d: Node3D
var menu_cam: Camera3D
var cur := ""
var P := Pal.menu()                 # 目前畫面的相對配色（選單＝藍色主色；樂園內＝該樂園主色）
var cur_park := ""
var cur_game := ""
var cur_diff := 0
var last_result := {}
var last_record_dir := ""
var _last_rest_min := 0.0
var args := {}
var _shot_n := 0
var _report_sel := 0
var _report_round := 0
var _report_mode := "path"
var _records: Array = []
var _help_page := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		if s.contains("="):
			args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
		else:
			args[s] = true
	get_tree().auto_accept_quit = false
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen)
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(modal_layer)
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	cursor = GazeCursor.new()
	cl.add_child(cursor)
	if not args.has("test") and Snd.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Updater.checked.connect(_on_update_checked)
	if args.has("linkcheck"):
		for i in 16:
			await get_tree().create_timer(0.5).timeout
			print("LINK linked=%s src=%s gaze=%s mouse=%s" % [Gaze.linked, Gaze.eyemouse_source, Gaze.point, get_viewport().get_mouse_position()])
		quit_game()
		return
	if args.has("play"):
		var p := str(args.play)
		_ensure_profile()
		start_level(p.get_slice(":", 0), int(p.get_slice(":", 1)) if p.contains(":") else 0)
		return
	if args.has("screen"):
		_ensure_profile()
		_open_screen(str(args.screen))
		return
	show_title()
	await get_tree().create_timer(0.8).timeout
	Snd.say("welcome")
	if not args.has("test"):
		await get_tree().create_timer(6.0).timeout
		Updater.check()


func _ensure_profile() -> void:
	if Game.current.is_empty():
		if Game.profiles.is_empty():
			Game.current = {"id": "test", "name": "測試小朋友", "age": 6, "color": "#80D8FF"}
		else:
			Game.current = Game.profiles[0]


func _open_screen(s: String) -> void:
	var name_ := s.get_slice(":", 0)
	var param := s.get_slice(":", 1) if s.contains(":") else ""
	match name_:
		"title": show_title()
		"profiles": show_profiles()
		"map": show_map()
		"park": show_park(param if param != "" else "rainbow")
		"help": _help_page = int(param); show_help()
		"settings": show_settings()
		"report": show_report()
		"about": show_about()
	if args.has("shots"):
		await get_tree().create_timer(1.2).timeout
		await shot(name_)
		if args.has("quit"):
			get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func quit_game() -> void:
	Snd.stop_all()
	Gaze.shutdown()
	get_tree().quit()


# ================================================================ 小工具
func shot(name_: String) -> void:
	if not args.has("shots"):
		return
	await RenderingServer.frame_post_draw
	var dir := str(args.shots)
	DirAccess.make_dir_recursive_absolute(dir)
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("%02d_%s.png" % [_shot_n, name_]))
	print("SHOT ", name_)


func clear_screen() -> void:
	GazeButton.modal = null
	for c in screen.get_children():
		c.queue_free()
	for c in modal_layer.get_children():
		c.queue_free()


func clear_world() -> void:
	for c in world.get_children():
		c.queue_free()
	level = null
	menu3d = null


func lbl(text: String, size := 28, color := Color(0, 0, 0, 0), align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	if color.a == 0.0:
		color = P.text
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func title_lbl(text: String, size := 56, color := Color.WHITE, outline := Color(0, 0, 0, 0)) -> Label:
	if outline.a == 0.0:
		outline = P.dark
	var l := lbl(text, size, color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", 16)
	return l


func btn(text: String, color: Color, cb: Callable, fs := 30, min_size := Vector2(240, 100)) -> GazeButton:
	var b := GazeButton.make(text, color, fs, min_size)
	b.pressed.connect(cb)
	return b


func panel(color := Color(0, 0, 0, 0), radius := 36, pad := 28) -> PanelContainer:
	if color.a == 0.0:
		color = Color(P.bar, 0.95)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_bottom = 8
	sb.border_color = P.light
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_size = 12
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", sb)
	return p


func vbox(sep := 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func center(c: Control, parent: Control = null) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	(parent if parent else screen).add_child(cc)
	return cc


func back_btn(cb: Callable) -> GazeButton:
	var b := btn("◀ 返回", P.dark, cb, 28, Vector2(180, 90))
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	b.position = Vector2(20, 18)
	screen.add_child(b)
	return b


func stars_text(n: int, total := 3) -> String:
	var s := ""
	for i in total:
		s += "★" if i < n else "☆"
	return s


# ================================================================ 3D 選單背景（探險島）
func build_island(cam_pos := Vector3(0, 8.5, 10.5), look := Vector3(0, 0, -0.5)) -> void:
	clear_world()
	menu3d = Node3D.new()
	world.add_child(menu3d)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Pal.hsv(Pal.MENU_HUE, 0.55, 0.97)
	sm.sky_horizon_color = Pal.hsv(Pal.MENU_HUE, 0.15, 1.0)
	sm.ground_horizon_color = Pal.hsv(Pal.MENU_HUE, 0.15, 1.0)
	sm.ground_bottom_color = Pal.hsv(Pal.MENU_HUE, 0.75, 0.6)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Pal.hsv(Pal.MENU_HUE, 0.1, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	menu3d.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	menu3d.add_child(sun)
	menu_cam = Camera3D.new()
	menu_cam.position = cam_pos
	menu_cam.fov = 45
	menu3d.add_child(menu_cam)
	menu_cam.look_at(look)
	menu_cam.current = true
	var sea := M.cyl(40, 40, 0.2, P.base, Vector3(0, -0.6, 0), Vector3.ZERO, 48)
	menu3d.add_child(sea)
	var sand := M.sphere(7.2, Pal.hsv(Pal.MENU_HUE + 0.5, 0.35, 0.95), Vector3(0, -0.9, 0), Vector3(1.05, 0.16, 0.72))
	menu3d.add_child(sand)
	var grass := M.sphere(6.6, Pal.hsv(Pal.PARK_HUES.forest, 0.5, 0.72), Vector3(0, -0.72, -0.1), Vector3(1.0, 0.16, 0.66))
	menu3d.add_child(grass)
	# 彩虹遊樂場：彩虹拱門
	var rb := Node3D.new()
	rb.position = ISLAND_POS.rainbow
	for k in 5:
		var t := M.torus(0.9 + k * 0.16, 1.05 + k * 0.16, ["purple", "blue", "green", "yellow", "red"][k], Vector3.ZERO, Vector3(PI / 2, 0, 0))
		rb.add_child(t)
	rb.add_child(M.box(Vector3(3.4, 1.4, 1.0), Pal.hsv(Pal.PARK_HUES.forest, 0.55, 0.62), Vector3(0, -0.9, 0)))
	menu3d.add_child(rb)
	# 積木工坊：疊疊樂
	var bl := Node3D.new()
	bl.position = ISLAND_POS.blocks
	for k in 4:
		bl.add_child(M.box(Vector3(0.8, 0.8, 0.8), ["red", "blue", "yellow", "green"][k], Vector3((k % 2) * 0.3 - 0.15, k * 0.8, 0), Vector3(0, k * 0.4, 0)))
	menu3d.add_child(bl)
	# 果汁吧：大杯果汁
	var ju := Node3D.new()
	ju.position = ISLAND_POS.juice
	ju.add_child(M.cyl(0.75, 0.6, 1.8, P.analog_a, Vector3(0, 0.9, 0)))
	ju.add_child(M.cyl(0.8, 0.8, 0.12, "white", Vector3(0, 1.85, 0)))
	ju.add_child(M.cyl(0.07, 0.07, 1.4, "pink", Vector3(0.3, 2.3, 0), Vector3(0, 0, -0.3)))
	ju.add_child(M.fruit("orange"))
	ju.get_child(-1).position = Vector3(-0.7, 2.0, 0.2)
	ju.get_child(-1).scale = Vector3.ONE * 0.5
	menu3d.add_child(ju)
	# 海洋搜查隊：跳出水面的魚
	var oc := Node3D.new()
	oc.position = ISLAND_POS.ocean
	var f := M.fish("cyan", "stripes")
	f.position = Vector3(0, 1.0, 0)
	f.rotation.z = 0.5
	oc.add_child(f)
	oc.add_child(M.cyl(0.9, 1.0, 0.3, P.analog_b, Vector3(0, 0, 0)))
	menu3d.add_child(oc)
	# 森林躲貓貓：樹叢
	var fo := Node3D.new()
	fo.position = ISLAND_POS.forest
	for k in 3:
		var tr := M.tree(2.0 + k * 0.3)
		tr.position = Vector3((k - 1) * 0.9, -0.5, -abs(k - 1) * 0.4)
		fo.add_child(tr)
	menu3d.add_child(fo)
	# 小柯
	var rob := M.robot()
	rob.name = "Robot"
	rob.position = Vector3(0, 2.2, -0.6)
	rob.scale = Vector3.ONE * 0.8
	menu3d.add_child(rob)
	for k in 5:
		var cl := M.cloud(2.0)
		cl.position = Vector3(-9 + k * 4.5, 5 + (k % 2), -8)
		menu3d.add_child(cl)


func _process(_dt: float) -> void:
	if menu3d and is_instance_valid(menu3d):
		var t := Time.get_ticks_msec() / 1000.0
		var rob := menu3d.get_node_or_null("Robot") as Node3D
		if rob:
			rob.position.y = 2.2 + sin(t * 2.0) * 0.15
			rob.rotation.y = sin(t * 0.7) * 0.4
			var arm := rob.get_node("ArmR") as Node3D
			arm.rotation.z = 1.8 + sin(t * 6.0) * 0.5


# ================================================================ 標題
func show_title() -> void:
	P = Pal.menu()
	cur = "title"
	clear_screen()
	build_island(Vector3(0, 6.5, 12.5), Vector3(0, 0.5, 0))
	Snd.play_music("m01_island")
	var v := vbox(18)
	v.add_child(title_lbl("小柯機器人眼動探險島", 72))
	v.add_child(title_lbl("用眼睛看，就能玩的視知覺遊戲", 32, P.comp_light, P.dark))
	var sp := Control.new()
	sp.custom_minimum_size.y = 150
	v.add_child(sp)
	var h := hbox(22)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(btn("▶ 開始探險", P.comp, show_profiles, 36, Vector2(320, 120)))
	h.add_child(btn("📖 遊戲說明", P.base, func(): _help_page = 0; show_help(), 30, Vector2(250, 120)))
	h.add_child(btn("📊 評估報告", P.analog_a, func(): show_report(), 30, Vector2(250, 120)))
	h.add_child(btn("⚙ 設定", P.dark, show_settings, 30, Vector2(190, 120)))
	v.add_child(h)
	var cc := center(v)
	cc.offset_top = -40
	var foot := lbl("%s　｜　v%s　｜　%s" % [Gaze.status_text(), Game.APP_VERSION, Game.AUTHOR], 20, Color.WHITE)
	foot.add_theme_color_override("font_outline_color", P.dark)
	foot.add_theme_constant_override("outline_size", 6)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -44
	foot.name = "Foot"
	screen.add_child(foot)
	var q := btn("離開", P.dark, ask_quit, 24, Vector2(130, 80))
	q.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	q.position = Vector2(-150, 18)
	q.dwell_scale = 1.6
	screen.add_child(q)
	var ab := btn("關於／更新", P.analog_b, show_about, 22, Vector2(170, 80))
	ab.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ab.position = Vector2(20, 18)
	screen.add_child(ab)
	if not Gaze.link_changed.is_connected(_refresh_foot):
		Gaze.link_changed.connect(_refresh_foot)


func _refresh_foot(_v: bool) -> void:
	var f := screen.get_node_or_null("Foot") as Label
	if f:
		f.text = "%s　｜　v%s　｜　%s" % [Gaze.status_text(), Game.APP_VERSION, Game.AUTHOR]


func ask_quit() -> void:
	var p := panel()
	var v := vbox(20)
	v.add_child(lbl("要離開遊戲嗎？", 40))
	var h := hbox(30)
	h.add_child(btn("繼續玩", P.comp, func(): _close_modal(), 32, Vector2(240, 110)))
	h.add_child(btn("離開", P.dark, func(): Snd.say("bye"); await get_tree().create_timer(1.6).timeout; quit_game(), 32, Vector2(240, 110)))
	v.add_child(h)
	p.add_child(v)
	_modal(p)


func _modal(p: Control) -> void:
	for c in modal_layer.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	center(p, modal_layer)
	GazeButton.modal = modal_layer
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP


func _close_modal() -> void:
	for c in modal_layer.get_children():
		c.queue_free()
	GazeButton.modal = null
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ================================================================ 小朋友
func show_profiles(manage := false) -> void:
	P = Pal.menu()
	cur = "profiles"
	clear_screen()
	if not menu3d:
		build_island()
	Snd.say("pick_profile")
	var v := vbox(24)
	v.add_child(title_lbl("你是誰呢？", 56))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 20)
	for p in Game.profiles:
		var pp: Dictionary = p
		var t := "%s\n%d 歲　★ %d" % [pp.name, int(pp.age), _stars_of(str(pp.id))]
		var b := btn(t, P.base if Game.profiles.find(pp) % 2 == 0 else P.analog_a, func():
			if manage:
				_confirm_delete_profile(pp)
			else:
				Game.current = pp
				Game.save()
				show_map(), 30, Vector2(260, 140))
		if manage:
			b.text = "🗑 " + t
		g.add_child(b)
	if Game.profiles.size() < 12 and not manage:
		g.add_child(btn("＋\n新增小朋友", P.comp, _new_profile_form, 30, Vector2(260, 140)))
	v.add_child(g)
	var h := hbox(20)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if not Game.profiles.is_empty():
		h.add_child(btn("完成" if manage else "管理名單", P.dark, func(): show_profiles(not manage), 24, Vector2(200, 80)))
	h.add_child(btn("先玩玩看（訪客）", P.analog_b, func():
		Game.current = {"id": "guest", "name": "訪客", "age": 5, "color": "#80D8FF"}
		show_map(), 24, Vector2(260, 80)))
	v.add_child(h)
	center(v)
	back_btn(show_title)


func _stars_of(pid: String) -> int:
	var t := 0
	for k in Game.progress.get(pid, {}):
		t += int(Game.progress[pid][k])
	return t


func _confirm_delete_profile(p: Dictionary) -> void:
	var pn := panel()
	var v := vbox(20)
	v.add_child(lbl("要刪除「%s」嗎？\n過關星星會一起刪除（評估紀錄仍保留在電腦裡）。" % p.name, 30))
	var h := hbox(30)
	h.add_child(btn("取消", P.dark, _close_modal, 28))
	h.add_child(btn("刪除", P.dark, func(): Game.remove_profile(str(p.id)); _close_modal(); show_profiles(true), 28))
	v.add_child(h)
	pn.add_child(v)
	_modal(pn)


func _new_profile_form() -> void:
	var pn := panel()
	var v := vbox(18)
	v.add_child(lbl("新增小朋友（請家長或老師幫忙輸入名字）", 30))
	var le := LineEdit.new()
	le.placeholder_text = "名字或暱稱"
	le.add_theme_font_size_override("font_size", 34)
	le.custom_minimum_size = Vector2(520, 72)
	le.max_length = 12
	v.add_child(le)
	var age := [5]
	var al := lbl("年齡：5 歲", 34)
	var h := hbox(20)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(btn("－", P.analog_b, func(): age[0] = maxi(2, age[0] - 1); al.text = "年齡：%d 歲" % age[0], 40, Vector2(110, 90)))
	h.add_child(al)
	h.add_child(btn("＋", P.base, func(): age[0] = mini(12, age[0] + 1); al.text = "年齡：%d 歲" % age[0], 40, Vector2(110, 90)))
	v.add_child(h)
	v.add_child(lbl("建議難度會依照年齡自動標示", 22, P.dark))
	var h2 := hbox(30)
	h2.alignment = BoxContainer.ALIGNMENT_CENTER
	h2.add_child(btn("取消", P.dark, _close_modal, 28))
	h2.add_child(btn("確定", P.comp, func():
		var nm := le.text.strip_edges()
		if nm == "":
			nm = "小朋友 %d" % (Game.profiles.size() + 1)
		Game.add_profile(nm, age[0])
		_close_modal()
		show_map(), 28))
	v.add_child(h2)
	pn.add_child(v)
	_modal(pn)
	le.grab_focus()


# ================================================================ 探險島地圖
func show_map() -> void:
	P = Pal.menu()
	cur = "map"
	clear_screen()
	build_island()
	Snd.play_music("m01_island")
	Snd.say("pick_park")
	var top := title_lbl("%s 的探險島　★ %d / 90" % [Game.pname(), Game.total_stars()], 40)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 24
	screen.add_child(top)
	back_btn(show_profiles)
	# 五座樂園按鈕：固定排在地標附近（不重疊）
	var spots := {"rainbow": Vector2(0.14, 0.50), "blocks": Vector2(0.30, 0.20), "juice": Vector2(0.70, 0.20),
		"ocean": Vector2(0.86, 0.50), "forest": Vector2(0.50, 0.84)}
	for p in Data.PARKS:
		var pp: Dictionary = p
		var got := 0
		for lv in Data.park_levels(pp.id):
			got += Game.stars(lv.id)
		var b := btn("%s
%s　★%d/18" % [pp.name, pp.skill, got], Pal.park_color(pp.id), func(): show_park(pp.id), 24, Vector2(300, 112))
		var sp: Vector2 = spots[pp.id]
		b.set_anchors_preset(Control.PRESET_TOP_LEFT)
		b.anchor_left = sp.x
		b.anchor_right = sp.x
		b.anchor_top = sp.y
		b.anchor_bottom = sp.y
		b.offset_left = -150
		b.offset_right = 150
		b.offset_top = -56
		b.offset_bottom = 56
		screen.add_child(b)


# ================================================================ 樂園（6 關）
func show_park(pid: String) -> void:
	cur = "park"
	cur_park = pid
	P = Pal.park(pid)
	clear_screen()
	var p := Data.park(pid)
	build_island(ISLAND_POS[pid] + Vector3(0, 4.5, 6.5), ISLAND_POS[pid] + Vector3(0, 0.8, 0))
	Snd.play_music(p.music)
	Snd.say(["park_" + pid, "pick_level"])
	var pn := panel(Color(1, 1, 1, 0.92))
	var v := vbox(14)
	v.add_child(title_lbl(p.name, 50, Color.WHITE, P.dark))
	v.add_child(lbl("訓練目標：%s｜%s" % [p.skill, p.goal], 24, P.text))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 14)
	var sug := Game.suggested_diff()
	for d in 3:
		var dl := lbl("%s\n%s%s" % [Data.DIFF_NAMES[d], Data.DIFF_AGES[d], "\n👍 建議" if d == sug else ""], 24, Pal.diff_color(P.base, d).darkened(0.3))
		dl.custom_minimum_size = Vector2(150, 0)
		g.add_child(dl)
		for gid in p.games:
			var gi: Dictionary = Data.GAMES[gid]
			var lid := "%s_%d" % [gid, d]
			var no: int = d * 2 + int(p.games.find(gid)) + 1
			var gg: String = gid
			var dd := d
			var b := btn("第 %d 關　%s\n%s" % [no, gi.name, stars_text(Game.stars(lid))], Pal.diff_color(P.base, d), func(): start_level(gg, dd), 24, Vector2(380, 104))
			if d == sug:
				b.text = "👍 " + b.text
			g.add_child(b)
	v.add_child(g)
	pn.add_child(v)
	var cc := center(pn)
	cc.offset_top = 40
	back_btn(show_map)


# ================================================================ 關卡
func start_level(gid: String, d: int) -> void:
	if not Data.GAMES.has(gid):
		push_error("沒有這個遊戲：" + gid)
		return
	cur = "level"
	cur_game = gid
	cur_diff = d
	cur_park = Data.GAMES[gid].park
	P = Pal.park(cur_park)
	clear_screen()
	clear_world()
	var info := Data.game_info(gid)
	var scr: GDScript = load(info.script)
	level = scr.new()
	level.setup(info, d)
	level.autoplay = args.has("autoplay")
	if args.has("wrong"):
		level.wrong_rate = float(args.wrong)
	world.add_child(level)
	level.finished.connect(_on_level_finished)
	level.pause_requested.connect(show_pause)
	Snd.play_music(Data.park(cur_park).music)
	if args.has("play"):
		_begin(args.has("demo"))
	else:
		show_intro()


func show_intro() -> void:
	var info := Data.game_info(cur_game)
	var pn := panel()
	var v := vbox(16)
	v.custom_minimum_size.x = 760
	v.add_child(title_lbl(info.name, 52, Color.WHITE, P.dark))
	v.add_child(lbl("%s｜%s（%s）" % [Data.park(cur_park).name, Data.DIFF_NAMES[cur_diff], Data.DIFF_AGES[cur_diff]], 26, Pal.diff_color(P.base, cur_diff).darkened(0.2)))
	v.add_child(lbl(info.desc, 30))
	v.add_child(lbl("這一關：" + str(info.levels[cur_diff]), 26, P.text))
	var h := hbox(24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var first := not Game.demo_seen(cur_game)
	h.add_child(btn("▶ 開始" + ("（先看示範）" if first else ""), P.comp, func(): _close_modal(); _begin(first), 30, Vector2(330, 110)))
	if not first:
		h.add_child(btn("👀 看示範", P.base, func(): _close_modal(); _begin(true), 28, Vector2(220, 110)))
	h.add_child(btn("返回", P.dark, func(): show_park(cur_park), 28, Vector2(160, 110)))
	v.add_child(h)
	pn.add_child(v)
	_modal(pn)
	var vid := "intro_" + cur_game
	Snd.say(vid if Snd.has_voice(vid) else [])


func _begin(demo_first: bool) -> void:
	if demo_first:
		Game.mark_demo(cur_game)
	if args.has("shots"):
		_shots_during_level()
	level.begin(demo_first)


func _shots_during_level() -> void:
	# 測試：每回合可以作答時拍一張
	var seen := -1
	while level and is_instance_valid(level) and cur == "level":
		if level.answering and level.round_i != seen and not level.demo:
			seen = level.round_i
			await get_tree().create_timer(0.7).timeout
			await shot("%s_%d_r%d" % [cur_game, cur_diff, seen + 1])
		await get_tree().process_frame


func show_pause() -> void:
	if not level or GazeButton.modal:
		return
	level.paused = true
	get_tree().paused = false
	Snd.say("paused")
	var pn := panel()
	var v := vbox(18)
	v.add_child(lbl("暫停中", 46))
	for item in [["▶ 繼續玩", P.comp, func(): _close_modal(); level.paused = false],
			["🔁 重新開始這一關", P.base, func(): start_level(cur_game, cur_diff)],
			["🔊 再聽一次說明", P.analog_a, func(): level.replay_prompt()],
			["🏠 回到樂園", P.dark, func(): show_park(cur_park)]]:
		v.add_child(btn(item[0], item[1], item[2], 30, Vector2(420, 96)))
	pn.add_child(v)
	_modal(pn)


func _on_level_finished(result: Dictionary) -> void:
	last_result = result
	Game.set_stars(result.level, int(result.stars))
	last_record_dir = Game.save_record(result, level.shots if level else [])
	show_result(result)
	if args.has("quit") and args.has("play"):
		await get_tree().create_timer(1.5).timeout
		await shot("result")
		var m := Report.record_metrics(result)
		print("RESULT ", result.level, " stars=", result.stars, " errors=", result.errors, " dur=", result.duration,
			" rounds=", result.rounds.size(), " metrics=", m, " dir=", last_record_dir)
		if str(args.get("then", "")) == "report":
			show_report()
			await get_tree().create_timer(1.5).timeout
			await shot("report")
			_report_mode = "numbered"
			_refresh_report_detail()
			await get_tree().create_timer(0.5).timeout
			await shot("report_numbered")
			if args.has("export"):
				var path := await export_html(_records.slice(0, 1))
				print("EXPORT ", path)
		get_tree().quit()


func show_result(r: Dictionary) -> void:
	cur = "result"
	var st := int(r.stars)
	Snd.play("fanfare")
	Snd.say(["level_done", "stars%d" % st])
	var pn := panel()
	var v := vbox(14)
	v.custom_minimum_size.x = 700
	v.add_child(title_lbl("過關了！", 60, Color.WHITE, P.dark))
	var sl := lbl(stars_text(st), 90, P.analog_a)
	v.add_child(sl)
	sl.pivot_offset = Vector2(350, 60)
	sl.scale = Vector2.ONE * 0.3
	create_tween().tween_property(sl, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	var m := Report.record_metrics(r)
	var info := "%s（%s）\n用了 %d 秒　平均每題 %.1f 秒　答錯 %d 次" % [r.title, Data.DIFF_NAMES[int(r.diff)], int(r.duration), m.avg_time, int(r.errors)]
	if int(r.hints) > 0:
		info += "　提示 %d 次" % int(r.hints)
	if float(r.coverage) >= 0.0:
		info += "\n答對時平均露出 %s" % Report.fmt_pct(float(r.coverage))
	v.add_child(lbl(info, 28))
	var h := hbox(18)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(btn("🔁 再玩一次", P.base, func(): start_level(cur_game, cur_diff), 26, Vector2(210, 100)))
	var nxt := _next_level()
	if not nxt.is_empty():
		h.add_child(btn("▶ 下一關", P.comp, func(): start_level(nxt.game, nxt.diff), 26, Vector2(200, 100)))
	h.add_child(btn("📊 看報告", P.analog_a, func(): show_report(), 26, Vector2(200, 100)))
	h.add_child(btn("🏠 樂園", P.dark, func(): show_park(cur_park), 26, Vector2(170, 100)))
	v.add_child(h)
	pn.add_child(v)
	_modal(pn)
	var bm := float(Game.settings.break_min)
	if bm > 0.0 and Game.minutes_played() - _last_rest_min >= bm and not args.has("test"):
		_last_rest_min = Game.minutes_played()
		await get_tree().create_timer(3.5).timeout
		if cur == "result":
			show_rest()


func _next_level() -> Dictionary:
	var lv := Data.park_levels(cur_park)
	for i in lv.size():
		if lv[i].game == cur_game and int(lv[i].diff) == cur_diff and i + 1 < lv.size():
			return lv[i + 1]
	return {}


func show_rest() -> void:
	Snd.say("rest")
	Snd.play_music("m08_lullaby")
	var pn := panel(P.bar)
	var v := vbox(18)
	v.add_child(lbl("🌙 休息一下", 52, P.dark))
	v.add_child(lbl("閉上眼睛數到十，\n或是看看窗外遠遠的地方。", 34))
	var cnt := lbl("20", 60, P.base)
	v.add_child(cnt)
	v.add_child(btn("休息好了", P.comp, func(): _close_modal(); show_park(cur_park), 30, Vector2(280, 100)))
	pn.add_child(v)
	_modal(pn)
	for i in range(19, -1, -1):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(cnt):
			return
		cnt.text = str(i)


# ================================================================ 遊戲說明
func show_help() -> void:
	P = Pal.menu()
	cur = "help"
	clear_screen()
	if not menu3d:
		build_island()
	var page: Array = Data.HELP[_help_page]
	Snd.say("help_%02d" % _help_page)
	var pn := panel(Color(1, 1, 1, 0.95))
	var v := vbox(16)
	v.custom_minimum_size = Vector2(1000, 0)
	v.add_child(lbl("遊戲說明 %d / %d" % [_help_page + 1, Data.HELP.size()], 22, P.dark))
	v.add_child(title_lbl(page[0], 48))
	var h := hbox(24)
	var art := HelpArt.new()
	art.page = _help_page
	art.custom_minimum_size = Vector2(380, 300)
	h.add_child(art)
	var body := lbl(page[1], 30, P.text, HORIZONTAL_ALIGNMENT_LEFT)
	body.custom_minimum_size = Vector2(560, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(body)
	v.add_child(h)
	var nav := hbox(20)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := btn("◀ 上一頁", P.base, func(): _help_page -= 1; show_help(), 26, Vector2(200, 90))
	prev.disabled = _help_page == 0
	nav.add_child(prev)
	nav.add_child(btn("🔊 再聽一次", P.analog_a, func(): Snd.say("help_%02d" % _help_page), 26, Vector2(200, 90)))
	if _help_page < Data.HELP.size() - 1:
		nav.add_child(btn("下一頁 ▶", P.base, func(): _help_page += 1; show_help(), 26, Vector2(200, 90)))
	else:
		nav.add_child(btn("看完了 ✔", P.comp, show_title, 26, Vector2(200, 90)))
	v.add_child(nav)
	pn.add_child(v)
	center(pn)
	back_btn(func(): Snd.stop_voice(); show_title())


# ================================================================ 設定
func show_settings() -> void:
	P = Pal.menu()
	cur = "settings"
	clear_screen()
	if not menu3d:
		build_island()
	var pn := panel(Color(1, 1, 1, 0.95))
	var v := vbox(10)
	v.custom_minimum_size.x = 1080
	v.add_child(title_lbl("設定", 46))
	var s := Game.settings
	v.add_child(_num_row("看多久選取", func(): return "%.1f 秒" % (float(s.dwell_ms) / 1000.0),
		func(dv): s.dwell_ms = clampi(int(s.dwell_ms) + dv * 200, 400, 4000)))
	v.add_child(_num_row("游標大小", func(): return str(int(s.cursor_size)),
		func(dv): s.cursor_size = clampi(int(s.cursor_size) + dv * 8, 24, 140)))
	v.add_child(_num_row("音樂音量", func(): return "%d%%" % roundi(Snd.music_vol * 100),
		func(dv): Snd.set_music_vol(clampf(Snd.music_vol + dv * 0.1, 0.0, 1.0))))
	v.add_child(_num_row("音效音量", func(): return "%d%%" % roundi(Snd.sfx_vol * 100),
		func(dv): Snd.sfx_vol = clampf(Snd.sfx_vol + dv * 0.1, 0.0, 1.0); Snd.play("pop")))
	v.add_child(_num_row("語音音量", func(): return "%d%%" % roundi(Snd.voice_vol * 100),
		func(dv): Snd.voice_vol = clampf(Snd.voice_vol + dv * 0.1, 0.0, 1.0); Snd.say("good2")))
	v.add_child(_num_row("休息提醒", func(): return "不提醒" if int(s.break_min) == 0 else "每 %d 分鐘" % int(s.break_min),
		func(dv): s.break_min = clampi(int(s.break_min) + dv * 5, 0, 60)))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 10)
	for t in [["show_cursor", "顯示視線星星"], ["magnet", "靠近目標自動吸附"], ["click_ok", "也可以用滑鼠點"],
			["auto_eyemouse", "自動啟動眼動鼠"], ["record_gaze", "記錄視線軌跡"], ["_fullscreen", "全螢幕"]]:
		g.add_child(_toggle(t[0], t[1]))
	v.add_child(g)
	var st := lbl("眼動鼠：" + Gaze.status_text(), 22, P.text)
	v.add_child(st)
	var h := hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if not Gaze.linked and Gaze.eyemouse_exe() != "":
		h.add_child(btn("啟動眼動鼠", P.analog_b, func(): Gaze.launch_eyemouse(), 24, Vector2(220, 80)))
	h.add_child(btn("儲存並返回", P.comp, func(): Game.save(); Snd.save_settings(); show_title(), 26, Vector2(260, 80)))
	v.add_child(h)
	pn.add_child(v)
	center(pn)
	back_btn(func(): Game.save(); Snd.save_settings(); show_title())


func _num_row(name_: String, getter: Callable, setter: Callable) -> HBoxContainer:
	var h := hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := lbl(name_, 28, P.text, HORIZONTAL_ALIGNMENT_RIGHT)
	l.custom_minimum_size.x = 220
	h.add_child(l)
	var val := lbl(getter.call(), 30, P.base)
	val.custom_minimum_size.x = 200
	h.add_child(btn("－", P.analog_b, func(): setter.call(-1); val.text = getter.call(), 34, Vector2(100, 70)))
	h.add_child(val)
	h.add_child(btn("＋", P.base, func(): setter.call(1); val.text = getter.call(), 34, Vector2(100, 70)))
	return h


func _toggle(key: String, name_: String) -> GazeButton:
	var get_v := func() -> bool: return Snd.fullscreen if key == "_fullscreen" else bool(Game.settings[key])
	var b := btn("", P.comp, func(): pass, 24, Vector2(330, 76))
	var refresh := func():
		var on: bool = get_v.call()
		b.text = ("✅ " if on else "⬜ ") + name_
		GazeButton.style(b, P.comp if on else P.light)
	b.pressed.connect(func():
		if key == "_fullscreen":
			Snd.fullscreen = not Snd.fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Snd.fullscreen else DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			Game.settings[key] = not bool(Game.settings[key])
		refresh.call())
	refresh.call()
	return b


# ================================================================ 關於／更新
func show_about() -> void:
	P = Pal.menu()
	cur = "about"
	clear_screen()
	if not menu3d:
		build_island()
	var pn := panel(Color(1, 1, 1, 0.95))
	var v := vbox(14)
	v.custom_minimum_size.x = 900
	v.add_child(title_lbl(Game.APP_NAME, 46))
	v.add_child(lbl("版本 %s（%s）" % [Game.APP_VERSION, Updater.platform_name()], 28))
	v.add_child(lbl(Game.AUTHOR, 28))
	v.add_child(lbl("搭配「眼動鼠 EyeMouse」使用：眼動鼠負責讀取 Tobii 眼動儀或攝影機的視線，遊戲負責 3D 關卡、停留選取與評估報告。\n本遊戲為視知覺練習用的教育遊戲，評估報告僅供家長、老師與治療師參考，不能取代專業評估。", 24, P.text))
	var ul := lbl("", 26, P.base)
	ul.name = "UpdLabel"
	v.add_child(ul)
	var h := hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(btn("檢查更新", P.analog_b, func(): ul.text = "檢查中…"; Updater.check(), 26, Vector2(220, 86)))
	v.add_child(h)
	pn.add_child(v)
	center(pn)
	back_btn(show_title)
	if not Updater.failed.is_connected(_on_update_failed):
		Updater.failed.connect(_on_update_failed)
		Updater.progress.connect(func(_r, t): _set_upd_text(t))


func _set_upd_text(t: String) -> void:
	var ul := screen.find_child("UpdLabel", true, false) as Label
	if ul:
		ul.text = t


func _on_update_failed(msg: String) -> void:
	_set_upd_text(msg)


func _on_update_checked(has: bool, latest: String, notes: String) -> void:
	if cur == "about":
		_set_upd_text(("有新版本 %s！\n%s" % [latest, notes]) if has else "已經是最新版本（%s）" % Updater.current_version())
	if has and (cur == "about" or cur == "title"):
		var pn := panel()
		var v := vbox(18)
		v.add_child(lbl("有新版本 %s" % latest, 38))
		v.add_child(lbl(notes, 24, P.text))
		var h := hbox(20)
		h.add_child(btn("以後再說", P.dark, _close_modal, 26))
		h.add_child(btn("立即更新", P.comp, func(): _close_modal(); show_about(); Updater.apply_update(), 26))
		v.add_child(h)
		pn.add_child(v)
		_modal(pn)


# ================================================================ 評估報告
func show_report() -> void:
	P = Pal.menu()
	cur = "report"
	clear_screen()
	clear_world()
	Snd.play_music("m07_stars")
	if Game.current.is_empty():
		show_profiles()
		return
	Snd.say("report")
	_records = Game.list_records()
	var bg := ColorRect.new()
	bg.color = P.bar
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var root := vbox(10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 16
	root.offset_bottom = -16
	screen.add_child(root)
	var top := hbox(14)
	top.add_child(btn("◀ 返回", P.dark, func(): show_title() if last_result.is_empty() else show_park(cur_park), 24, Vector2(150, 70)))
	var t := lbl("%s 的眼動評估報告（共 %d 筆）" % [Game.pname(), _records.size()], 34, P.text, HORIZONTAL_ALIGNMENT_LEFT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	if not _records.is_empty():
		top.add_child(btn("匯出網頁報告", P.analog_a, func(): _do_export(), 22, Vector2(210, 70)))
		top.add_child(btn("開啟資料夾", P.base, func(): OS.shell_open(ProjectSettings.globalize_path(Game.records_dir())), 22, Vector2(180, 70)))
	root.add_child(top)
	if _records.is_empty():
		root.add_child(lbl("還沒有紀錄。玩完一關就會自動產生報告。", 30))
		return
	var body := hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.x = 360
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var list := vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	_report_sel = clampi(_report_sel, 0, _records.size() - 1)
	for i in _records.size():
		var r: Dictionary = _records[i]
		var k := i
		var b := btn("%s\n%s %s" % [Data.level_title(str(r.level)), str(r.date).replace("T", " ").substr(5, 11), stars_text(int(r.stars))],
			Pal.park_color(str(r.park)).darkened(0.0 if i != _report_sel else 0.3),
			func(): _report_sel = k; _report_round = 0; show_report(), 20, Vector2(330, 76))
		b.dwell_scale = 1.5
		list.add_child(b)
	var detail := vbox(8)
	detail.name = "Detail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail)
	_refresh_report_detail()


func _refresh_report_detail() -> void:
	var detail := screen.find_child("Detail", true, false) as VBoxContainer
	if not detail or _records.is_empty():
		return
	for c in detail.get_children():
		c.queue_free()
	var r: Dictionary = _records[_report_sel]
	var m := Report.record_metrics(r)
	var scr: Array = r.get("screen", [1280, 720])
	var aspect := float(scr[0]) / maxf(1.0, float(scr[1]))
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 18)
	var cells := [
		["關卡", Data.level_title(str(r.level))], ["日期", str(r.date).replace("T", " ")], ["星星", stars_text(int(r.stars))],
		["作答總時間", Report.fmt_s(float(r.duration))], ["平均每題", Report.fmt_s(m.avg_time)], ["錯誤次數", "%d 次" % int(r.errors)],
		["提示次數", "%d 次" % int(r.hints)], ["答對覆蓋率", Report.fmt_pct(float(r.coverage))], ["視線有效率", Report.fmt_pct(m.valid)],
		["注視點數", str(m.fixations)], ["視線路徑長", "%.1f 個畫面寬" % m.path], ["來回比對（平均）", "%.1f 次" % m.avg_switch],
		["首次看到目標", Report.fmt_s(m.first_target)], ["視線來源", {"eyemouse": "眼動鼠", "mouse": "滑鼠", "bot": "自動測試"}.get(str(r.gaze_source), str(r.gaze_source))],
		["停留時間", "%.1f 秒" % (float(r.dwell_ms) / 1000.0)],
	]
	for c in cells:
		var k := lbl(str(c[0]), 18, P.dark, HORIZONTAL_ALIGNMENT_RIGHT)
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		g.add_child(k)
		var vl := lbl(str(c[1]), 20, P.text, HORIZONTAL_ALIGNMENT_LEFT)
		vl.autowrap_mode = TextServer.AUTOWRAP_OFF
		vl.custom_minimum_size.x = 170
		g.add_child(vl)
	detail.add_child(g)
	var rounds: Array = r.get("rounds", [])
	if rounds.is_empty():
		return
	_report_round = clampi(_report_round, 0, rounds.size() - 1)
	var rd: Dictionary = rounds[_report_round]
	var rm := Report.round_metrics(rd, aspect)
	var bar := hbox(10)
	var pv := btn("◀", P.base, func(): _report_round -= 1; _refresh_report_detail(), 24, Vector2(70, 60))
	pv.disabled = _report_round == 0
	bar.add_child(pv)
	var rl := lbl("第 %d / %d 回合" % [_report_round + 1, rounds.size()], 24)
	rl.autowrap_mode = TextServer.AUTOWRAP_OFF
	bar.add_child(rl)
	var nx := btn("▶", P.base, func(): _report_round += 1; _refresh_report_detail(), 24, Vector2(70, 60))
	nx.disabled = _report_round >= rounds.size() - 1
	bar.add_child(nx)
	bar.add_child(btn("一般版（路徑）", P.base if _report_mode == "path" else P.light, func(): _report_mode = "path"; _refresh_report_detail(), 20, Vector2(180, 60)))
	bar.add_child(btn("數字版（注視順序）", P.dark if _report_mode == "numbered" else P.light, func(): _report_mode = "numbered"; _refresh_report_detail(), 20, Vector2(210, 60)))
	var info := lbl("時間 %s｜錯 %d｜注視 %d 個｜路徑 %.2f｜比對 %d 次｜看過 %d 個物件%s" % [Report.fmt_s(float(rd.time)), int(rd.errors), rm.fixations, rm.path, rm.switches, rm.visited,
		("｜露出 " + Report.fmt_pct(float(rd.coverage))) if float(rd.coverage) >= 0.0 else ""], 20, P.text, HORIZONTAL_ALIGNMENT_LEFT)
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	for c in bar.get_children():
		(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail.add_child(bar)
	detail.add_child(info)
	var tv := TrailView.new()
	tv.mode = _report_mode
	tv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(tv)
	var img_path := str(r._dir).path_join("round_%d.jpg" % (_report_round + 1))
	var tex: Texture2D = null
	if FileAccess.file_exists(img_path):
		var img := Image.load_from_file(img_path)
		if img:
			tex = ImageTexture.create_from_image(img)
	tv.set_data(tex, rd, aspect)
	var legend := lbl("綠圈＝正確目標、白圈＝其他物件；一般版顯示視線路徑（綠「起」→紅「終」，顏色由藍變紅），數字版顯示注視點的先後順序（圓越大看越久）。路徑越短、來回比對越少，代表搜尋越有效率。", 18, P.dark, HORIZONTAL_ALIGNMENT_LEFT)
	legend.custom_minimum_size.x = 400
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(legend)


func _do_export() -> void:
	var pn := panel()
	var l := lbl("正在產生報告…", 34)
	pn.add_child(l)
	_modal(pn)
	var path := await export_html(_records)
	_close_modal()
	if path != "":
		OS.shell_open(path)


## 匯出網頁報告（含每回合軌跡圖），回傳 index.html 路徑
func export_html(recs: Array) -> String:
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs == "":
		docs = OS.get_user_data_dir()
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var dir := docs.path_join("小柯眼動探險島報告").path_join("%s_%s" % [Game.pname().validate_filename(), stamp])
	DirAccess.make_dir_recursive_absolute(dir)
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var tv := TrailView.new()
	tv.size = Vector2(960, 540)
	vp.add_child(tv)
	var h := PackedStringArray()
	h.append("<!doctype html><html lang='zh-Hant'><head><meta charset='utf-8'><title>眼動評估報告</title><style>")
	h.append("body{font-family:'Microsoft JhengHei',sans-serif;background:#f8f9fa;color:#212529;margin:24px}h1{color:#1c7ed6}")
	h.append(".rec{background:#fff;border-radius:16px;padding:16px 20px;margin:18px 0;box-shadow:0 2px 8px #0002}")
	h.append("table{border-collapse:collapse;margin:8px 0}td,th{border:1px solid #dee2e6;padding:6px 10px;text-align:center}th{background:#e7f5ff}")
	h.append(".imgs{display:flex;gap:10px;flex-wrap:wrap}.imgs figure{margin:0}.imgs img{width:460px;border-radius:8px;border:1px solid #ced4da}figcaption{font-size:14px;color:#495057}")
	h.append(".note{color:#868e96;font-size:14px}</style></head><body>")
	h.append("<h1>%s 的眼動評估報告</h1><p>年齡 %s 歲｜產生時間 %s｜%s v%s</p>" % [Game.pname().xml_escape(), str(Game.current.get("age", "")), Time.get_datetime_string_from_system().replace("T", " "), Game.APP_NAME, Game.APP_VERSION])
	h.append("<table><tr><th>日期</th><th>關卡</th><th>星星</th><th>總時間</th><th>平均每題</th><th>錯誤</th><th>提示</th><th>答對覆蓋率</th><th>注視點</th><th>路徑長</th><th>平均比對</th><th>首次看到目標</th></tr>")
	for r in recs:
		var m := Report.record_metrics(r)
		h.append("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%d</td><td>%d</td><td>%s</td><td>%d</td><td>%.1f</td><td>%.1f</td><td>%s</td></tr>" % [
			str(r.date).replace("T", " "), Data.level_title(str(r.level)), stars_text(int(r.stars)), Report.fmt_s(float(r.duration)), Report.fmt_s(m.avg_time),
			int(r.errors), int(r.hints), Report.fmt_pct(float(r.coverage)), m.fixations, m.path, m.avg_switch, Report.fmt_s(m.first_target)])
	h.append("</table>")
	var idx := 0
	for r in recs:
		idx += 1
		var scr: Array = r.get("screen", [1280, 720])
		var aspect := float(scr[0]) / maxf(1.0, float(scr[1]))
		h.append("<div class='rec'><h2>%d. %s　%s</h2>" % [idx, Data.level_title(str(r.level)), str(r.date).replace("T", " ")])
		h.append("<table><tr><th>回合</th><th>時間</th><th>錯誤</th><th>提示</th><th>露出比例</th><th>注視點</th><th>路徑長</th><th>來回比對</th><th>看過物件</th><th>首次看到目標</th></tr>")
		var rounds: Array = r.get("rounds", [])
		for rd in rounds:
			var rm := Report.round_metrics(rd, aspect)
			h.append("<tr><td>%d</td><td>%s</td><td>%d</td><td>%d</td><td>%s</td><td>%d</td><td>%.2f</td><td>%d</td><td>%d</td><td>%s</td></tr>" % [
				int(rd.round), Report.fmt_s(float(rd.time)), int(rd.errors), int(rd.hints), Report.fmt_pct(float(rd.coverage)), rm.fixations, rm.path, rm.switches, rm.visited, Report.fmt_s(rm.first_target)])
		h.append("</table><div class='imgs'>")
		for k in rounds.size():
			var img_path := str(r._dir).path_join("round_%d.jpg" % (k + 1))
			var tex: Texture2D = null
			if FileAccess.file_exists(img_path):
				var img := Image.load_from_file(img_path)
				if img:
					tex = ImageTexture.create_from_image(img)
			for md in ["path", "numbered"]:
				tv.mode = md
				vp.size = Vector2i(960, int(960 / aspect))
				tv.size = Vector2(vp.size)
				tv.set_data(tex, rounds[k], aspect)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var out := vp.get_texture().get_image()
				var fname := "r%02d_%d_%s.png" % [idx, k + 1, md]
				out.save_png(dir.path_join(fname))
				h.append("<figure><img src='%s'><figcaption>第 %d 回合｜%s</figcaption></figure>" % [fname, k + 1, "一般版（路徑、起迄點）" if md == "path" else "數字版（注視順序）"])
		h.append("</div></div>")
	h.append("<p class='note'>指標說明：注視點以 I-DT 演算法（散布 3.5%% 畫面寬、至少 0.1 秒）計算；路徑長以畫面寬為 1；來回比對次數＝視線在不同物件之間切換的次數；答對覆蓋率＝答對時目標露出的比例（越低代表完形能力越好）。本報告僅供參考，不能取代專業評估。</p>")
	h.append("<p class='note'>%s</p></body></html>" % Game.AUTHOR)
	vp.queue_free()
	var f := FileAccess.open(dir.path_join("index.html"), FileAccess.WRITE)
	if not f:
		return ""
	f.store_string("\n".join(h))
	f.close()
	return dir.path_join("index.html")
