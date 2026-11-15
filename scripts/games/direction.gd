extends Level
## 積木工坊｜方向找一找（視覺空間關係）
## 左邊目標卡放一個有方向的東西，找出方向「一模一樣」的那一個。
## 簡單：小汽車四個方向；中等：箭頭八個方向；困難：格子積木，選項有旋轉也有鏡像翻面。

const VOICE := {
	"direction_find_car": "找出車頭方向一模一樣的小汽車。",
	"direction_find_arrow": "找出箭頭方向一模一樣的。",
	"direction_find_block": "找出方向一模一樣的積木。小心，有的積木翻面了喔。",
}

const COUNTS := [3, 4, 5]
const OPT_RECT := Rect2(-4.0, -3.55, 10.1, 5.9)
## 題目本身的顏色（避開背景的藍色系，比較醒目）
const CAR_COLORS := ["red", "green", "orange", "purple", "yellow"]
const ITEM_COLORS := ["red", "orange", "green", "purple"]
const CAR_DIRS := ["朝右", "朝上", "朝左", "朝下"]
const ARROW_DIRS := ["右", "右上", "上", "左上", "左", "左下", "下", "右下"]
## 不對稱（沒有旋轉對稱、也不是左右對稱）的格子積木；第一格會有白色圓點
const BLOCK_SHAPES := {
	"L": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0)],
	"P": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 1), Vector2i(1, 2)],
	"F": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 1), Vector2i(2, 2)],
	"N": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	"Y": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 2)],
}

var target_node: Node3D
var _last_key := ""
var _shape_cells: Array = []
var _color: Color = Color.WHITE


func build() -> void:
	var deco: Array = [theme.base, theme.light, theme.analog_a, theme.analog_b]
	# 背景：後方堆疊的玩具積木塔
	for i in 15:
		var x := -13.0 + i * 1.85
		var h := 1 + (i * 5 + 1) % 3
		for k in h:
			var c: Color = Color(deco[(i + k) % deco.size()]).lightened(0.2)
			var b := M.box(Vector3(1.25, 0.72, 0.7), c, Vector3(x + (k % 2) * 0.25, -4.12 + k * 0.74, -7.6))
			add_child(b)
			add_child(M.cyl(0.16, 0.16, 0.14, c, Vector3(x + (k % 2) * 0.25 - 0.3, -4.12 + k * 0.74 + 0.42, -7.6)))
			add_child(M.cyl(0.16, 0.16, 0.14, c, Vector3(x + (k % 2) * 0.25 + 0.3, -4.12 + k * 0.74 + 0.42, -7.6)))
	# 上方一排小方塊彩帶
	for i in 26:
		var c2: Color = deco[i % deco.size()]
		add_child(M.box(Vector3(0.5, 0.5, 0.2), c2, Vector3(-12.5 + i * 1.0, 4.75 - absf(i - 12.5) * 0.02, -8.6), Vector3(0, 0, PI / 4)))


# ---------------------------------------------------------------- 模型
static func arrow(c) -> Node3D:
	var n := Node3D.new()
	n.add_child(M.cyl(0.19, 0.19, 0.95, c, Vector3(-0.3, 0, 0), Vector3(0, 0, PI / 2)))
	n.add_child(M.cyl(0.0, 0.46, 0.75, c, Vector3(0.5, 0, 0), Vector3(0, 0, -PI / 2), 24))
	n.add_child(M.cyl(0.22, 0.22, 0.14, M.col(c).darkened(0.25), Vector3(-0.77, 0, 0), Vector3(0, 0, PI / 2)))
	return n


func _make(spec: Dictionary) -> Node3D:
	var steps: int = spec.rot
	var m: Node3D
	match diff:
		0:
			# 朝左用左右翻轉（輪子保持朝下），上／下才用旋轉
			m = Node3D.new()
			var car := M.car(_color)
			m.add_child(car)
			if steps % 4 == 2:
				car.scale.x = -1.0
			else:
				car.rotation.z = steps * PI / 2
		1:
			m = arrow(_color)
			m.rotation.z = steps * PI / 4
		_:
			var cells: Array = []
			for p in _shape_cells:
				var v: Vector2i = p
				cells.append(Vector2i(-v.x, v.y) if spec.mirror else v)
			var ext := 0
			for p in _shape_cells:
				var v: Vector2i = p
				ext = maxi(ext, maxi(v.x, v.y) + 1)
			m = M.blocks(cells, _color, 0.5 if ext <= 3 else 0.4)
			m.rotation = Vector3(-0.22, 0.18, steps * PI / 2)
	var wrap := Node3D.new()
	wrap.add_child(m)
	return wrap


func _name(spec: Dictionary) -> String:
	var steps: int = spec.rot
	match diff:
		0:
			return "車頭" + CAR_DIRS[steps]
		1:
			return "箭頭朝" + ARROW_DIRS[steps]
	var s := "翻面" if spec.mirror else ""
	if steps != 0:
		s += ("＋" if s != "" else "") + "轉%d度" % (steps * 90)
	return s if s != "" else "一模一樣"


# ---------------------------------------------------------------- 回合
func new_round(_i: int) -> void:
	var n: int = COUNTS[diff]
	var opts: Array = []
	var t_rot := 0
	match diff:
		0:
			_color = M.col(CAR_COLORS[rng.randi() % CAR_COLORS.size()])
			t_rot = _pick_rot(4)
			var others: Array = []
			for r in 4:
				if r != t_rot:
					others.append({"rot": r, "mirror": false, "target": false})
			opts = pick_n(others, n - 1)
		1:
			_color = M.col(ITEM_COLORS[rng.randi() % ITEM_COLORS.size()])
			t_rot = _pick_rot(8)
			var near: Array = []
			var far: Array = []
			for r in 8:
				if r == t_rot:
					continue
				var d := absi(r - t_rot)
				d = mini(d, 8 - d)
				if d == 1:
					near.append({"rot": r, "mirror": false, "target": false})
				else:
					far.append({"rot": r, "mirror": false, "target": false})
			# 一個相鄰（差 45 度）的方向，其他隨機
			opts = pick_n(near, 1) + pick_n(far, n - 2)
		_:
			_color = M.col(ITEM_COLORS[rng.randi() % ITEM_COLORS.size()])
			var keys: Array = BLOCK_SHAPES.keys()
			var key: String = keys[rng.randi() % keys.size()]
			if key == _last_key:
				key = keys[(keys.find(key) + 1 + rng.randi() % (keys.size() - 1)) % keys.size()]
			_last_key = key
			_shape_cells = BLOCK_SHAPES[key]
			t_rot = rng.randi() % 4
			var rots: Array = []
			var mirs: Array = []
			for r in 4:
				if r != t_rot:
					rots.append({"rot": r, "mirror": false, "target": false})
				if r != t_rot:
					mirs.append({"rot": r, "mirror": true, "target": false})
			# 一定有「同方向但翻面」的，再加一個翻面、兩個旋轉
			opts = [{"rot": t_rot, "mirror": true, "target": false}] + pick_n(mirs, 1) + pick_n(rots, n - 3)
	var t_spec := {"rot": t_rot, "mirror": false, "target": true}
	opts.append(t_spec)
	opts = shuffled(opts)
	set_target(_make(t_spec), 1.7)
	match diff:
		0:
			set_prompt("找出車頭方向一模一樣的小汽車", ["direction_find_car"])
		1:
			set_prompt("找出箭頭方向一模一樣的", ["direction_find_arrow"])
		_:
			set_prompt("找出方向一模一樣的積木（小心翻面的）", ["direction_find_block"])
	var cols := n if n <= 4 else 3
	var pos := grid(n, OPT_RECT, cols)
	var pad_c := Color(theme.bar)
	for k in n:
		var spec: Dictionary = opts[k]
		var w := Node3D.new()
		w.position = pos[k]
		round_root.add_child(w)
		w.add_child(M.box(Vector3(2.2, 2.2, 0.12), theme.base, Vector3(0, 0, -0.6)))
		w.add_child(M.box(Vector3(2.0, 2.0, 0.14), pad_c, Vector3(0, 0, -0.55)))
		var m := _make(spec)
		m.scale = Vector3.ONE * [0.9, 0.88, 0.95][diff]
		w.add_child(m)
		if spec.target:
			target_node = w
		add_pickable(w, 1.05, {"name": _name(spec), "target": spec.target})
		pop_in(w, k * 0.07)
	await wait(0.5)
	ready_to_answer()


func _pick_rot(count: int) -> int:
	var r := rng.randi() % count
	var key := "%d_%d" % [diff, r]
	if key == _last_key:
		r = (r + 1 + rng.randi() % (count - 1)) % count
		key = "%d_%d" % [diff, r]
	_last_key = key
	return r


func on_pick(node: Node3D, data: Dictionary) -> void:
	if data.target:
		good(node)
		clear_pickables()
		await wait(0.6)
		finish_round()
	else:
		bad(node)
		_bot_target = null  # 自動測試：答錯後重新選目標（基底的 bot 會一直看著同一個）


func bot_target() -> Node3D:
	return target_node
