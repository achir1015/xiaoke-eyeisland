extends Level
## 積木工坊｜分類收納箱（視覺空間關係）
## 中間出現一個積木，看著和它一樣的收納箱，積木就會飛進去。每個積木算一回合。
## 簡單：2 箱依顏色；中等：3 箱依形狀；困難：4 箱顏色＋形狀都要對。

const VOICE := {
	"sort_which": "這個積木要放進哪個箱子？",
	"sort_by_color": "把它放進一樣顏色的箱子。",
	"sort_by_shape": "把它放進一樣形狀的箱子。",
	"sort_by_both": "顏色和形狀都要一樣喔。",
}
const RULE_VOICE := ["sort_by_color", "sort_by_shape", "sort_by_both"]
const RULE_TEXT := ["放進一樣顏色的箱子", "放進一樣形狀的箱子", "顏色和形狀都要一樣"]
const SHAPES_ALL := ["cube", "ball", "star", "heart", "cylinder", "cone"]
const SHAPES_SORT := ["cube", "ball", "star", "heart", "cone"]
const BLOCK_COLORS := ["red", "blue", "yellow", "green", "purple", "orange"]
const BIN_Y := -2.45
const BLOCK_POS := Vector3(1.0, 0.85, 0.6)

var bins_root: Node3D
var bins: Array = []            # [{node, color, shape, name, count}]
var queue: Array = []           # 每回合要分的積木（bins 的索引）
var block: Node3D
var block_color := ""
var block_shape := ""
var answer_bin: Node3D
var _spin := false


func build() -> void:
	var deco := [theme.base, theme.analog_a, theme.analog_b, theme.light]
	# 背景兩側堆疊的玩具積木
	for side in [-1, 1]:
		var x0: float = 9.6 * side
		var k := 0
		for row in 4:
			for c in 4 - row:
				var col: Color = deco[(k + (0 if side < 0 else 2)) % deco.size()]
				var b := M.box(Vector3.ONE * 1.25, col, Vector3(x0 + (c - (3 - row) / 2.0) * 1.35 * side, -3.7 + row * 1.3, -7.6), Vector3(0, 0.15 * side, 0))
				add_child(b)
				k += 1
	# 上方一排字母積木風格的小方塊
	for i in 18:
		var col: Color = deco[i % deco.size()]
		add_child(M.box(Vector3(0.7, 0.7, 0.7), col, Vector3(-10.2 + i * 1.2, 3.55, -8.2), Vector3(0.2, 0.3 * ((i % 3) - 1), 0)))
	# 積木出現的展示圓盤
	var plate := M.cyl(1.25, 1.25, 0.12, theme.bar, BLOCK_POS + Vector3(0, 0, -1.4), Vector3(PI / 2, 0, 0), 40)
	plate.material_override = M.flat(theme.bar)
	add_child(plate)
	var ring := M.torus(1.22, 1.4, theme.base, BLOCK_POS + Vector3(0, 0, -1.3), Vector3(PI / 2, 0, 0))
	add_child(ring)
	bins_root = Node3D.new()
	bins_root.name = "Bins"
	add_child(bins_root)


func _make_bins() -> void:
	for c in bins_root.get_children():
		c.queue_free()
	bins.clear()
	var defs: Array = []
	match diff:
		0:
			for c in ["red", "blue"]:
				defs.append({"color": c, "shape": "", "name": "%s箱子" % M.COLOR_NAMES[c]})
		1:
			for s in pick_n(SHAPES_SORT, 3):
				defs.append({"color": "", "shape": s, "name": "%s箱子" % M.SHAPES[s]})
		_:
			var cs := pick_n(["red", "blue", "yellow", "green"], 2)
			var ss := pick_n(["cube", "ball", "star", "heart"], 2)
			for c in cs:
				for s in ss:
					defs.append({"color": c, "shape": s, "name": "%s%s箱子" % [M.COLOR_NAMES[c], M.SHAPES[s]]})
			defs = shuffled(defs)
	var n := defs.size()
	var gap: float = [4.4, 3.3, 2.65][diff]
	for k in n:
		var d: Dictionary = defs[k]
		var sign_node: Node3D
		match diff:
			0:
				# 一大塊顏料
				sign_node = Node3D.new()
				sign_node.add_child(M.sphere(0.75, d.color, Vector3.ZERO, Vector3(1.2, 1.0, 0.3)))
				for a in 5:
					var ang := TAU * a / 5.0 + 0.3
					sign_node.add_child(M.sphere(0.22, d.color, Vector3(cos(ang) * 0.85, sin(ang) * 0.72, 0), Vector3(1, 1, 0.3)))
			1:
				sign_node = M.shape(d.shape, theme.dark)
			_:
				sign_node = M.shape(d.shape, d.color)
		# 外殼：簡單關直接用分類色（題目特徵），其他關用主題深色（中性，不暗示答案）
		var shell: Color = M.col(d.color) if diff == 0 else theme.wall
		var b := M.bin(shell, sign_node)
		b.position = Vector3(1.0 + (k - (n - 1) / 2.0) * gap, BIN_Y, 0.2)
		b.rotation.x = 0.22
		bins_root.add_child(b)
		# 箱口邊條
		var rim_c: Color = shell.lightened(0.25) if diff == 0 else theme.base
		b.add_child(M.box(Vector3(2.1, 0.14, 0.16), rim_c, Vector3(0, 0.62, 0.58)))
		d["node"] = b
		d["count"] = 0
		bins.append(d)
		pop_in(b, k * 0.08)
	# 6 個積木：每個箱子至少一個，其餘隨機，不連續同一箱太多次
	queue.clear()
	var pool: Array = range(n)
	while pool.size() < rounds:
		pool.append(rng.randi() % n)
	queue = shuffled(pool)


func new_round(i: int) -> void:
	if i == 0 or bins.is_empty():
		_make_bins()
		await wait(0.5)
	var bi: int = queue[i % queue.size()]
	var target: Dictionary = bins[bi]
	answer_bin = target.node
	block_color = target.color if target.color != "" else BLOCK_COLORS[rng.randi() % BLOCK_COLORS.size()]
	if target.shape != "":
		block_shape = target.shape
	else:
		block_shape = SHAPES_ALL[rng.randi() % SHAPES_ALL.size()]
	block = M.shape(block_shape, block_color, 1.15)
	block.position = BLOCK_POS
	round_root.add_child(block)
	pop_in(block)
	_spin = true
	for d in bins:
		add_pickable(d.node, 1.15, {"name": d.name, "target": d.node == answer_bin, "offset": Vector3(0, 0.1, 0)})
	var voice: Array = [RULE_VOICE[diff]] if i == 0 else ["sort_which"]
	set_prompt("這個積木要放進哪個箱子？（%s）" % RULE_TEXT[diff], voice)
	await wait(0.45)
	ready_to_answer()


func _process(delta: float) -> void:
	super._process(delta)
	if _spin and is_instance_valid(block) and not paused:
		block.rotation.y = sin(Time.get_ticks_msec() / 700.0) * 0.45
		block.position.y = BLOCK_POS.y + sin(Time.get_ticks_msec() / 400.0) * 0.08


func on_pick(node: Node3D, data: Dictionary) -> void:
	if not data.target:
		bad(node)
		_bot_target = null  # 自動測試：答錯後重新決定要看哪個
		return
	clear_pickables()
	_spin = false
	var d: Dictionary = {}
	for b in bins:
		if b.node == node:
			d = b
	var slot: int = d.get("count", 0)
	d["count"] = slot + 1
	# 飛進箱子：先飛到箱子上方，再落進去
	var above := node.to_global(Vector3(0, 1.6, 0))
	var inside := node.to_global(Vector3((slot % 3 - 1) * 0.5, 0.45, -0.05))
	var mid := (block.global_position + above) / 2.0 + Vector3(0, 0.8, 0.6)
	var tw := create_tween()
	tw.tween_property(block, "global_position", mid, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(block, "global_position", above, 0.22).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(block, "scale", Vector3.ONE * 0.55, 0.44)
	tw.parallel().tween_property(block, "rotation:y", block.rotation.y + PI, 0.44)
	tw.tween_property(block, "global_position", inside, 0.2).set_ease(Tween.EASE_IN)
	await tw.finished
	if is_instance_valid(block) and is_instance_valid(node):
		block.reparent(node, true)
	good(node)
	await wait(0.6)
	finish_round()


func bot_target() -> Node3D:
	return answer_bin
