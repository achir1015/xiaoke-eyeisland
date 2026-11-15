extends Level
## 森林躲貓貓｜迷霧猜猜看（視覺完形）
## 東西藏在一格一格的雲霧裡，雲霧會一塊一塊散開，越早猜對越厲害。

const Bush := preload("res://scripts/games/bush.gd")

const VOICE := {
	"fog_what": "雲霧裡藏著什麼呢？",
	"fog_is_apple": "是蘋果！",
	"fog_is_banana": "是香蕉！",
	"fog_is_orange": "是橘子！",
	"fog_is_grape": "是葡萄！",
	"fog_is_strawberry": "是草莓！",
	"fog_is_pear": "是西洋梨！",
	"fog_is_cherry": "是櫻桃！",
	"fog_is_lemon": "是檸檬！",
	"fog_is_watermelon": "是西瓜！",
	"fog_is_kiwi": "是奇異果！",
	"fog_is_carrot": "是紅蘿蔔！",
	"fog_is_peach": "是水蜜桃！",
	"fog_is_cat": "是貓咪！",
	"fog_is_rabbit": "是兔子！",
	"fog_is_bear": "是小熊！",
	"fog_is_pig": "是小豬！",
	"fog_is_frog": "是青蛙！",
	"fog_is_elephant": "是大象！",
	"fog_is_panda": "是熊貓！",
	"fog_is_duck": "是鴨子！",
	"fog_is_lion": "是獅子！",
	"fog_is_mouse": "是老鼠！",
}
const NOPT := [3, 4, 5]
const INTERVAL := [0.7, 1.5, 1.5]        # 每隔幾秒散開一格
const BOT_WAIT := [0.3, 0.4, 0.5]        # 自動測試：露出多少才作答
const N := 6
const CELL := 0.62
const GRID_C := Vector3(1.0, 0.5, 0.75)
const FRUIT_SIM := [["apple", "peach", "orange", "lemon"], ["cherry", "grape", "strawberry"], ["pear", "lemon", "apple"], ["kiwi", "peach", "orange"]]
const ANIMAL_SIM := [["cat", "lion", "mouse"], ["bear", "panda"], ["rabbit", "mouse"], ["pig", "bear"], ["cat", "rabbit"]]

var item: Node3D
var target_kind := ""
var target_opt: Node3D
var is_fruit := true
var _last := ""
var _cells: Array = []        # [{node, weight, open}]
var _order: Array = []
var _total := 0
var _opened := 0
var _t := 0.0
var _done := false
var _rim: Array = []


func build() -> void:
	Bush.forest_decor(self, theme, rng)


func new_round(_i: int) -> void:
	_done = false
	_cells.clear()
	_order.clear()
	_opened = 0
	_t = -0.6
	# 題目：水果或動物
	is_fruit = rng.randf() < 0.5
	var kinds: Array = M.FRUITS.keys() if is_fruit else M.ANIMALS.keys()
	var pool := kinds.duplicate()
	pool.erase(_last)
	if diff == 2:
		pool = pool.filter(func(k): return _similar_of(k).size() > 0)
	target_kind = pool[rng.randi() % pool.size()]
	_last = target_kind
	var opts := _make_options(target_kind, kinds)
	set_prompt("雲霧裡藏著什麼呢？", ["fog_what"])
	# 藏起來的東西：縮放到剛好填滿雲霧格子中央
	item = _model(target_kind)
	round_root.add_child(item)
	var pts := Bush.silhouette(item)
	var bb := _bbox(pts)
	var sc := minf(3.2 / maxf(bb.size.x, 0.1), 3.2 / maxf(bb.size.y, 0.1))
	sc = minf(sc, 1.9)
	var ctr := bb.get_center()
	item.scale = Vector3.ONE * sc
	item.position = Vector3(GRID_C.x - ctr.x * sc, GRID_C.y - ctr.y * sc, -1.3)   # 放在雲霧後面，凸出的部分才不會穿出來
	pts = Bush.silhouette(item)
	_total = pts.size()
	# 雲霧格子
	var half := N * CELL / 2.0
	for gy in N:
		for gx in N:
			var c := Vector3(GRID_C.x - half + (gx + 0.5) * CELL, GRID_C.y - half + (gy + 0.5) * CELL, GRID_C.z)
			var a := cam.unproject_position(c + Vector3(-CELL / 2, -CELL / 2, 0.12))
			var b := cam.unproject_position(c + Vector3(CELL / 2, CELL / 2, 0.12))
			var rect := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
			_cells.append({"node": _cloud_cell(c, (gx + gy) % 2), "rect": rect, "weight": 0, "open": false})
	for p in pts:
		var sp := cam.unproject_position(p)
		for c in _cells:
			var rc: Rect2 = c.rect
			if rc.has_point(sp):
				c.weight = int(c.weight) + 1
				break
	# 散開順序：先散和東西重疊的格子（隨機），再散旁邊的
	var on_item: Array = []
	var off_item: Array = []
	for k in _cells.size():
		if int(_cells[k].weight) > 0:
			on_item.append(k)
		else:
			off_item.append(k)
	_order = shuffled(on_item) + shuffled(off_item)
	_rim.clear()
	_cloud_rim()
	var cnt := 0
	for c in _cells:
		pop_in(c.node, cnt * 0.008)
		cnt += 1
	# 選項
	var slots := grid(opts.size(), Rect2(-3.9, -3.65, 10.0, 1.6), opts.size())
	for k in opts.size():
		var kind: String = opts[k]
		var sl: Vector3 = slots[k]
		var br := 0.92 if opts.size() < 5 else 0.84
		var badge := M.cyl(br, br, 0.08, theme.bar, Vector3(sl.x, sl.y, -0.7), Vector3(PI / 2, 0, 0), 32)
		badge.material_override = M.flat(theme.bar)
		round_root.add_child(badge)
		round_root.add_child(M.torus(br - 0.04, br + 0.06, theme.base, Vector3(sl.x, sl.y, -0.62), Vector3(PI / 2, 0, 0)))
		var m := _model(kind)
		var s := 0.55 if is_fruit else 0.5
		m.position = Vector3(sl.x, sl.y - (0.0 if is_fruit else 0.08), 0)
		m.scale = Vector3.ONE * s
		Bush.no_shadow(m)
		round_root.add_child(m)
		var is_t := kind == target_kind
		if is_t:
			target_opt = m
		add_pickable(m, 0.9 / s, {"name": _name(kind), "target": is_t})
		pop_in(m, 0.3 + k * 0.08)
	await wait(0.6)
	ready_to_answer()


func _model(kind: String) -> Node3D:
	return M.fruit(kind) if M.FRUITS.has(kind) else M.animal(kind)


func _name(kind: String) -> String:
	return M.FRUITS[kind] if M.FRUITS.has(kind) else M.ANIMALS[kind]


func _bbox(pts: Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var w: Vector3 = p
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
		hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	if pts.is_empty():
		return Rect2(-1, -1, 2, 2)
	return Rect2(lo, hi - lo)


## 一格雲霧：方塊＋鼓起來的雲朵（不透明，一開始完全蓋住）
func _cloud_cell(c: Vector3, shade: int) -> Node3D:
	var n := Node3D.new()
	n.position = c
	var w2: Color = theme.wall2
	var bc: Color = theme.wall if shade == 0 else (theme.light as Color).lerp(theme.wall, 0.4)
	var puff: Color = w2
	var bx := M.box(Vector3(CELL * 1.01, CELL * 1.01, 0.22), bc)
	bx.material_override = M.flat(bc)   # 不受光照，才看得出淡淡的主題色
	n.add_child(bx)
	n.add_child(M.sphere(CELL * 0.36, puff, Vector3(-CELL * 0.1, CELL * 0.08, 0.12), Vector3(1.1, 0.9, 0.4)))
	n.add_child(M.sphere(CELL * 0.26, w2.lerp(theme.wall, 0.5), Vector3(CELL * 0.2, -CELL * 0.14, 0.14), Vector3(1.1, 0.9, 0.4)))
	Bush.no_shadow(n)
	round_root.add_child(n)
	return n


## 雲霧外圍一圈蓬蓬的雲（裝飾，讓方格看起來像一團雲）
func _cloud_rim() -> void:
	var half := N * CELL / 2.0
	var w2: Color = theme.wall2
	var k := 0
	for side in 4:
		for j in N + 1:
			var t := -half + j * CELL
			var p: Vector3
			match side:
				0: p = Vector3(t, half, 0)
				1: p = Vector3(t, -half, 0)
				2: p = Vector3(-half, t, 0)
				_: p = Vector3(half, t, 0)
			var r := CELL * (0.42 if k % 2 == 0 else 0.34)
			var s := M.sphere(r, w2 if k % 3 else w2.lerp(theme.wall, 0.6), GRID_C + p + Vector3(0, 0, 0.05), Vector3(1.15, 1.0, 0.4))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			round_root.add_child(s)
			_rim.append(s)
			k += 1


func _similar_of(kind: String) -> Array:
	var out: Array = []
	for g in (FRUIT_SIM if M.FRUITS.has(kind) else ANIMAL_SIM):
		if kind in g:
			for k in g:
				if k != kind and not (k in out):
					out.append(k)
	return out


func _make_options(t: String, kinds: Array) -> Array:
	var n: int = NOPT[diff]
	var opts: Array = [t]
	if diff == 2:
		for k in shuffled(_similar_of(t)):
			if opts.size() < n:
				opts.append(k)
	var rest := shuffled(kinds)
	for k in rest:
		if opts.size() >= n:
			break
		if k in opts:
			continue
		if diff == 0:
			var ok := true
			for o in opts:
				if k in _similar_of(o):
					ok = false
			if not ok:
				continue
		opts.append(k)
	for k in rest:
		if opts.size() >= n:
			break
		if not (k in opts):
			opts.append(k)
	return shuffled(opts)


## 露出比例：已散開格子裡的剪影取樣點／全部取樣點
func reveal() -> float:
	if _total <= 0:
		return 0.0
	var w := 0
	for c in _cells:
		if c.open:
			w += int(c.weight)
	return float(w) / _total


func _open_cell(k: int, quick := false) -> void:
	var c: Dictionary = _cells[k]
	if c.open:
		return
	c.open = true
	_opened += 1
	var n: Node3D = c.node
	if not is_instance_valid(n):
		return
	var tw := create_tween()
	var d := 0.35 if quick else 0.6
	tw.tween_property(n, "position", n.position + Vector3(rng.randf_range(-0.6, 0.6), 0.8, 0.6), d).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.02, d).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


func _process(delta: float) -> void:
	super._process(delta)
	if not answering or paused or _done or _order.is_empty():
		return
	_t += delta
	if _t >= INTERVAL[diff]:
		_t = 0.0
		_open_cell(_order.pop_front())
		Snd.play("tick", 0.3)


func on_pick(node: Node3D, data: Dictionary) -> void:
	if _done:
		return
	if data.target:
		_done = true
		set_coverage(reveal())
		print("COVERAGE %s r%d %.3f opened=%d/%d" % [level_id, round_i + 1, reveal(), _opened, _cells.size()])
		good(node)
		clear_pickables()
		var k := 0
		for c in _order:
			var tw := create_tween()
			tw.tween_interval(k * 0.012)
			tw.tween_callback(_open_cell.bind(int(c), true))
			k += 1
		_order.clear()
		for r in _rim:
			if is_instance_valid(r):
				var tw2 := create_tween()
				tw2.tween_property(r, "scale", Vector3.ONE * 0.02, 0.5)
		show_toast("是%s！" % _name(target_kind), 1.0)
		Snd.say("fog_is_" + target_kind)
		await wait(1.6)
		finish_round()
	else:
		bad(node)
		_bot_target = null   # 自動測試：答錯後重新決定要看哪一個（不要一直選同一個錯的）


func bot_target() -> Node3D:
	# 模擬孩子：露出一定比例才認得出來
	if reveal() < BOT_WAIT[diff]:
		Gaze.bot_point = cam.unproject_position(GRID_C)   # 等待時看著雲霧，不要停在選項上
		return null
	return target_opt
