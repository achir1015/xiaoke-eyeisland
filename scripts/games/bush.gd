extends Level
## 森林躲貓貓｜樹叢躲貓貓（視覺完形）
## 動物躲在樹叢後面只露出一部分，從下方一排動物裡選出是誰。可以用提示撥開幾片樹葉。

const VOICE := {
	"bush_who": "是誰躲在樹叢後面呢？",
	"bush_is_cat": "是貓咪！",
	"bush_is_rabbit": "是兔子！",
	"bush_is_bear": "是小熊！",
	"bush_is_pig": "是小豬！",
	"bush_is_frog": "是青蛙！",
	"bush_is_elephant": "是大象！",
	"bush_is_panda": "是熊貓！",
	"bush_is_duck": "是鴨子！",
	"bush_is_lion": "是獅子！",
	"bush_is_mouse": "是老鼠！",
}
const REVEAL := [0.5, 0.33, 0.2]
const NOPT := [3, 4, 5]
## 長得像的動物（困難關一起出現；簡單關避免同組）
const SIMILAR := [["cat", "lion", "mouse"], ["bear", "panda"], ["rabbit", "mouse"], ["pig", "bear"], ["cat", "rabbit"]]
const HIDE_POS := Vector3(1.0, 0.6, 0)
const HIDE_SCALE := 1.15
const DIRS := [Vector2(0, 1), Vector2(-0.7, 0.7), Vector2(0.7, 0.7), Vector2(-1, 0.15), Vector2(1, 0.15)]

var hidden: Node3D
var target_kind := ""
var target_opt: Node3D
var _last := ""
var _samples: PackedVector2Array = PackedVector2Array()   # 動物剪影的取樣點（螢幕座標）
var _cover: PackedInt32Array = PackedInt32Array()         # 每個取樣點被幾片葉子擋住
var _leaves: Array = []     # [{pos, r, covers, active, node}]
var _order: Array = []      # 還可以撥開的葉片（依序）
var _center := Vector3.ZERO
var _done := false


func build() -> void:
	has_hint = true
	forest_decor(self, theme, rng)


## 森林背景：遠處的樹、草叢、小花（顏色都由主題推算）
static func forest_decor(parent: Node3D, th: Dictionary, r: RandomNumberGenerator) -> void:
	var base: Color = th.base
	var crowns: Array = [base.lerp(th.wall, 0.35), (th.analog_a as Color).lerp(th.wall, 0.4), (th.analog_b as Color).lerp(th.wall, 0.35)]
	var trunk: Color = (th.dark as Color).lerp(th.wall, 0.3)
	for i in 10:
		var t := Node3D.new()
		var h := r.randf_range(3.2, 4.6)
		var c: Color = crowns[i % crowns.size()]
		t.add_child(M.cyl(0.2, 0.3, h * 0.55, trunk, Vector3(0, h * 0.27, 0)))
		t.add_child(M.sphere(h * 0.3, c, Vector3(0, h * 0.66, 0)))
		t.add_child(M.sphere(h * 0.22, c.lightened(0.08), Vector3(h * 0.16, h * 0.8, 0.1)))
		t.add_child(M.sphere(h * 0.2, c.darkened(0.06), Vector3(-h * 0.18, h * 0.74, 0.05)))
		t.position = Vector3(-11.5 + i * 2.6 + r.randf_range(-0.5, 0.5), -4.5, -7.2 + (i % 2) * 0.6)
		parent.add_child(t)
	for i in 12:
		var g := bush_cluster(r.randf_range(0.6, 1.0), th, i)
		g.position = Vector3(-11 + i * 2.0 + r.randf_range(-0.4, 0.4), -4.0, -5.0)
		parent.add_child(g)
	for i in 8:
		var f := Node3D.new()
		var fc: Color = th.comp_light if i % 2 == 0 else th.light
		for k in 5:
			var a := TAU * k / 5
			f.add_child(M.sphere(0.09, fc, Vector3(cos(a) * 0.1, sin(a) * 0.1, 0), Vector3(1, 1, 0.4)))
		f.add_child(M.sphere(0.06, th.analog_a, Vector3(0, 0, 0.03)))
		f.position = Vector3(-9 + i * 2.5 + r.randf_range(-0.5, 0.5), -3.75 + r.randf_range(-0.1, 0.1), -3.6)
		parent.add_child(f)


## 一團樹葉（主題色版本的 M.leaf_cluster）
static func bush_cluster(rad: float, th: Dictionary, shade := 0) -> Node3D:
	var n := Node3D.new()
	var base: Color = th.base
	var greens: Array = [th.dark, base, th.analog_b, base.lightened(0.15), (th.dark as Color).lerp(base, 0.5)]
	for i in 7:
		var a := TAU * i / 7.0 + shade
		var d := rad * (0.35 if i > 0 else 0.0)
		var l := M.sphere(rad * 0.6, greens[(i + shade) % greens.size()], Vector3(cos(a) * d, sin(a) * d, 0.05 * i), Vector3(1.0, 0.8, 0.35))
		l.rotation.z = a
		n.add_child(l)
	return n


## 取樣模型剪影（從鏡頭方向看），回傳世界座標點
static func silhouette(root: Node3D, steps := 34) -> Array:
	var shapes: Array = []
	var inv := root.global_transform.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var stack: Array = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
		if not (nd is MeshInstance3D):
			continue
		var mi := nd as MeshInstance3D
		if mi.mesh == null:
			continue
		var rel: Transform3D = inv * mi.global_transform
		var bb := mi.mesh.get_aabb()
		var a := Vector2(INF, INF)
		var b := Vector2(-INF, -INF)
		for k in 8:
			var p: Vector3 = rel * bb.get_endpoint(k)
			a = Vector2(minf(a.x, p.x), minf(a.y, p.y))
			b = Vector2(maxf(b.x, p.x), maxf(b.y, p.y))
		lo = Vector2(minf(lo.x, a.x), minf(lo.y, a.y))
		hi = Vector2(maxf(hi.x, b.x), maxf(hi.y, b.y))
		if mi.mesh is SphereMesh:
			shapes.append({"sphere": true, "inv": rel.affine_inverse(), "z": rel.origin.z, "r": (mi.mesh as SphereMesh).radius})
		else:
			shapes.append({"sphere": false, "rect": Rect2(a, b - a)})
	var out: Array = []
	if shapes.is_empty():
		return out
	var dx := (hi.x - lo.x) / steps
	var dy := (hi.y - lo.y) / steps
	for iy in steps + 1:
		for ix in steps + 1:
			var x := lo.x + ix * dx
			var y := lo.y + iy * dy
			for s in shapes:
				var inside := false
				if s.sphere:
					var tf: Transform3D = s.inv
					var q: Vector3 = tf * Vector3(x, y, float(s.z))
					inside = q.x * q.x + q.y * q.y <= float(s.r) * float(s.r)
				else:
					var rc: Rect2 = s.rect
					inside = rc.has_point(Vector2(x, y))
				if inside:
					out.append(root.global_transform * Vector3(x, y, 0.4))
					break
	return out


func new_round(_i: int) -> void:
	_done = false
	_leaves.clear()
	_order.clear()
	# 題目
	var kinds: Array = M.ANIMALS.keys()
	var pool := kinds.duplicate()
	pool.erase(_last)
	if diff == 2:
		pool = pool.filter(func(k): return _similar_of(k).size() > 0)
	target_kind = pool[rng.randi() % pool.size()]
	_last = target_kind
	var opts := _make_options(target_kind, kinds)
	set_prompt("是誰躲在樹叢後面呢？", ["bush_who"])
	# 躲起來的動物
	hidden = M.animal(target_kind)
	hidden.position = HIDE_POS
	hidden.scale = Vector3.ONE * HIDE_SCALE
	round_root.add_child(hidden)
	var pts := silhouette(hidden)
	_samples = PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var w: Vector3 = p
		_samples.append(cam.unproject_position(w))
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
		hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	_cover = PackedInt32Array()
	_cover.resize(_samples.size())
	_cover.fill(0)
	# 樹叢：橢圓形的一大叢，把整隻動物蓋住
	_center = Vector3((lo.x + hi.x) / 2.0, (lo.y + hi.y) / 2.0 - 0.15, 0)
	var semi := Vector2((hi.x - lo.x) / 2.0 * 1.3 + 0.3, (hi.y - lo.y) / 2.0 * 1.25 + 0.3)
	var step := 0.48
	var gy := _center.y - semi.y
	while gy <= _center.y + semi.y:
		var gx := _center.x - semi.x
		while gx <= _center.x + semi.x:
			var p := Vector3(gx + rng.randf_range(-0.12, 0.12), gy + rng.randf_range(-0.12, 0.12), 1.0 + rng.randf_range(0, 0.45))
			var e := Vector2((p.x - _center.x) / semi.x, (p.y - _center.y) / semi.y)
			if e.length() <= 1.0 and p.y >= -1.15:   # 不要擋到下方選項
				_add_leaf(p, rng.randf_range(0.5, 0.66))
			gx += step
		gy += step
	# 依方向撥開，直到露出目標比例
	var dir: Vector2 = DIRS[rng.randi() % DIRS.size()]
	if diff == 2:
		dir = DIRS[rng.randi() % 3]   # 困難關從上方露出一點（耳朵、頭頂）
	var keyed: Array = []
	for k in _leaves.size():
		var lp: Vector3 = _leaves[k].pos
		var key := Vector2((lp.x - _center.x) / semi.x, (lp.y - _center.y) / semi.y).dot(dir) + rng.randf() * 0.25
		keyed.append([key, k])
	keyed.sort_custom(func(a, b): return a[0] > b[0])
	for e in keyed:
		_order.append(e[1])
	var goal: float = REVEAL[diff]
	var last := -1
	while reveal() < goal and not _order.is_empty():
		last = _order.pop_front()
		_set_leaf(last, false)
	# 一下子露太多：退回最後一片，改找最接近目標的那一片
	if last >= 0 and reveal() > goal + 0.06:
		_set_leaf(last, true)
		_order.push_front(last)
		var best := 0
		var best_d := INF
		for c in mini(10, _order.size()):
			var k: int = _order[c]
			_set_leaf(k, false)
			var d := absf(reveal() - goal)
			if reveal() >= goal - 0.05 and d < best_d:
				best_d = d
				best = c
			_set_leaf(k, true)
		var kk: int = _order[best]
		_order.remove_at(best)
		_set_leaf(kk, false)
	# 建立葉片
	var cnt := 0
	for k in _leaves.size():
		var lf: Dictionary = _leaves[k]
		if not lf.active:
			continue
		var node := bush_cluster(float(lf.r), theme, rng.randi() % 5)
		node.position = lf.pos
		node.rotation.z = rng.randf() * TAU
		round_root.add_child(node)
		lf["node"] = node
		pop_in(node, cnt * 0.006)
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
		var ring := M.torus(br - 0.04, br + 0.06, theme.base, Vector3(sl.x, sl.y, -0.62), Vector3(PI / 2, 0, 0))
		round_root.add_child(ring)
		var a := M.animal(kind)
		a.position = Vector3(sl.x, sl.y - 0.08, 0)
		a.scale = Vector3.ONE * 0.5
		no_shadow(a)
		round_root.add_child(a)
		var is_t := kind == target_kind
		if is_t:
			target_opt = a
		add_pickable(a, 1.8, {"name": M.ANIMALS[kind], "target": is_t, "offset": Vector3(0, 0.08, 0)})
		pop_in(a, 0.3 + k * 0.08)
	await wait(0.9)
	ready_to_answer()


static func no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		no_shadow(c)


func _similar_of(kind: String) -> Array:
	var out: Array = []
	for g in SIMILAR:
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
			# 簡單：和已選的都不像
			var ok := true
			for o in opts:
				if k in _similar_of(o):
					ok = false
			if not ok:
				continue
		opts.append(k)
	for k in rest:   # 保險：數量不夠就補
		if opts.size() >= n:
			break
		if not (k in opts):
			opts.append(k)
	return shuffled(opts)


func _add_leaf(p: Vector3, r: float) -> void:
	var c := cam.unproject_position(p)
	var rr := c.distance_to(cam.unproject_position(p + Vector3(r * 0.85, 0, 0)))
	var covers := PackedInt32Array()
	for s in _samples.size():
		if _samples[s].distance_squared_to(c) <= rr * rr:
			covers.append(s)
			_cover[s] += 1
	_leaves.append({"pos": p, "r": r, "covers": covers, "active": true, "node": null})


func _set_leaf(k: int, on: bool) -> void:
	var lf: Dictionary = _leaves[k]
	if bool(lf.active) == on:
		return
	lf.active = on
	var covers: PackedInt32Array = lf.covers
	for s in covers:
		_cover[s] += 1 if on else -1


## 目前露出比例（沒被任何葉片擋住的取樣點／全部）
func reveal() -> float:
	if _samples.is_empty():
		return 0.0
	var open := 0
	for c in _cover:
		if c <= 0:
			open += 1
	return float(open) / _samples.size()


func _blow_leaf(lf: Dictionary, far := 3.0) -> void:
	var node = lf.get("node")
	if node == null or not is_instance_valid(node):
		return
	var n3: Node3D = node
	var away := Vector3(n3.position.x - _center.x, n3.position.y - _center.y, 0).normalized()
	if away.length() < 0.1:
		away = Vector3.UP
	var tw := create_tween()
	tw.tween_property(n3, "position", n3.position + away * far + Vector3(0, 0.6, 0.5), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(n3, "rotation:z", n3.rotation.z + rng.randf_range(-3, 3), 0.6)
	tw.parallel().tween_property(n3, "scale", Vector3.ONE * 0.05, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(n3.queue_free)
	lf["node"] = null


func on_hint() -> void:
	if _done or _order.is_empty():
		return
	var start := reveal()
	var moved := 0
	while not _order.is_empty() and (reveal() < minf(1.0, start + 0.15) or moved < 2):
		var k: int = _order.pop_front()
		_set_leaf(k, false)
		_blow_leaf(_leaves[k], 2.0)
		moved += 1
	Snd.play("tick", 0.6)


func on_pick(node: Node3D, data: Dictionary) -> void:
	if _done:
		return
	if data.target:
		_done = true
		set_coverage(reveal())
		print("COVERAGE %s r%d %.3f hints=%d" % [level_id, round_i + 1, reveal(), round_hints])
		good(node)
		clear_pickables()
		for lf in _leaves:
			if lf.active:
				_blow_leaf(lf, 4.0)
		var tw := create_tween()
		tw.tween_interval(0.35)
		tw.tween_property(hidden, "position:y", HIDE_POS.y + 0.5, 0.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(hidden, "position:y", HIDE_POS.y, 0.25).set_ease(Tween.EASE_IN)
		show_toast("是%s！" % M.ANIMALS[target_kind], 1.0)
		Snd.say("bush_is_" + target_kind)
		await wait(1.6)
		finish_round()
	else:
		bad(node)
		_bot_target = null   # 自動測試：答錯後重新決定要看哪一個（不要一直選同一個錯的）


func bot_target() -> Node3D:
	# 自動測試：困難關單數回合先用一次提示（測試提示流程）
	if autoplay and not demo and diff == 2 and round_i % 2 == 0 and round_hints == 0:
		hint_used()
		on_hint()
		Gaze.bot_point = cam.unproject_position(HIDE_POS)
		return null
	return target_opt
