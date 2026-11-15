extends Level
## 彩虹遊樂場｜哪個不一樣（視覺辨識）
## 一排東西裡只有一個和別人不一樣，看著那一個。
## 簡單：4 個、顏色不同；中等：6 個、形狀或數量不同；困難：9 個、只差一點點。

const VOICE := {
	"oddone_find": "找出哪一個不一樣。",
	"oddone_color": "看看哪一個的顏色不一樣。",
	"oddone_shape": "看看哪一個的形狀或數量不一樣。",
	"oddone_detail": "仔細看喔，只差一點點。",
}
const COUNTS := [4, 6, 9]
const COLS := [4, 3, 5]
const RULE_VOICE := ["oddone_color", "oddone_shape", "oddone_detail"]
const RULE_TEXT := ["看看哪一個顏色不一樣", "看看哪一個形狀或數量不一樣", "仔細看，只差一點點"]
const KINDS := [
	["icecream", "flower", "balloon", "shape", "car"],
	["icecream", "flower", "balloon", "shape", "blocks"],
	["icecream", "flower", "balloon", "shape", "face"],
]
const EASY_COLORS := ["red", "yellow", "green", "blue", "purple"]
const PETAL_COLORS := ["red", "blue", "purple", "pink", "cyan"]
const FLAVORS := ["#FF8FA3", "#8CE99A", "#FFF3BF", "#9C6644", "#91A7FF", "#FFD43B"]
const FLAVOR_NAMES := ["草莓", "薄荷", "香草", "巧克力", "藍莓", "檸檬"]
const SHAPE_KINDS := ["cube", "ball", "star", "heart", "cone", "cylinder"]
const ITEM_RECT := Rect2(-4.3, -3.55, 10.6, 5.95)

var _order: Array = []
var odd_node: Node3D
var _t := 0.0


func build() -> void:
	var acc: Array = [theme.base, theme.analog_a, theme.light, theme.analog_b]
	# 背景淡淡的彩虹（下半部被地板擋住）
	for k in 4:
		var c: Color = (acc[k] as Color).lerp(theme.wall2, 0.45)
		var r := 12.6 - k * 0.9
		var arc := M.torus(r - 0.45, r, c, Vector3(1.0, -6.2, -8.6), Vector3(PI / 2, 0, 0))
		arc.material_override = M.flat(c)
		add_child(arc)
	# 三角彩旗
	for i in 22:
		var f := M.cyl(0.0, 0.32, 0.55, acc[i % acc.size()] as Color, Vector3(-11 + i * 1.05, 3.3 - absf(i - 10.5) * 0.03, -8.4), Vector3(PI, 0, 0), 3)
		add_child(f)
	# 兩側小雲朵（主題最淡色）
	for p in [Vector3(-10.5, 1.6, -8.3), Vector3(11.0, 0.8, -8.3)]:
		var cl := Node3D.new()
		cl.position = p
		for k in 4:
			cl.add_child(M.sphere(2.4 * (0.25 + 0.08 * (k % 2)), theme.bar, Vector3((k - 1.5) * 0.6, (k % 2) * 0.24, 0)))
		add_child(cl)


func new_round(i: int) -> void:
	if i == 0 or _order.is_empty():
		_order = shuffled(KINDS[diff])
	var kind: String = _order[i % _order.size()]
	var v := _variant(kind)
	var n: int = COUNTS[diff]
	var cols: int = COLS[diff]
	var pos := grid(n, ITEM_RECT, cols)
	var rows := int(ceil(float(n) / cols))
	var cw := ITEM_RECT.size.x / cols
	var ch := ITEM_RECT.size.y / rows
	var fit_w := minf(cw * 0.76, 2.3)
	var fit_h := minf(ch * 0.72, 2.6)
	var card_w := minf(cw * 0.92, fit_w + 0.55)
	var card_h := minf(ch * 0.9, fit_h + 0.6)
	# 兩款共用同一個縮放（大小差異才保留得住），各自置中
	var sa: Node3D = (v.a as Callable).call()
	var sb: Node3D = (v.b as Callable).call()
	var ba := _bounds(sa)
	var bbb := _bounds(sb)
	sa.free()
	sb.free()
	var mx := maxf(ba.size.x, bbb.size.x)
	var my := maxf(ba.size.y, bbb.size.y)
	var fit := minf(fit_w / maxf(mx, 0.01), fit_h / maxf(my, 0.01))
	var odd_i := rng.randi() % n
	for k in n:
		var is_odd := k == odd_i
		var holder := Node3D.new()
		holder.position = pos[k]
		round_root.add_child(holder)
		# 卡片用不受光材質：不會被物件投影弄髒
		var fc: Color = [theme.base, theme.analog_a, theme.analog_b][k % 3]
		var frame := M.box(Vector3(card_w + 0.16, card_h + 0.16, 0.08), fc, Vector3(0, 0, -1.05))
		frame.material_override = M.flat(fc)
		holder.add_child(frame)
		var card := M.box(Vector3(card_w, card_h, 0.1), theme.bar, Vector3(0, 0, -1.0))
		card.material_override = M.flat(theme.bar)
		holder.add_child(card)
		var inner := Node3D.new()
		inner.scale = Vector3.ONE * fit
		holder.add_child(inner)
		var model: Node3D = ((v.b if is_odd else v.a) as Callable).call()
		model.position = -(bbb if is_odd else ba).get_center()
		inner.add_child(model)
		holder.set_meta("inner", inner)
		holder.set_meta("phase", rng.randf() * TAU)
		if is_odd:
			odd_node = holder
		var nm: String = v.nb if is_odd else v.na
		add_pickable(holder, minf(card_w, card_h) * 0.5, {"name": nm, "target": is_odd})
		pop_in(holder, k * 0.05)
	var voice: Array = ["oddone_find"]
	var text := "找出哪一個不一樣"
	if i == 0:
		voice.append(RULE_VOICE[diff])
		text += "（%s）" % RULE_TEXT[diff]
	set_prompt(text, voice)
	await wait(0.4 + n * 0.05)
	ready_to_answer()


func _process(delta: float) -> void:
	super._process(delta)
	if paused:
		return
	_t += delta
	for h in round_root.get_children():
		var inner: Node3D = h.get_meta("inner", null)
		if inner:
			var ph: float = h.get_meta("phase", 0.0)
			inner.rotation.y = sin(_t * 1.3 + ph) * 0.22


func on_pick(node: Node3D, data: Dictionary) -> void:
	if data.target:
		good(node)
		clear_pickables()
		await wait(0.6)
		finish_round()
	else:
		bad(node)
		_bot_target = null  # 自動測試：答錯後重新決定要看哪個（否則會一直選同一個錯的）


func bot_target() -> Node3D:
	return odd_node


# ---------------------------------------------------------------- 題目產生
## 回傳 {a: 一般款 Callable, b: 不一樣的 Callable, na, nb: 報告名稱}
func _variant(kind: String) -> Dictionary:
	match kind:
		"icecream":
			return _v_icecream()
		"flower":
			return _v_flower()
		"balloon":
			return _v_balloon()
		"shape":
			return _v_shape()
		"car":
			var cs := pick_n(EASY_COLORS, 2)
			var ca: String = cs[0]
			var cb: String = cs[1]
			return {"a": func() -> Node3D: return M.car(ca), "b": func() -> Node3D: return M.car(cb),
				"na": "%s小汽車" % M.COLOR_NAMES[ca], "nb": "%s小汽車" % M.COLOR_NAMES[cb]}
		"blocks":
			var c: String = PETAL_COLORS[rng.randi() % PETAL_COLORS.size()]
			var ka := rng.randi_range(2, 4)
			var kb := ka + (1 if ka < 4 and (ka == 2 or rng.randf() < 0.5) else -1)
			return {"a": func() -> Node3D: return M.blocks(_row(ka), c, 0.5), "b": func() -> Node3D: return M.blocks(_row(kb), c, 0.5),
				"na": "%d 格積木" % ka, "nb": "%d 格積木" % kb}
		"face":
			var pairs := [["happy", "laugh"], ["happy", "sleepy"], ["sad", "scared"], ["surprised", "scared"]]
			var pr: Array = pairs[rng.randi() % pairs.size()]
			if rng.randf() < 0.5:
				pr = [pr[1], pr[0]]
			var ea: String = pr[0]
			var eb: String = pr[1]
			return {"a": func() -> Node3D: return M.face(ea), "b": func() -> Node3D: return M.face(eb),
				"na": "%s的臉" % M.EXPRESSIONS[ea], "nb": "%s的臉" % M.EXPRESSIONS[eb]}
	return _v_shape()


func _v_icecream() -> Dictionary:
	var idx := pick_n(range(FLAVORS.size()), 3)
	var fa: String = FLAVORS[idx[0]]
	var fb: String = FLAVORS[idx[1]]
	var fc: String = FLAVORS[idx[2]]
	match diff:
		0:
			var k := rng.randi_range(1, 2)
			var sa: Array = []
			var sb: Array = []
			for j in k:
				sa.append(Color(fa))
				sb.append(Color(fb))
			return {"a": func() -> Node3D: return M.icecream(sa), "b": func() -> Node3D: return M.icecream(sb),
				"na": "%s冰淇淋" % FLAVOR_NAMES[idx[0]], "nb": "%s冰淇淋" % FLAVOR_NAMES[idx[1]]}
		1:
			var all: Array = [Color(fa), Color(fb), Color(fc)]
			var ka := rng.randi_range(1, 3)
			var kb := ka + (1 if ka == 1 else (-1 if ka == 3 else (1 if rng.randf() < 0.5 else -1)))
			var sa: Array = all.slice(0, ka)
			var sb: Array = all.slice(0, kb)
			return {"a": func() -> Node3D: return M.icecream(sa), "b": func() -> Node3D: return M.icecream(sb),
				"na": "%d 球冰淇淋" % ka, "nb": "%d 球冰淇淋" % kb}
		_:
			var s: Array = [Color(fa), Color(fb)]
			var odd_has := rng.randf() < 0.6
			return {"a": func() -> Node3D: return M.icecream(s, not odd_has), "b": func() -> Node3D: return M.icecream(s, odd_has),
				"na": "冰淇淋" + ("沒有櫻桃" if odd_has else "有櫻桃"), "nb": "冰淇淋" + ("有櫻桃" if odd_has else "沒有櫻桃")}


func _v_flower() -> Dictionary:
	match diff:
		0:
			var cs := pick_n(["red", "blue", "purple"], 2)
			var ca: String = cs[0]
			var cb: String = cs[1]
			return {"a": func() -> Node3D: return M.flower(5, ca), "b": func() -> Node3D: return M.flower(5, cb),
				"na": "%s的花" % M.COLOR_NAMES[ca], "nb": "%s的花" % M.COLOR_NAMES[cb]}
		1:
			var c: String = PETAL_COLORS[rng.randi() % PETAL_COLORS.size()]
			var pairs := [[4, 7], [5, 8], [7, 4], [8, 5]]
			var pr: Array = pairs[rng.randi() % pairs.size()]
			var pa: int = pr[0]
			var pb: int = pr[1]
			return {"a": func() -> Node3D: return M.flower(pa, c), "b": func() -> Node3D: return M.flower(pb, c),
				"na": "%d 片花瓣的花" % pa, "nb": "%d 片花瓣的花" % pb}
		_:
			var c: String = ["pink", "purple", "blue", "red"][rng.randi() % 4]
			var centers := ["yellow", "brown", "white"]
			if c == "red" or c == "pink":
				centers = ["yellow", "brown", "cyan"]
			var cc := pick_n(centers, 2)
			var ca: String = cc[0]
			var cb: String = cc[1]
			return {"a": func() -> Node3D: return M.flower(6, c, ca), "b": func() -> Node3D: return M.flower(6, c, cb),
				"na": "%s花心的花" % M.COLOR_NAMES[ca], "nb": "%s花心的花" % M.COLOR_NAMES[cb]}


func _v_balloon() -> Dictionary:
	match diff:
		0:
			var cs := pick_n(EASY_COLORS, 2)
			var ca: String = cs[0]
			var cb: String = cs[1]
			return {"a": func() -> Node3D: return M.balloon(ca), "b": func() -> Node3D: return M.balloon(cb),
				"na": "%s氣球" % M.COLOR_NAMES[ca], "nb": "%s氣球" % M.COLOR_NAMES[cb]}
		1:
			var cols := pick_n(["red", "yellow", "blue", "green", "purple", "pink"], 3)
			var ka := rng.randi_range(1, 3)
			var kb := ka + (1 if ka == 1 else (-1 if ka == 3 else (1 if rng.randf() < 0.5 else -1)))
			return {"a": func() -> Node3D: return _bunch(ka, cols), "b": func() -> Node3D: return _bunch(kb, cols),
				"na": "%d 顆氣球" % ka, "nb": "%d 顆氣球" % kb}
		_:
			var c: String = ["red", "blue", "purple", "pink", "orange"][rng.randi() % 5]
			var ms := ["star", "heart"] if rng.randf() < 0.5 else ["heart", "star"]
			var ma: String = ms[0]
			var mb: String = ms[1]
			var nm := {"star": "星星", "heart": "愛心"}
			return {"a": func() -> Node3D: return M.balloon(c, ma), "b": func() -> Node3D: return M.balloon(c, mb),
				"na": "%s圖案氣球" % nm[ma], "nb": "%s圖案氣球" % nm[mb]}


func _v_shape() -> Dictionary:
	match diff:
		0:
			var sk: String = SHAPE_KINDS[rng.randi() % SHAPE_KINDS.size()]
			var cs := pick_n(EASY_COLORS, 2)
			var ca: String = cs[0]
			var cb: String = cs[1]
			return {"a": func() -> Node3D: return M.shape(sk, ca), "b": func() -> Node3D: return M.shape(sk, cb),
				"na": "%s%s" % [M.COLOR_NAMES[ca], M.SHAPES[sk]], "nb": "%s%s" % [M.COLOR_NAMES[cb], M.SHAPES[sk]]}
		1:
			var c: String = EASY_COLORS[rng.randi() % EASY_COLORS.size()]
			var ss := pick_n(SHAPE_KINDS, 2)
			var sa: String = ss[0]
			var sb: String = ss[1]
			return {"a": func() -> Node3D: return M.shape(sa, c), "b": func() -> Node3D: return M.shape(sb, c),
				"na": M.SHAPES[sa], "nb": M.SHAPES[sb]}
		_:
			var sk: String = ["cube", "ball", "star", "heart"][rng.randi() % 4]
			var c: String = EASY_COLORS[rng.randi() % EASY_COLORS.size()]
			var big := rng.randf() < 0.5
			var sz := 1.15 if big else 0.85
			return {"a": func() -> Node3D: return M.shape(sk, c), "b": func() -> Node3D: return M.shape(sk, c, sz),
				"na": M.SHAPES[sk], "nb": ("大一點的" if big else "小一點的") + M.SHAPES[sk]}


func _row(k: int) -> Array:
	var cells: Array = []
	for j in k:
		cells.append(Vector2i(j, 0))
	return cells


## 一串氣球（k 顆，綁在同一點）
func _bunch(k: int, cols: Array) -> Node3D:
	var n := Node3D.new()
	for j in k:
		var off := (j - (k - 1) / 2.0)
		var b := M.balloon(cols[j % cols.size()])
		b.position = Vector3(off * 0.95, 0.15 - absf(off) * 0.25, -absf(off) * 0.1)
		b.rotation.z = -off * 0.3
		b.scale = Vector3.ONE * 0.85
		n.add_child(b)
	return n


## 模型的外框（不在場景樹裡也能算）
func _bounds(n: Node3D) -> AABB:
	var acc: Array = [AABB(), false]
	_collect(n, n.transform, acc)
	return acc[0]


func _collect(n: Node3D, xf: Transform3D, acc: Array) -> void:
	for c in n.get_children():
		if not (c is Node3D):
			continue
		var cn := c as Node3D
		var t: Transform3D = xf * cn.transform
		if cn is MeshInstance3D and (cn as MeshInstance3D).mesh:
			var bb: AABB = t * (cn as MeshInstance3D).mesh.get_aabb()
			if acc[1]:
				acc[0] = (acc[0] as AABB).merge(bb)
			else:
				acc[0] = bb
				acc[1] = true
		_collect(cn, t, acc)
