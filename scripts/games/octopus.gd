extends Level
## 海洋搜查隊｜章魚小偵探（主題背景區辨／特徵結合搜尋）
## 每隻章魚戴不同顏色的帽子、拿不同的東西，找出題目說的那一隻。

const VOICE := {
	"octopus_hat_red": "找出戴紅色帽子的章魚。",
	"octopus_hat_blue": "找出戴藍色帽子的章魚。",
	"octopus_hat_yellow": "找出戴黃色帽子的章魚。",
	"octopus_hat_green": "找出戴綠色帽子的章魚。",
	"octopus_hat_white": "找出戴白色帽子的章魚。",
	"octopus_red_star": "找出戴紅色帽子、拿著星星的章魚。",
	"octopus_red_fishy": "找出戴紅色帽子、拿著小魚的章魚。",
	"octopus_red_flower": "找出戴紅色帽子、拿著花的章魚。",
	"octopus_red_balloon": "找出戴紅色帽子、拿著氣球的章魚。",
	"octopus_red_shell": "找出戴紅色帽子、拿著貝殼的章魚。",
	"octopus_blue_star": "找出戴藍色帽子、拿著星星的章魚。",
	"octopus_blue_fishy": "找出戴藍色帽子、拿著小魚的章魚。",
	"octopus_blue_flower": "找出戴藍色帽子、拿著花的章魚。",
	"octopus_blue_balloon": "找出戴藍色帽子、拿著氣球的章魚。",
	"octopus_blue_shell": "找出戴藍色帽子、拿著貝殼的章魚。",
	"octopus_yellow_star": "找出戴黃色帽子、拿著星星的章魚。",
	"octopus_yellow_fishy": "找出戴黃色帽子、拿著小魚的章魚。",
	"octopus_yellow_flower": "找出戴黃色帽子、拿著花的章魚。",
	"octopus_yellow_balloon": "找出戴黃色帽子、拿著氣球的章魚。",
	"octopus_yellow_shell": "找出戴黃色帽子、拿著貝殼的章魚。",
	"octopus_green_star": "找出戴綠色帽子、拿著星星的章魚。",
	"octopus_green_fishy": "找出戴綠色帽子、拿著小魚的章魚。",
	"octopus_green_flower": "找出戴綠色帽子、拿著花的章魚。",
	"octopus_green_balloon": "找出戴綠色帽子、拿著氣球的章魚。",
	"octopus_green_shell": "找出戴綠色帽子、拿著貝殼的章魚。",
	"octopus_white_star": "找出戴白色帽子、拿著星星的章魚。",
	"octopus_white_fishy": "找出戴白色帽子、拿著小魚的章魚。",
	"octopus_white_flower": "找出戴白色帽子、拿著花的章魚。",
	"octopus_white_balloon": "找出戴白色帽子、拿著氣球的章魚。",
	"octopus_white_shell": "找出戴白色帽子、拿著貝殼的章魚。",
}
const HATS := ["red", "blue", "yellow", "green", "white"]
const COUNTS := [4, 6, 9]
const SCALES := [1.0, 0.95, 0.85]

var target_node: Node3D
var _last := ""
var _bob: Array = []          # [{node, y, ph}]
var _bubbles: Array = []      # [{node, v, x}]
var _sway: Array = []         # [{node, ph}]


func build() -> void:
	var weed: Color = theme.analog_b
	# 背景：遠處的海草、珊瑚、岩石（主題色系）
	for i in 9:
		var sw := M.seaweed(rng.randf_range(2.2, 3.6), weed.lerp(theme.wall, 0.35))
		sw.position = Vector3(-10.5 + i * 2.6 + rng.randf_range(-0.4, 0.4), -4.5, -7.5)
		add_child(sw)
		_sway.append({"node": sw, "ph": rng.randf() * TAU})
	for i in 6:
		var co := M.coral((theme.comp as Color).lerp(theme.wall, 0.45) if i % 2 == 0 else (theme.analog_a as Color).lerp(theme.wall, 0.3))
		co.position = Vector3(-9.0 + i * 3.6, -4.4, -6.5)
		co.scale = Vector3.ONE * 1.4
		add_child(co)
	for i in 5:
		var rock := M.sphere(1.0, (theme.floor as Color).darkened(0.15), Vector3(-9 + i * 4.5, -4.5, -5.5), Vector3(1.6, 0.6, 0.6))
		add_child(rock)
	# 背景小氣泡（緩緩往上）
	for i in 14:
		var b := M.sphere(rng.randf_range(0.08, 0.2), theme.bar, Vector3(rng.randf_range(-9, 9), rng.randf_range(-4, 4), -7.0))
		b.material_override = M.mat(theme.bar, 0.2, 0.0, 0.45)
		add_child(b)
		_bubbles.append({"node": b, "v": rng.randf_range(0.25, 0.6), "x": b.position.x})


func new_round(_i: int) -> void:
	_bob.clear()
	# 上一回合的前景物件（round_root 已排程清除）
	_bubbles = _bubbles.filter(func(e): return not e.get("fg", false))
	_sway = _sway.filter(func(e): return not e.get("fg", false))
	var n: int = COUNTS[diff]
	var items: Array = M.ITEMS.keys()
	# 題目（不和上一回合一樣）
	var th: String
	var ti: String
	while true:
		th = HATS[rng.randi() % HATS.size()]
		ti = items[rng.randi() % items.size()]
		var key := th if diff == 0 else th + "_" + ti
		if key != _last:
			_last = key
			break
	var combos: Array = [[th, ti]]
	if diff == 0:
		# 帽子顏色都不同，手上的東西隨意
		var hats := HATS.duplicate()
		hats.erase(th)
		for h in pick_n(hats, n - 1):
			combos.append([h, items[rng.randi() % items.size()]])
	else:
		var other_items := items.duplicate()
		other_items.erase(ti)
		var other_hats := HATS.duplicate()
		other_hats.erase(th)
		var same_hat := 2 if diff == 1 else 4
		var same_item := 2 if diff == 1 else 4
		for it in pick_n(other_items, same_hat):
			combos.append([th, it])
		for h in pick_n(other_hats, same_item):
			combos.append([h, ti])
		while combos.size() < n:
			var c := [other_hats[rng.randi() % other_hats.size()], other_items[rng.randi() % other_items.size()]]
			var dup := false
			for e in combos:
				if e[0] == c[0] and e[1] == c[1]:
					dup = true
			if not dup:
				combos.append(c)
	combos = shuffled(combos)
	# 目標卡
	var card := M.octopus(th, ti)
	card.position = Vector3(-0.12, -0.35, 0)
	no_shadow(card)
	set_target(card, 1.55)
	var hn: String = M.COLOR_NAMES[th]
	if diff == 0:
		set_prompt("找出戴「%s帽子」的章魚" % hn, ["octopus_hat_" + th])
	else:
		set_prompt("找出戴「%s帽子」、拿著「%s」的章魚" % [hn, M.ITEMS[ti]], ["octopus_%s_%s" % [th, ti]])
	# 位置
	var s: float = SCALES[diff]
	var pos: Array = []
	if diff == 0:
		pos = grid(n, Rect2(-4.0, -2.4, 10.0, 4.4), 4)
	elif diff == 1:
		pos = grid(n, Rect2(-4.1, -3.6, 10.2, 6.0), 3)
	else:
		# 三排擠在一起，前後錯開、互相重疊
		for r in 3:
			for c in 3:
				var x := -2.7 + c * 3.0 + (0.75 if r == 1 else -0.2) + rng.randf_range(-0.3, 0.3)
				var y := 1.7 - r * 1.95 + rng.randf_range(-0.1, 0.1)
				pos.append(Vector3(x, y, 0.1 + r * 0.25 + rng.randf_range(0, 0.1)))
		pos = shuffled(pos)
	for k in n:
		var hat: String = combos[k][0]
		var it: String = combos[k][1]
		var body := Color("#E599F7")
		if diff == 2:
			body = [Color("#E599F7"), Color("#DA77F2"), Color("#F783AC"), Color("#B197FC")][k % 4]
		var o := M.octopus(hat, it, body)
		var p: Vector3 = pos[k]
		o.position = Vector3(p.x - 0.25 * s, p.y - 0.4 * s, p.z)
		o.scale = Vector3.ONE * s
		o.rotation.z = rng.randf_range(-0.08, 0.08)
		round_root.add_child(o)
		var is_t: bool = hat == th and it == ti
		if is_t:
			target_node = o
		var nm := "%s帽子＋%s" % [M.COLOR_NAMES[hat], M.ITEMS[it]]
		add_pickable(o, 0.95 if diff < 2 else 0.85, {"name": nm, "target": is_t, "offset": Vector3(0.2 * s, 0.35 * s, 0)})
		pop_in(o, k * 0.06)
		_bob.append({"node": o, "y": o.position.y, "ph": rng.randf() * TAU})
	if diff == 2:
		_foreground()
	await wait(0.4 + n * 0.06)
	ready_to_answer()


## 困難關：前景的泡泡和海草（部分擋住章魚）
func _foreground() -> void:
	for k in 4:
		var sw := M.seaweed(rng.randf_range(2.0, 2.8), (theme.analog_b as Color).lerp(theme.dark, 0.3))
		sw.position = Vector3(-3.6 + k * 3.1 + rng.randf_range(-0.4, 0.4), -4.3, 2.2)
		round_root.add_child(sw)
		_sway.append({"node": sw, "ph": rng.randf() * TAU, "fg": true})
	for k in 9:
		var r := rng.randf_range(0.22, 0.45)
		var b := M.sphere(r, theme.bar, Vector3(rng.randf_range(-4.0, 6.0), rng.randf_range(-3.5, 2.4), 2.5))
		b.material_override = M.mat(theme.bar, 0.1, 0.0, 0.38)
		round_root.add_child(b)
		_bubbles.append({"node": b, "v": rng.randf_range(0.2, 0.45), "x": b.position.x, "fg": true})


static func no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		no_shadow(c)


func _process(delta: float) -> void:
	super._process(delta)
	if paused:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for e in _bob:
		if is_instance_valid(e.node):
			var o: Node3D = e.node
			o.position.y = float(e.y) + sin(t * 1.6 + float(e.ph)) * 0.07
	for e in _bubbles:
		if not is_instance_valid(e.node):
			continue
		var b: Node3D = e.node
		b.position.y += float(e.v) * delta
		b.position.x = float(e.x) + sin(t + float(e.x)) * 0.15
		if b.position.y > 3.4:
			b.position.y = -4.2
	for e in _sway:
		if is_instance_valid(e.node):
			var sw: Node3D = e.node
			sw.rotation.z = sin(t * 0.9 + float(e.ph)) * 0.08


func on_pick(node: Node3D, data: Dictionary) -> void:
	if data.target:
		good(node)
		clear_pickables()
		await wait(0.6)
		finish_round()
	else:
		bad(node)
		_bot_target = null   # 自動測試：答錯後重新決定要看哪一個（不要一直選同一個錯的）


func bot_target() -> Node3D:
	return target_node
