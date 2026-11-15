extends Level
## 海洋搜查隊｜找到那條魚（主題背景區辨）
## 海裡有很多魚游來游去，看著和目標卡一樣顏色、一樣花紋的那條魚。

const VOICE := {
	"fishfind_red_plain": "找出紅色、沒有花紋的魚。",
	"fishfind_red_stripes": "找出紅色條紋的魚。",
	"fishfind_red_dots": "找出紅色點點的魚。",
	"fishfind_orange_plain": "找出橘色、沒有花紋的魚。",
	"fishfind_orange_stripes": "找出橘色條紋的魚。",
	"fishfind_orange_dots": "找出橘色點點的魚。",
	"fishfind_yellow_plain": "找出黃色、沒有花紋的魚。",
	"fishfind_yellow_stripes": "找出黃色條紋的魚。",
	"fishfind_yellow_dots": "找出黃色點點的魚。",
	"fishfind_green_plain": "找出綠色、沒有花紋的魚。",
	"fishfind_green_stripes": "找出綠色條紋的魚。",
	"fishfind_green_dots": "找出綠色點點的魚。",
	"fishfind_purple_plain": "找出紫色、沒有花紋的魚。",
	"fishfind_purple_stripes": "找出紫色條紋的魚。",
	"fishfind_purple_dots": "找出紫色點點的魚。",
	"fishfind_pink_plain": "找出粉紅色、沒有花紋的魚。",
	"fishfind_pink_stripes": "找出粉紅色條紋的魚。",
	"fishfind_pink_dots": "找出粉紅色點點的魚。",
	"fishfind_white_plain": "找出白色、沒有花紋的魚。",
	"fishfind_white_stripes": "找出白色條紋的魚。",
	"fishfind_white_dots": "找出白色點點的魚。",
	"fishfind_brown_plain": "找出咖啡色、沒有花紋的魚。",
	"fishfind_brown_stripes": "找出咖啡色條紋的魚。",
	"fishfind_brown_dots": "找出咖啡色點點的魚。",
}
## 在海藍背景上看得清楚的顏色（不用藍色、水藍色）
const FISH_COLORS := ["red", "orange", "yellow", "green", "purple", "pink", "white", "brown"]
const FISH_PATTERNS := ["plain", "stripes", "dots"]
const PATTERN_TEXT := {"plain": "、沒有花紋", "stripes": "條紋", "dots": "點點"}
const COUNTS := [6, 10, 16]
const SIZES := [0.85, 0.74, 0.66]
const SPEEDS := [0.35, 0.5, 0.75]
const RADII := [1.05, 1.0, 0.95]
## 魚游動的範圍（AREA 內再留邊）
const SWIM := Rect2(-4.0, -3.15, 10.0, 5.35)

var fishes: Array = []        # [{node, flip, x, y0, vx, lo, hi, phase, freeze, turning}]
var target_node: Node3D
var _last := ""
var _sway: Array = []         # 會擺動的海草 [{node, phase}]
var _bubbles: Array = []      # [{node, speed, x0, phase}]


func build() -> void:
	# 更深一點的海藍（取主題牆色再暗一點，同一色系）
	backdrop_color((theme.wall as Color).lerp(theme.dark, 0.45))
	# 水面光束
	for i in 6:
		var ray := M.box(Vector3(1.2 + (i % 3) * 0.5, 16, 0.05), Color(theme.wall2), Vector3(-9 + i * 3.6, 2.5, -8.6), Vector3(0, 0, 0.25 - (i % 2) * 0.1))
		ray.material_override = _alpha_flat(Color(theme.wall2), 0.18)
		add_child(ray)
	# 遠處沙丘與岩石
	for i in 7:
		add_child(M.sphere(2.2, (theme.floor as Color).darkened(0.18), Vector3(-12 + i * 4.0, -5.9, -7.5), Vector3(1.6, 0.5, 0.4)))
	for i in 5:
		add_child(M.sphere(0.7 + (i % 2) * 0.3, theme.dark.lerp(theme.floor, 0.35), Vector3(-8 + i * 4.3, -3.9, -5.5), Vector3(1.4, 0.8, 0.8)))
	# 背景海草與珊瑚
	for i in 14:
		var sw := M.seaweed(2.4 + (i % 4) * 0.6, (theme.analog_a as Color).darkened(0.25 + 0.08 * (i % 3)))
		sw.position = Vector3(-10 + i * 1.6 + (i % 2) * 0.4, -4.4, -6.0 - (i % 3) * 0.5)
		add_child(sw)
		_sway.append({"node": sw, "phase": i * 0.7})
	var coral_c: Array = [theme.comp, theme.comp_light, theme.light, theme.analog_b]
	for i in 8:
		var co := M.coral(coral_c[i % coral_c.size()])
		co.position = Vector3(-9 + i * 2.6, -4.3, -4.5 - (i % 2) * 0.8)
		co.scale = Vector3.ONE * (1.2 + (i % 3) * 0.3)
		add_child(co)
	# 泡泡
	var bub := _alpha_mat(theme.bar, 0.45)
	for i in 18:
		var b := M.sphere(0.08 + (i % 3) * 0.05, theme.bar, Vector3(rng.randf_range(-8, 8), rng.randf_range(-4.5, 4.5), -3.0 + (i % 4) * 0.8))
		b.material_override = bub
		add_child(b)
		_bubbles.append({"node": b, "speed": rng.randf_range(0.4, 0.9), "x0": b.position.x, "phase": rng.randf() * TAU})
	# 前景海草（中等以上：會遮住部分魚）
	var fg: int = [0, 4, 7][diff]
	for i in fg:
		var sw2 := M.seaweed(3.2 + (i % 3) * 0.9, (theme.analog_a as Color).darkened(0.1 + 0.1 * (i % 3)))
		var x: float = SWIM.position.x + 0.5 + (SWIM.size.x - 1.0) * (i + 0.5) / fg + rng.randf_range(-0.4, 0.4)
		sw2.position = Vector3(x, -4.3, 1.2 + (i % 2) * 0.3)
		sw2.scale = Vector3(1.6, 1.0, 1.0)
		add_child(sw2)
		_sway.append({"node": sw2, "phase": i * 1.3})


func _alpha_flat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _alpha_mat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.roughness = 0.1
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.rim_enabled = true
	m.rim = 0.6
	return m


func _combo_name(c: String, p: String) -> String:
	if p == "plain":
		return "%s、沒有花紋" % M.COLOR_NAMES[c]
	return "%s%s" % [M.COLOR_NAMES[c], M.PATTERNS[p]]


func new_round(_i: int) -> void:
	fishes.clear()
	target_node = null
	# 目標
	var tc: String
	var tp: String
	while true:
		tc = FISH_COLORS[rng.randi() % FISH_COLORS.size()]
		tp = FISH_PATTERNS[rng.randi() % FISH_PATTERNS.size()]
		if tc + "_" + tp != _last:
			break
	_last = tc + "_" + tp
	set_target(M.fish(tc, tp), 1.45)
	set_prompt("找出「%s」的魚" % _combo_name(tc, tp), ["fishfind_%s_%s" % [tc, tp]])
	# 干擾魚
	var n: int = COUNTS[diff]
	var other_c: Array = FISH_COLORS.duplicate()
	other_c.erase(tc)
	var other_p: Array = FISH_PATTERNS.duplicate()
	other_p.erase(tp)
	var combos: Array = [[tc, tp]]
	if diff == 0:
		# 顏色都不一樣
		for c in pick_n(other_c, n - 1):
			combos.append([c, FISH_PATTERNS[rng.randi() % FISH_PATTERNS.size()]])
	else:
		for k in n - 1:
			var mode := k % 3
			if diff == 2:
				mode = k % 2          # 困難：只差一個特徵
			if mode == 0:
				combos.append([tc, other_p[rng.randi() % other_p.size()]])
			elif mode == 1:
				combos.append([other_c[rng.randi() % other_c.size()], tp])
			else:
				var c2: String = other_c[rng.randi() % other_c.size()]
				combos.append([c2, FISH_PATTERNS[rng.randi() % FISH_PATTERNS.size()]])
	combos = shuffled(combos)
	# 位置
	var size: float = SIZES[diff]
	var homes: Array
	var roam := 0.0
	if diff == 0:
		homes = grid(n, SWIM, 3)
		roam = (SWIM.size.x / 3.0 - 2.5 * size) / 2.0 - 0.1
	elif diff == 1:
		homes = grid(n, SWIM, 4)
		roam = 1.3
		for k in homes.size():
			var h: Vector3 = homes[k]
			homes[k] = h + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.35, 0.35), 0)
	else:
		homes = scatter(n, 1.15, Rect2(SWIM.position + Vector2(0.6, 0.3), SWIM.size - Vector2(1.2, 0.6)))
		while homes.size() < n:
			homes.append(Vector3(rng.randf_range(SWIM.position.x, SWIM.end.x), rng.randf_range(SWIM.position.y, SWIM.end.y), 0))
		roam = 2.2
	var half := 1.25 * size
	for k in n:
		var cc: String = combos[k][0]
		var pp: String = combos[k][1]
		var home: Vector3 = homes[k]
		var outer := Node3D.new()
		var flip := Node3D.new()
		outer.add_child(flip)
		flip.add_child(M.fish(cc, pp))
		outer.scale = Vector3.ONE * size
		var lo := maxf(SWIM.position.x + half, home.x - roam)
		var hi := minf(SWIM.end.x - half, home.x + roam)
		if hi < lo:
			hi = lo
		var x := clampf(home.x + rng.randf_range(-roam, roam) * 0.5, lo, hi)
		var z := (k * 0.09 - n * 0.045) if diff > 0 else 0.0
		outer.position = Vector3(x, home.y, z)
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		flip.scale.x = dir
		round_root.add_child(outer)
		var is_t := cc == tc and pp == tp
		if is_t:
			target_node = outer
		fishes.append({"node": outer, "flip": flip, "x": x, "y0": home.y, "vx": dir * SPEEDS[diff] * rng.randf_range(0.8, 1.2),
			"lo": lo, "hi": hi, "phase": rng.randf() * TAU, "freeze": 0.0})
		add_pickable(outer, RADII[diff], {"name": "%s的魚" % _combo_name(cc, pp), "target": is_t})
		pop_in(outer, k * 0.04)
	await wait(0.5)
	ready_to_answer()


func _process(delta: float) -> void:
	super._process(delta)
	if paused:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for s in _sway:
		var sw: Node3D = s.node
		sw.rotation.z = sin(t * 0.9 + float(s.phase)) * 0.08
	for b in _bubbles:
		var bn: Node3D = b.node
		bn.position.y += float(b.speed) * delta
		bn.position.x = float(b.x0) + sin(t * 1.5 + float(b.phase)) * 0.15
		if bn.position.y > 4.6:
			bn.position.y = -4.4
	for f in fishes:
		var node: Node3D = f.node
		if not is_instance_valid(node):
			continue
		if float(f.freeze) > 0.0:
			f.freeze = float(f.freeze) - delta
			continue
		var x: float = f.x + float(f.vx) * delta
		if x > float(f.hi) or x < float(f.lo):
			x = clampf(x, float(f.lo), float(f.hi))
			f.vx = -float(f.vx)
			_turn(f)
		f.x = x
		node.position.x = x
		node.position.y = float(f.y0) + sin(t * 1.3 + float(f.phase)) * 0.12
		node.rotation.z = cos(t * 1.3 + float(f.phase)) * 0.06 * signf(float(f.vx))


## 轉向：翻面（壓扁再展開）
func _turn(f: Dictionary) -> void:
	var flip: Node3D = f.flip
	if not is_instance_valid(flip):
		return
	var to := signf(float(f.vx))
	var tw := create_tween()
	tw.tween_property(flip, "scale:x", to, 0.35).set_trans(Tween.TRANS_SINE)


func _entry(node: Node3D) -> Dictionary:
	for f in fishes:
		if f.node == node:
			return f
	return {}


func on_pick(node: Node3D, data: Dictionary) -> void:
	var f := _entry(node)
	if data.target:
		if not f.is_empty():
			f.freeze = 999.0
		good(node)
		clear_pickables()
		await wait(0.6)
		finish_round()
	else:
		if not f.is_empty():
			f.freeze = 0.5
		bad(node)
		# 短暫停止作答（讓孩子看清楚、也讓自動測試重新選目標）
		answering = false
		await wait(0.5)
		if is_instance_valid(node) and not pickables.is_empty():
			answering = true


func bot_target() -> Node3D:
	return target_node
