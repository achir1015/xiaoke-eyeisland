extends Level
## 彩虹遊樂場｜旋轉木馬找表情（視覺辨識）
## 旋轉木馬上坐著好多張臉，看著和目標卡一樣表情的那張臉。

const VOICE := {
	"carousel_find_happy": "找出開心的臉。",
	"carousel_find_laugh": "找出哈哈大笑的臉。",
	"carousel_find_sad": "找出難過的臉。",
	"carousel_find_angry": "找出生氣的臉。",
	"carousel_find_surprised": "找出驚訝的臉。",
	"carousel_find_sleepy": "找出想睡覺的臉。",
	"carousel_find_scared": "找出害怕的臉。",
}
const POOLS := [["happy", "sad"], ["happy", "sad", "angry", "surprised"], ["happy", "laugh", "sad", "angry", "surprised", "sleepy", "scared"]]
const SIMILAR := {"happy": ["laugh", "sleepy"], "laugh": ["happy"], "sad": ["scared", "sleepy"], "scared": ["sad", "surprised"],
	"surprised": ["scared"], "angry": ["sad"], "sleepy": ["happy", "sad"]}
const COUNTS := [4, 6, 8]
const SPEEDS := [0.12, 0.22, 0.32]

var ring: Node3D
var target_expr := ""
var target_node: Node3D
var _last_expr := ""


func build() -> void:
	var acc: Array = theme.accent
	# 背景三角彩旗（主題色系）
	for i in 22:
		var f := M.cyl(0.0, 0.32, 0.55, Color(acc[i % acc.size()]), Vector3(-11 + i * 1.05, 3.3 - absf(i - 10.5) * 0.03, -8.6), Vector3(PI, 0, 0), 3)
		add_child(f)
	var carousel := Node3D.new()
	carousel.position = Vector3(1.0, -1.0, -2.5)
	carousel.rotation.x = 0.42
	add_child(carousel)
	var base := M.cyl(5.4, 5.6, 0.5, Color(acc[0]), Vector3(0, -0.6, 0), Vector3.ZERO, 40)
	carousel.add_child(base)
	carousel.add_child(M.cyl(5.0, 5.0, 0.55, Color(theme.bar), Vector3(0, -0.55, 0), Vector3.ZERO, 40))
	carousel.add_child(M.cyl(0.25, 0.25, 3.0, Color(acc[2]), Vector3(0, 0.8, 0)))
	ring = Node3D.new()
	carousel.add_child(ring)


func new_round(i: int) -> void:
	for c in ring.get_children():
		c.queue_free()
	var pool: Array = POOLS[diff]
	var choices := pool.duplicate()
	choices.erase(_last_expr)
	target_expr = choices[rng.randi() % choices.size()]
	_last_expr = target_expr
	set_target(M.face(target_expr), 1.8)
	set_prompt("找出「%s」的臉" % M.EXPRESSIONS[target_expr], ["carousel_find_" + target_expr])
	var n: int = COUNTS[diff]
	var others := pool.duplicate()
	others.erase(target_expr)
	var exprs: Array = [target_expr]
	for k in n - 1:
		var e: String
		if diff == 2 and k < 3 and SIMILAR.has(target_expr):
			var sim: Array = SIMILAR[target_expr]
			e = sim[k % sim.size()]
		else:
			e = others[(k + rng.randi()) % others.size()]
		exprs.append(e)
	exprs = shuffled(exprs)
	ring.rotation.y = rng.randf() * TAU
	for k in n:
		var a := TAU * k / n
		var seat := Node3D.new()
		seat.position = Vector3(cos(a) * 4.2, 0, sin(a) * 4.2)
		ring.add_child(seat)
		seat.add_child(M.cyl(0.07, 0.07, 3.6, Color(theme.accent[2]).darkened(0.1), Vector3(0, 1.3, 0)))
		var horse := M.sphere(0.6, Color(theme.accent[k % 4]).lightened(0.35), Vector3(0, 0.15, 0), Vector3(1.4, 0.6, 0.7))
		seat.add_child(horse)
		var f := M.face(exprs[k])
		f.position = Vector3(0, 1.25, 0)
		f.scale = Vector3.ONE * 0.85
		seat.add_child(f)
		seat.set_meta("face", f)
		var is_t: bool = exprs[k] == target_expr
		if is_t:
			target_node = f
		add_pickable(f, 1.0, {"name": M.EXPRESSIONS[exprs[k]], "target": is_t})
		pop_in(f, k * 0.06)
	await wait(0.5)
	ready_to_answer()


func _process(delta: float) -> void:
	super._process(delta)
	if ring and not paused:
		ring.rotation.y += SPEEDS[diff] * delta
		for seat in ring.get_children():
			var f: Node3D = seat.get_meta("face", null)
			if f:
				f.global_basis = Basis().scaled(f.global_basis.get_scale())


func on_pick(node: Node3D, data: Dictionary) -> void:
	if data.target:
		good(node)
		clear_pickables()
		await wait(0.6)
		finish_round()
	else:
		bad(node)


func bot_target() -> Node3D:
	return target_node
