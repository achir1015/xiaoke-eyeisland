extends Level
## 小柯果汁吧｜杯子藏寶（視覺記憶）
## 先掀開杯子給孩子看底下藏了什麼，杯子蓋下來以後，看著藏有指定東西的那個杯子。

const VOICE := {
	"cups_look": "看清楚，東西藏在哪一個杯子下面？",
	"cups_cover": "杯子蓋起來囉！",
	"cups_where_apple": "蘋果在哪一個杯子下面？",
	"cups_where_banana": "香蕉在哪一個杯子下面？",
	"cups_where_orange": "橘子在哪一個杯子下面？",
	"cups_where_grape": "葡萄在哪一個杯子下面？",
	"cups_where_strawberry": "草莓在哪一個杯子下面？",
	"cups_where_pear": "西洋梨在哪一個杯子下面？",
	"cups_where_cherry": "櫻桃在哪一個杯子下面？",
	"cups_where_lemon": "檸檬在哪一個杯子下面？",
	"cups_where_watermelon": "西瓜在哪一個杯子下面？",
	"cups_where_kiwi": "奇異果在哪一個杯子下面？",
	"cups_where_peach": "水蜜桃在哪一個杯子下面？",
	"cups_where_star": "星星在哪一個杯子下面？",
	"cups_where_flower": "花在哪一個杯子下面？",
	"cups_where_shell": "貝殼在哪一個杯子下面？",
}
## 可以藏的東西：fruit = M.fruit；item = M.item（比較小，放大一點）
const FRUIT_KINDS := ["apple", "banana", "orange", "grape", "strawberry", "pear", "cherry", "lemon", "watermelon", "kiwi", "peach"]
const ITEM_KINDS := ["star", "flower", "shell"]
const CUP_COUNTS := [3, 4, 6]
const HIDE_COUNTS := [1, 2, 3]
const SHOW_SECS := [2.4, 2.8, 3.2]
const CUP_SCALES := [1.25, 1.15, 1.0]
const SPACINGS := [2.9, 2.5, 1.8]
const TABLE_Y := -1.9
const ROW_X := 1.0

var cups: Array = []          # [{cup: Node3D, item: Node3D, kind: String, down_y: float, up_y: float}]
var target_cup: Node3D
var target_kind := ""
var _last_kind := ""
var _busy := false


func build() -> void:
	var wood: Color = theme.floor
	var dots: Array = [theme.analog_a, theme.light, theme.analog_b]
	# 後方吧台層架＋果汁杯（同色相深淺＋類似色點綴）
	add_child(M.box(Vector3(26, 0.25, 1.2), theme.dark, Vector3(0, 0.55, -6.5)))
	var juices: Array = [theme.base, theme.analog_a, theme.light, theme.analog_b]
	for i in 16:
		var x := -10.5 + i * 1.45
		var c: Color = juices[i % juices.size()]
		add_child(M.cyl(0.32, 0.26, 0.85, theme.bar, Vector3(x, 1.12, -6.4)))
		add_child(M.cyl(0.29, 0.24, 0.62, c, Vector3(x, 1.06, -6.25)))
		add_child(M.cyl(0.03, 0.03, 0.9, theme.dark, Vector3(x + 0.12, 1.55, -6.3), Vector3(0, 0, -0.25)))
	# 上方條紋遮陽棚（主色／淺色相間）
	for i in 24:
		var c2: Color = theme.base if i % 2 == 0 else theme.bar
		add_child(M.box(Vector3(1.0, 0.9, 0.3), c2, Vector3(-11.5 + i * 1.0, 3.9, -5.0), Vector3(0.35, 0, 0)))
		add_child(M.cyl(0.5, 0.5, 0.3, c2, Vector3(-11.5 + i * 1.0, 3.42, -4.83), Vector3(PI / 2 + 0.35, 0, 0), 16))
	# 吧台（桌面＋正面＋主色飾條）
	add_child(M.box(Vector3(11.8, 0.25, 2.6), theme.bar, Vector3(ROW_X + 0.1, TABLE_Y - 0.125, 0)))
	add_child(M.box(Vector3(11.6, 2.4, 2.4), wood, Vector3(ROW_X + 0.1, TABLE_Y - 1.45, -0.05)))
	add_child(M.box(Vector3(11.65, 0.22, 0.05), theme.base, Vector3(ROW_X + 0.1, TABLE_Y - 0.55, 1.17)))
	for i in 8:
		add_child(M.sphere(0.16, dots[i % dots.size()], Vector3(ROW_X - 4.6 + i * 1.33, TABLE_Y - 1.2, 1.18), Vector3(1, 1, 0.3)))


func _make_item(kind: String) -> Node3D:
	var n: Node3D
	if kind in ITEM_KINDS:
		n = M.item(kind)
		n.scale = Vector3.ONE * 1.5
	else:
		n = M.fruit(kind)
		n.scale = Vector3.ONE * 0.55
	var holder := Node3D.new()
	holder.add_child(n)
	return holder


func _name(kind: String) -> String:
	if M.FRUITS.has(kind):
		return M.FRUITS[kind]
	return M.ITEMS.get(kind, kind)


func new_round(_i: int) -> void:
	cups.clear()
	target_cup = null
	_busy = false
	clear_target()
	var n: int = CUP_COUNTS[diff]
	var cs: float = CUP_SCALES[diff]
	var sp: float = SPACINGS[diff]
	var pool: Array = FRUIT_KINDS + ITEM_KINDS
	var kinds: Array = pick_n(pool, HIDE_COUNTS[diff])
	# 要問的東西：避免和上一回合一樣
	var ask_choices: Array = kinds.duplicate()
	if ask_choices.size() > 1:
		ask_choices.erase(_last_kind)
	elif kinds[0] == _last_kind:
		var others: Array = pool.duplicate()
		others.erase(_last_kind)
		kinds[0] = others[rng.randi() % others.size()]
		ask_choices = [kinds[0]]
	target_kind = ask_choices[rng.randi() % ask_choices.size()]
	_last_kind = target_kind
	# 哪幾個杯子藏東西
	var slots: Array = pick_n(range(n), kinds.size())
	set_prompt("看清楚，東西藏在哪一個杯子下面？", ["cups_look"])
	var cup_c: Color = theme.base
	for k in n:
		var x := ROW_X + (k - (n - 1) / 2.0) * sp
		var kind := ""
		var si := slots.find(k)
		if si >= 0:
			kind = kinds[si]
		var item: Node3D = null
		if kind != "":
			item = _make_item(kind)
			item.scale = Vector3.ONE * cs
			item.position = Vector3(x, TABLE_Y + 0.5 * cs, 0.05)
			round_root.add_child(item)
		var cup := M.cup(cup_c)
		cup.scale = Vector3.ONE * cs
		var down_y := TABLE_Y + 0.67 * cs
		var up_y := down_y + 1.75 * cs
		cup.position = Vector3(x, up_y, 0)
		cup.rotation.z = 0.22
		round_root.add_child(cup)
		cups.append({"cup": cup, "item": item, "kind": kind, "down_y": down_y, "up_y": up_y})
		var is_t := kind == target_kind
		if is_t:
			target_cup = cup
		var label := "杯子%d（%s）" % [k + 1, _name(kind) if kind != "" else "空的"]
		add_pickable(cup, 0.95, {"name": label, "target": is_t, "slot": k})
		pop_in(cup, k * 0.05)
		if item:
			pop_in(item, 0.15 + k * 0.05)
	# 記憶展示
	await wait(SHOW_SECS[diff] + 0.4)
	if not is_inside_tree():
		return
	Snd.play("cup")
	for c in cups:
		_move_cup(c, false, 0.45)
	await wait(0.5)
	for c in cups:
		if c.item:
			(c.item as Node3D).visible = false
	await wait(0.5)
	var tgt := _make_item(target_kind)
	set_target(tgt, 1.9)
	set_prompt("%s在哪一個杯子下面？" % _name(target_kind), ["cups_where_" + target_kind])
	await wait(0.3)
	ready_to_answer()


## 掀開（up=true）或蓋下杯子
func _move_cup(c: Dictionary, up: bool, secs := 0.4) -> void:
	var cup: Node3D = c.cup
	if not is_instance_valid(cup):
		return
	var tw := create_tween().set_parallel(true)
	if up:
		tw.tween_property(cup, "position:y", float(c.up_y), secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cup, "rotation:z", 0.22, secs)
	else:
		tw.tween_property(cup, "position:y", float(c.down_y), secs).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(cup, "rotation:z", 0.0, secs * 0.8)


func _entry(cup: Node3D) -> Dictionary:
	for c in cups:
		if c.cup == cup:
			return c
	return {}


func on_pick(node: Node3D, data: Dictionary) -> void:
	if _busy:
		return
	var c := _entry(node)
	if c.is_empty():
		return
	_busy = true
	if c.item:
		(c.item as Node3D).visible = true
	Snd.play("whoosh", 0.6)
	_move_cup(c, true, 0.35)
	if data.target:
		answering = false
		clear_pickables()
		await wait(0.35)
		good(c.item if c.item else node)
		await wait(0.6)
		# 把其他杯子也掀開，看看全部
		for o in cups:
			if o != c:
				if o.item:
					(o.item as Node3D).visible = true
				_move_cup(o, true, 0.35)
		await wait(0.9)
		finish_round()
	else:
		answering = false
		await wait(0.3)
		bad(node)
		await wait(1.2)
		if not is_instance_valid(node):
			return
		Snd.play("cup")
		_move_cup(c, false, 0.4)
		await wait(0.45)
		if c.item and is_instance_valid(c.item):
			(c.item as Node3D).visible = false
		_busy = false
		answering = true


func bot_target() -> Node3D:
	return target_cup
