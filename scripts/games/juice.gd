extends Level
## 小柯果汁吧｜果汁配方（視覺記憶＋順序記憶）
## 配方板上的水果一個一個出現，記住順序；配方蓋起來後，照順序把水果放進果汁機。

const VOICE := {
	"juice_watch": "看配方，記住水果出現的順序。",
	"juice_cover": "配方蓋起來囉，想一想剛才的順序。",
	"juice_pick": "照順序把水果放進果汁機。",
	"juice_blend": "果汁機轉轉轉，果汁做好囉！",
}

const RECIPE_N := [2, 3, 4]
const SHELF_N := [4, 6, 8]
const BOARD_POS := Vector3(-0.3, 1.78, -0.4)
const BLENDER_POS := Vector3(5.3, 0.2, 0)
const CUP_POS := Vector3(5.3, -2.75, 0.3)
const SLOT_GAP := 1.6
const FRUIT_SCALE := 0.62
const SHELF_SCALE := 0.68

var blade: Node3D
var lid: Node3D
var blender: Node3D
var jar_fill: Node3D
var jar_fill_mesh: MeshInstance3D
var cup_fill: Node3D
var cup_fill_mesh: MeshInstance3D
var stream: MeshInstance3D

var recipe: Array = []
var step := 0
var shelf := {}          # kind -> Node3D
var slots: Array = []    # 每格的位置
var covers: Array = []   # 每格的蓋子
var chunks: Array = []   # 果汁機裡的水果塊


# ---------------------------------------------------------------- 佈置
func build() -> void:
	var deco: Array = [theme.base, theme.analog_a, theme.light, theme.analog_b]
	# 上方條紋遮陽篷
	for i in 30:
		var c: Color = theme.base if i % 2 == 0 else theme.bar
		add_child(M.box(Vector3(0.9, 1.1, 0.15), c, Vector3(-13.05 + i * 0.9, 5.25, -8.7)))
		add_child(M.sphere(0.45, c, Vector3(-13.05 + i * 0.9, 4.7, -8.6), Vector3(1, 0.7, 0.3)))
	# 後方牆上的果汁瓶架
	for side in [-1]:
		var sx: float = side * 10.5
		add_child(M.box(Vector3(5.0, 0.18, 1.0), theme.dark, Vector3(sx, 0.2, -8.2)))
		for k in 4:
			var bc: Color = deco[(k + (0 if side < 0 else 2)) % deco.size()]
			var bx := sx - 1.8 + k * 1.2
			add_child(M.cyl(0.32, 0.36, 1.1, bc, Vector3(bx, 0.85, -8.2)))
			add_child(M.cyl(0.14, 0.2, 0.35, bc.darkened(0.2), Vector3(bx, 1.55, -8.2)))
	# 吧台
	var counter := M.box(Vector3(40, 0.9, 2.2), theme.dark.lightened(0.15), Vector3(0, -4.25, -1.8))
	add_child(counter)
	add_child(M.box(Vector3(40, 0.14, 2.3), theme.base, Vector3(0, -3.75, -1.8)))
	# 配方板
	var board := Node3D.new()
	board.position = BOARD_POS
	add_child(board)
	board.add_child(M.box(Vector3(8.5, 1.85, 0.12), theme.base, Vector3(0, 0, -0.08)))
	board.add_child(M.box(Vector3(8.2, 1.6, 0.14), Color(theme.bar), Vector3.ZERO))
	for sx in [-3.9, 3.9]:
		board.add_child(M.sphere(0.13, theme.analog_a, Vector3(sx, 0.62, 0.1)))
	# 果汁機
	blender = _blender()
	blender.position = BLENDER_POS
	add_child(blender)
	stream = M.cyl(0.07, 0.07, 1.0, theme.light, Vector3(BLENDER_POS.x, -1.75, 0.35))
	stream.visible = false
	add_child(stream)
	var cup := _cup()
	cup.position = CUP_POS
	add_child(cup)


func _blender() -> Node3D:
	var n := Node3D.new()
	var oc: Color = theme.base
	n.add_child(M.box(Vector3(1.45, 0.75, 1.1), oc, Vector3(0, -1.2, 0)))
	n.add_child(M.box(Vector3(1.3, 0.12, 1.0), oc.darkened(0.25), Vector3(0, -0.8, 0)))
	for k in 3:
		var b := M.sphere(0.09, [theme.bar, theme.analog_a, theme.comp][k], Vector3(-0.35 + k * 0.35, -1.2, 0.56), Vector3(1, 1, 0.5))
		n.add_child(b)
	blade = Node3D.new()
	blade.position = Vector3(0, -0.6, 0)
	n.add_child(blade)
	blade.add_child(M.box(Vector3(0.75, 0.04, 0.14), theme.light.darkened(0.25)))
	blade.add_child(M.box(Vector3(0.14, 0.04, 0.75), theme.light.darkened(0.25)))
	blade.add_child(M.cyl(0.05, 0.05, 0.2, theme.dark, Vector3(0, -0.08, 0)))
	jar_fill = Node3D.new()
	jar_fill.position = Vector3(0, -0.72, 0)
	jar_fill.scale = Vector3(1, 0.01, 1)
	n.add_child(jar_fill)
	jar_fill_mesh = M.cyl(0.55, 0.43, 1.55, theme.base, Vector3(0, 0.775, 0))
	jar_fill.add_child(jar_fill_mesh)
	var jar := M.cyl(0.62, 0.48, 1.7, theme.bar, Vector3(0, 0.1, 0))
	jar.material_override = M.mat(theme.bar, 0.15, 0.0, 0.32)
	n.add_child(jar)
	n.add_child(M.tube(PackedVector3Array([Vector3(0.58, 0.7, 0), Vector3(0.95, 0.55, 0), Vector3(0.95, -0.25, 0), Vector3(0.52, -0.45, 0)]), 0.09, oc.darkened(0.15)))
	lid = Node3D.new()
	lid.position = Vector3(0, 1.0, 0)
	n.add_child(lid)
	lid.add_child(M.cyl(0.67, 0.67, 0.16, oc.darkened(0.2)))
	lid.add_child(M.sphere(0.13, theme.comp, Vector3(0, 0.14, 0)))
	return n


func _cup() -> Node3D:
	var n := Node3D.new()
	cup_fill = Node3D.new()
	cup_fill.position = Vector3(0, -0.5, 0)
	cup_fill.scale = Vector3(1, 0.01, 1)
	n.add_child(cup_fill)
	cup_fill_mesh = M.cyl(0.47, 0.37, 0.95, theme.base, Vector3(0, 0.475, 0))
	cup_fill.add_child(cup_fill_mesh)
	var glass := M.cyl(0.52, 0.4, 1.1, theme.bar)
	glass.material_override = M.mat(theme.bar, 0.15, 0.0, 0.35)
	n.add_child(glass)
	n.add_child(M.tube(PackedVector3Array([Vector3(0.15, -0.3, 0), Vector3(0.25, 0.75, 0), Vector3(0.55, 0.95, 0)]), 0.05, theme.comp))
	n.add_child(M.cyl(0.42, 0.42, 0.08, theme.light, Vector3(0, -0.58, 0)))
	return n


# ---------------------------------------------------------------- 回合
func new_round(i: int) -> void:
	step = 0
	shelf.clear()
	slots.clear()
	covers.clear()
	chunks.clear()
	jar_fill.scale = Vector3(1, 0.01, 1)
	cup_fill.scale = Vector3(1, 0.01, 1)
	jar_fill.visible = false
	cup_fill.visible = false
	stream.visible = false
	var rn: int = RECIPE_N[diff]
	if diff == 2 and i >= 2:
		rn = 5
	var kinds: Array = M.FRUITS.keys()
	recipe = pick_n(kinds, rn)
	var rest: Array = []
	for k in kinds:
		if not recipe.has(k):
			rest.append(k)
	var on_shelf: Array = shuffled(recipe + pick_n(rest, SHELF_N[diff] - rn))
	# 配方板上的格子
	for k in rn:
		var p := BOARD_POS + Vector3((k - (rn - 1) / 2.0) * SLOT_GAP, 0, 0.12)
		slots.append(p)
		var plate := M.cyl(0.66, 0.66, 0.06, Color(theme.wall2), p + Vector3(0, 0, -0.02), Vector3(PI / 2, 0, 0), 28)
		round_root.add_child(plate)
		var num := Label3D.new()
		num.text = str(k + 1)
		num.font_size = 72
		num.outline_size = 14
		num.modulate = Color.WHITE
		num.outline_modulate = theme.dark
		num.position = p + Vector3(-0.66, 0.58, 0.75)
		round_root.add_child(num)
		if k < rn - 1:
			var dot := M.cyl(0.0, 0.11, 0.2, theme.analog_a, p + Vector3(SLOT_GAP / 2.0, 0, 0.05), Vector3(0, 0, -PI / 2), 3)
			round_root.add_child(dot)
	# 記憶展示：水果一個一個出現
	set_prompt("看配方，記住水果出現的順序", ["juice_watch"])
	await wait(1.6)
	var shown: Array = []
	for k in rn:
		var kind: String = recipe[k]
		var f := M.fruit(kind)
		var sp: Vector3 = slots[k]
		f.position = sp + Vector3(0, 0, 0.35)
		f.scale = Vector3.ONE * FRUIT_SCALE
		round_root.add_child(f)
		pop_in(f)
		Snd.play("pop")
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(f, "rotation:z", 0.25, 0.15)
		tw.tween_property(f, "rotation:z", -0.2, 0.2)
		tw.tween_property(f, "rotation:z", 0.0, 0.15)
		shown.append(f)
		await wait(1.3)
	await wait(0.6)
	# 蓋起來：水果縮小消失、蓋子翻過來
	Snd.play("whoosh")
	for k in rn:
		var f: Node3D = shown[k]
		var tw := create_tween()
		tw.tween_interval(k * 0.08)
		tw.tween_property(f, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
		tw.tween_callback(f.queue_free)
	await wait(0.3)
	for k in rn:
		var cv := _cover()
		var cp: Vector3 = slots[k]
		cv.position = cp + Vector3(0, 0, 0.3)
		cv.rotation.y = PI / 2
		round_root.add_child(cv)
		covers.append(cv)
		var tw := create_tween()
		tw.tween_interval(k * 0.1)
		tw.tween_property(cv, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await wait(0.5)
	set_prompt("配方蓋起來囉！照順序把水果放進果汁機", ["juice_cover", "juice_pick"])
	# 水果架
	var n: int = on_shelf.size()
	var cols := n if n <= 4 else n / 2
	var rows := 1 if n <= 4 else 2
	var row_y: Array = [-1.55] if rows == 1 else [-0.4, -2.6]
	var gap := 1.9 if cols >= 4 else 2.3
	for r in rows:
		var ry: float = row_y[r]
		var plank := M.box(Vector3(cols * gap + 0.4, 0.16, 1.1), theme.dark.lightened(0.15), Vector3(BOARD_POS.x, ry - 0.72, -0.35))
		round_root.add_child(plank)
		pop_in(plank)
	for k in n:
		var kind: String = on_shelf[k]
		var r := k / cols
		var c := k % cols
		var ry: float = row_y[r]
		var f := M.fruit(kind)
		f.position = Vector3(BOARD_POS.x + (c - (cols - 1) / 2.0) * gap, ry, 0)
		f.scale = Vector3.ONE * SHELF_SCALE
		round_root.add_child(f)
		shelf[kind] = f
		add_pickable(f, 0.85, {"name": M.FRUITS[kind], "target": recipe.has(kind), "kind": kind})
		pop_in(f, 0.1 + k * 0.06)
	await wait(0.5 + n * 0.06)
	ready_to_answer()


func _cover() -> Node3D:
	var n := Node3D.new()
	n.add_child(M.box(Vector3(1.32, 1.32, 0.14), theme.base))
	n.add_child(M.box(Vector3(1.12, 1.12, 0.05), theme.light, Vector3(0, 0, 0.08)))
	var q := Label3D.new()
	q.text = "?"
	q.font_size = 120
	q.outline_size = 16
	q.modulate = Color.WHITE
	q.outline_modulate = theme.dark
	q.position = Vector3(0, 0, 0.13)
	n.add_child(q)
	return n


func on_pick(node: Node3D, data: Dictionary) -> void:
	if step >= recipe.size():
		return
	var kind: String = data.get("kind", "")
	var want: String = recipe[step]
	if kind != want:
		bad(node)
		_bot_target = null  # 自動測試：答錯後重新選目標（基底的 bot 會一直看著同一個）
		return
	var slot_i := step
	step += 1
	remove_pickable(node)
	shelf.erase(kind)
	good(node)
	_reveal(slot_i, kind)
	_fly_in(node, kind)
	if step >= recipe.size():
		clear_pickables()
		var t0 := Time.get_ticks_msec()
		await wait(1.3)
		await _blend()
		await wait(0.6)
		# 作答時間只算到選完最後一個水果，不含果汁機動畫
		t_round += Time.get_ticks_msec() - t0
		finish_round()


## 配方板上對應的格子打開，露出放對的水果
func _reveal(k: int, kind: String) -> void:
	var cv: Node3D = covers[k]
	var tw := create_tween()
	tw.tween_property(cv, "rotation:y", PI / 2, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(cv.queue_free)
	var f := M.fruit(kind)
	var sp: Vector3 = slots[k]
	f.position = sp + Vector3(0, 0, 0.35)
	f.scale = Vector3.ONE * FRUIT_SCALE
	round_root.add_child(f)
	pop_in(f, 0.2)


## 水果飛進果汁機
func _fly_in(node: Node3D, kind: String) -> void:
	await wait(0.32)
	if not is_instance_valid(node):
		return
	var top := BLENDER_POS + Vector3(0, 2.0, 0.5)
	var mid := (node.position + top) / 2.0 + Vector3(0, 1.2, 0.5)
	Snd.play("whoosh", 0.6)
	var tw := create_tween()
	tw.tween_property(node, "position", mid, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "rotation:z", 1.5, 0.5)
	tw.tween_property(node, "position", top, 0.25).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.4, 0.25)
	var lt := create_tween()
	lt.tween_interval(0.3)
	lt.tween_property(lid, "position:y", 1.6, 0.12)
	lt.tween_interval(0.35)
	lt.tween_property(lid, "position:y", 1.0, 0.15).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_property(node, "position", BLENDER_POS + Vector3(0, -0.2, 0), 0.25).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.22, 0.25)
	await tw.finished
	if not is_instance_valid(node):
		return
	Snd.play("drop")
	node.queue_free()
	var ch := M.sphere(0.17, Color(M.FRUIT_JUICE[kind]), BLENDER_POS + Vector3(rng.randf_range(-0.25, 0.25), -0.48 + chunks.size() * 0.1, rng.randf_range(-0.15, 0.15)))
	round_root.add_child(ch)
	chunks.append(ch)


func _mix_color() -> Color:
	var c := Color(0, 0, 0)
	for k in recipe:
		c += Color(M.FRUIT_JUICE[k])
	c /= float(recipe.size())
	c.a = 1.0
	return c


## 果汁機轉動、果汁倒進杯子
func _blend() -> void:
	set_prompt("果汁機轉轉轉，果汁做好囉！", ["juice_blend"])
	var mc := _mix_color()
	jar_fill_mesh.material_override = M.mat(mc, 0.35)
	cup_fill_mesh.material_override = M.mat(mc, 0.35)
	stream.material_override = M.mat(mc, 0.35)
	Snd.play("blend")
	jar_fill.visible = true
	var tw := create_tween()
	tw.tween_property(blade, "rotation:y", blade.rotation.y + TAU * 8, 1.6)
	var sh := create_tween()
	for k in 10:
		sh.tween_property(blender, "rotation:z", 0.04 if k % 2 == 0 else -0.04, 0.08)
	sh.tween_property(blender, "rotation:z", 0.0, 0.08)
	for ch in chunks:
		var c: Node3D = ch
		if is_instance_valid(c):
			var t2 := create_tween()
			t2.tween_property(c, "scale", Vector3.ONE * 0.01, 0.8)
	var ft := create_tween()
	ft.tween_property(jar_fill, "scale:y", 0.85, 1.4).set_ease(Tween.EASE_OUT)
	await wait(1.7)
	stream.visible = true
	cup_fill.visible = true
	Snd.play("drop", 0.8)
	var pt := create_tween()
	pt.tween_property(jar_fill, "scale:y", 0.15, 1.0)
	pt.parallel().tween_property(cup_fill, "scale:y", 1.0, 1.0)
	await pt.finished
	stream.visible = false
	good(cup_fill.get_parent())
	await wait(0.4)


func bot_target() -> Node3D:
	if step >= recipe.size():
		return null
	var want: String = recipe[step]
	if shelf.has(want):
		var n: Node3D = shelf[want]
		return n
	return null
