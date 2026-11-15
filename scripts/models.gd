class_name M
extends RefCounted
## 程序化 3D 模型（全部用程式組成，可自由變換表情、顏色、花紋、帽子，方便做辨識題）。
## 慣例：模型面向 +Z（鏡頭），高度約 2 個單位，原點在模型中心。

static var _mats := {}

const COLORS := {
	"red": Color("#F2545B"), "orange": Color("#FF9F43"), "yellow": Color("#FFD43B"), "green": Color("#51CF66"),
	"blue": Color("#4C9AFF"), "purple": Color("#9775FA"), "pink": Color("#FF8CC6"), "white": Color("#F8F9FA"),
	"brown": Color("#A0703C"), "black": Color("#2B2B33"), "gray": Color("#ADB5BD"), "cyan": Color("#3BC9DB"),
}
const COLOR_NAMES := {"red": "紅色", "orange": "橘色", "yellow": "黃色", "green": "綠色", "blue": "藍色", "purple": "紫色",
	"pink": "粉紅色", "white": "白色", "brown": "咖啡色", "black": "黑色", "gray": "灰色", "cyan": "水藍色"}

const SKIN := Color("#FFD66B")
const DARK := Color("#3A2A2A")


static func col(c) -> Color:
	if c is Color:
		return c
	return COLORS.get(str(c), Color(str(c)) if str(c).begins_with("#") else Color.WHITE)


static func mat(c, rough := 0.55, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var cc := col(c)
	var key := "%s_%.2f_%.2f_%.2f" % [cc.to_html(), rough, emission, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cc.r, cc.g, cc.b, alpha)
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.5
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = cc
		m.emission_energy_multiplier = emission
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


## 不受光照的純色材質（背景用，顏色準確不泛白）
static func flat(c) -> StandardMaterial3D:
	var cc := col(c)
	var key := "flat_" + cc.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = cc
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func _mi(mesh: Mesh, c, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c) if not (c is Material) else c
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	return mi


static func sphere(r: float, c, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return _mi(s, c, pos, scl)


static func box(size: Vector3, c, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(b, c, pos, Vector3.ONE, rot)


static func cyl(top: float, bottom: float, h: float, c, pos := Vector3.ZERO, rot := Vector3.ZERO, seg := 20) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	return _mi(m, c, pos, Vector3.ONE, rot)


static func torus(inner: float, outer: float, c, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return _mi(t, c, pos, Vector3.ONE, rot)


## 沿著點列做一條圓管（嘴巴、眉毛、觸手、香蕉…）
static func tube(pts: PackedVector3Array, radius: float, c, taper := 1.0) -> Node3D:
	var root := Node3D.new()
	if pts.size() < 2:
		return root
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 8
	var n := pts.size()
	var up := Vector3.UP
	var rings: Array = []
	for i in n:
		var tdir: Vector3
		if i == 0:
			tdir = (pts[1] - pts[0]).normalized()
		elif i == n - 1:
			tdir = (pts[n - 1] - pts[n - 2]).normalized()
		else:
			tdir = (pts[i + 1] - pts[i - 1]).normalized()
		if absf(tdir.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var bx := tdir.cross(up).normalized()
		var by := bx.cross(tdir).normalized()
		var r := radius * lerpf(1.0, taper, float(i) / (n - 1))
		var ring: Array = []
		for k in seg:
			var a := TAU * k / seg
			var nrm := (bx * cos(a) + by * sin(a))
			ring.append([pts[i] + nrm * r, nrm])
		rings.append(ring)
	for i in n - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			var a0 = rings[i][k]
			var a1 = rings[i][k2]
			var b0 = rings[i + 1][k]
			var b1 = rings[i + 1][k2]
			for v in [a0, b0, a1, a1, b0, b1]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat(c)
	root.add_child(mi)
	root.add_child(sphere(radius, c, pts[0]))
	root.add_child(sphere(radius * taper, c, pts[n - 1]))
	return root


## 星形柱體（面向 +Z）
static func star(points: int, r_out: float, r_in: float, depth: float, c) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array = []
	for i in points * 2:
		var a := PI / 2 + TAU * i / (points * 2)
		var r := r_out if i % 2 == 0 else r_in
		ring.append(Vector2(cos(a), sin(a)) * r)
	var h := depth / 2.0
	var m := ring.size()
	for i in m:
		var p0: Vector2 = ring[i]
		var p1: Vector2 = ring[(i + 1) % m]
		# 前面（中心微凸，看起來比較立體）
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(0, 0, h * 1.6))
		st.add_vertex(Vector3(p0.x, p0.y, h))
		st.add_vertex(Vector3(p1.x, p1.y, h))
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(0, 0, -h * 1.6))
		st.add_vertex(Vector3(p1.x, p1.y, -h))
		st.add_vertex(Vector3(p0.x, p0.y, -h))
		var nn := Vector3(p1.y - p0.y, -(p1.x - p0.x), 0).normalized()
		st.set_normal(nn)
		st.add_vertex(Vector3(p0.x, p0.y, h))
		st.add_vertex(Vector3(p0.x, p0.y, -h))
		st.add_vertex(Vector3(p1.x, p1.y, h))
		st.add_vertex(Vector3(p1.x, p1.y, h))
		st.add_vertex(Vector3(p0.x, p0.y, -h))
		st.add_vertex(Vector3(p1.x, p1.y, -h))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat(c)
	return mi


static func heart(size: float, c) -> Node3D:
	var n := Node3D.new()
	n.add_child(sphere(size * 0.36, c, Vector3(-size * 0.25, size * 0.12, 0), Vector3(1, 1, 0.7)))
	n.add_child(sphere(size * 0.36, c, Vector3(size * 0.25, size * 0.12, 0), Vector3(1, 1, 0.7)))
	var b := box(Vector3(size * 0.62, size * 0.62, size * 0.5), c, Vector3(0, -size * 0.14, 0), Vector3(0, 0, PI / 4))
	n.add_child(b)
	return n


static func on_head(x: float, y: float, r := 1.0, lift := 0.02) -> Vector3:
	return Vector3(x, y, sqrt(maxf(0.0, r * r - x * x - y * y)) + lift)


static func arc(x0: float, x1: float, fy: Callable, r := 1.0, n := 9) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n:
		var x := lerpf(x0, x1, float(i) / (n - 1))
		pts.append(on_head(x, fy.call(x), r))
	return pts


# ================================================================ 表情臉
const EXPRESSIONS := {"happy": "開心", "laugh": "大笑", "sad": "難過", "angry": "生氣", "surprised": "驚訝", "sleepy": "想睡覺", "scared": "害怕"}


static func face(expr: String, tint := SKIN) -> Node3D:
	var root := Node3D.new()
	var head_c := tint
	if expr == "angry":
		head_c = Color("#FF8A65")
	elif expr == "scared":
		head_c = Color("#C5E3F6")
	root.add_child(sphere(1.0, head_c, Vector3.ZERO, Vector3(1, 0.95, 0.9)))
	var lw := 0.07
	# 眼睛
	match expr:
		"laugh":
			for sx in [-1, 1]:
				root.add_child(tube(arc(sx * 0.42, sx * 0.16, func(x): return 0.18 + 0.1 * (1.0 - pow((x - sx * 0.29) / 0.13, 2))), lw, DARK))
		"sleepy":
			for sx in [-1, 1]:
				root.add_child(tube(arc(sx * 0.42, sx * 0.16, func(x): return 0.15 - 0.05 * (1.0 - pow((x - sx * 0.29) / 0.13, 2))), lw, DARK))
		"surprised", "scared":
			for sx in [-1, 1]:
				root.add_child(sphere(0.19, "white", on_head(sx * 0.3, 0.16, 0.9), Vector3(1, 1.15, 0.5)))
				root.add_child(sphere(0.09, DARK, on_head(sx * 0.3, 0.16 if expr == "surprised" else 0.12, 0.9) + Vector3(0, 0, 0.08), Vector3(1, 1, 0.5)))
		_:
			for sx in [-1, 1]:
				root.add_child(sphere(0.12, DARK, on_head(sx * 0.3, 0.14, 0.9), Vector3(1, 1.4, 0.5)))
				root.add_child(sphere(0.04, "white", on_head(sx * 0.3 + 0.04, 0.22, 0.9) + Vector3(0, 0, 0.06)))
	# 眉毛
	match expr:
		"angry":
			for sx in [-1, 1]:
				root.add_child(tube(PackedVector3Array([on_head(sx * 0.5, 0.48), on_head(sx * 0.14, 0.33)]), lw, DARK))
		"sad", "scared":
			for sx in [-1, 1]:
				root.add_child(tube(PackedVector3Array([on_head(sx * 0.48, 0.38), on_head(sx * 0.16, 0.5)]), lw * 0.85, DARK))
		"surprised":
			for sx in [-1, 1]:
				root.add_child(tube(arc(sx * 0.48, sx * 0.14, func(x): return 0.48 + 0.06 * (1.0 - pow((x - sx * 0.31) / 0.17, 2))), lw * 0.8, DARK))
	# 嘴巴
	match expr:
		"happy":
			root.add_child(tube(arc(-0.38, 0.38, func(x): return -0.3 - 0.18 * (1.0 - pow(x / 0.38, 2))), lw * 1.1, DARK))
		"laugh":
			root.add_child(sphere(0.34, Color("#8E2B3A"), on_head(0, -0.38, 0.86), Vector3(1.1, 0.62, 0.4)))
			root.add_child(sphere(0.14, Color("#FF8FA3"), on_head(0, -0.5, 0.88), Vector3(1.4, 0.6, 0.4)))
			root.add_child(tube(PackedVector3Array([on_head(-0.36, -0.26), on_head(0, -0.24), on_head(0.36, -0.26)]), lw * 0.9, DARK))
		"sad":
			root.add_child(tube(arc(-0.32, 0.32, func(x): return -0.52 + 0.14 * (1.0 - pow(x / 0.32, 2))), lw * 1.1, DARK))
			root.add_child(sphere(0.07, Color("#74C0FC"), on_head(-0.33, -0.05, 0.95), Vector3(0.8, 1.4, 0.6)))
		"angry":
			root.add_child(tube(arc(-0.3, 0.3, func(x): return -0.5 + 0.08 * (1.0 - pow(x / 0.3, 2))), lw * 1.2, DARK))
		"surprised":
			root.add_child(torus(0.08, 0.17, DARK, on_head(0, -0.45, 0.93), Vector3(PI / 2, 0, 0)))
		"sleepy":
			root.add_child(sphere(0.08, DARK, on_head(0.05, -0.45, 0.93), Vector3(1, 1, 0.5)))
		"scared":
			var pts := PackedVector3Array()
			for i in 9:
				var x := lerpf(-0.34, 0.34, i / 8.0)
				pts.append(on_head(x, -0.46 + (0.05 if i % 2 == 0 else -0.05)))
			root.add_child(tube(pts, lw * 0.8, DARK))
	# 臉頰
	if expr in ["happy", "laugh", "sleepy"]:
		for sx in [-1, 1]:
			root.add_child(sphere(0.13, Color("#FF9AA2"), on_head(sx * 0.58, -0.12, 0.9), Vector3(1.2, 0.7, 0.4)))
	return root


# ================================================================ 水果
const FRUITS := {"apple": "蘋果", "banana": "香蕉", "orange": "橘子", "grape": "葡萄", "strawberry": "草莓", "pear": "西洋梨",
	"cherry": "櫻桃", "lemon": "檸檬", "watermelon": "西瓜", "kiwi": "奇異果", "carrot": "紅蘿蔔", "peach": "水蜜桃"}
const FRUIT_JUICE := {"apple": "#F2545B", "banana": "#FFE066", "orange": "#FF9F43", "grape": "#9C36B5", "strawberry": "#FF6B81",
	"pear": "#C0EB75", "cherry": "#C2255C", "lemon": "#FFF3A3", "watermelon": "#FF8787", "kiwi": "#94D82D", "carrot": "#FD7E14", "peach": "#FFB4A2"}


static func _leaf(pos: Vector3, rot_z: float, size := 0.35, c := Color("#40C057")) -> MeshInstance3D:
	var l := sphere(size, c, pos, Vector3(1.0, 0.45, 0.18))
	l.rotation.z = rot_z
	return l


static func fruit(kind: String) -> Node3D:
	var n := Node3D.new()
	var brown := Color("#7A4E2D")
	match kind:
		"apple":
			n.add_child(sphere(0.8, "red", Vector3(0, -0.05, 0), Vector3(1.05, 0.95, 1.0)))
			n.add_child(cyl(0.04, 0.05, 0.4, brown, Vector3(0, 0.85, 0)))
			n.add_child(_leaf(Vector3(0.22, 0.9, 0), 0.5))
		"banana":
			var pts := PackedVector3Array()
			for i in 12:
				var a := lerpf(-1.0, 1.0, i / 11.0)
				pts.append(Vector3(a * 0.85, -0.35 * (1 - a * a) + 0.15, 0))
			n.add_child(tube(pts, 0.27, "yellow", 0.45))
			n.add_child(cyl(0.05, 0.07, 0.2, brown, Vector3(0.9, 0.22, 0), Vector3(0, 0, -0.6)))
		"orange":
			n.add_child(sphere(0.8, "orange"))
			n.add_child(_leaf(Vector3(0.15, 0.82, 0), 0.4))
			n.add_child(sphere(0.06, Color("#5C940D"), Vector3(0, 0.79, 0)))
		"grape":
			var g := Color("#9C36B5")
			var k := 0
			for row in 4:
				for i in 4 - row:
					var x := (i - (3 - row) / 2.0) * 0.36
					n.add_child(sphere(0.21, g if k % 3 else Color("#AE3EC9"), Vector3(x, 0.45 - row * 0.32, 0.05 * (i % 2))))
					k += 1
			n.add_child(cyl(0.04, 0.05, 0.35, brown, Vector3(0, 0.78, 0)))
			n.add_child(_leaf(Vector3(0.25, 0.75, 0), 0.3, 0.3))
		"strawberry":
			var s := sphere(0.7, Color("#FA5252"), Vector3(0, 0, 0), Vector3(1.0, 1.05, 0.9))
			n.add_child(s)
			n.add_child(cyl(0.02, 0.55, 0.6, Color("#FA5252"), Vector3(0, -0.55, 0), Vector3(PI, 0, 0)))
			for i in 10:
				var a := i * 2.4
				n.add_child(sphere(0.05, Color("#FFF3BF"), Vector3(cos(a) * 0.35 * (0.5 + 0.5 * (i % 3) / 2.0), -0.25 + (i % 4) * 0.18, 0.62)))
			for i in 5:
				n.add_child(_leaf(Vector3(cos(i * TAU / 5) * 0.25, 0.68, sin(i * TAU / 5) * 0.2), i * TAU / 5, 0.25))
		"pear":
			n.add_child(sphere(0.7, Color("#A9E34B"), Vector3(0, -0.3, 0)))
			n.add_child(sphere(0.45, Color("#A9E34B"), Vector3(0, 0.35, 0)))
			n.add_child(cyl(0.04, 0.05, 0.35, brown, Vector3(0, 0.88, 0)))
			n.add_child(_leaf(Vector3(0.2, 0.85, 0), 0.5, 0.28))
		"cherry":
			n.add_child(sphere(0.4, Color("#C2255C"), Vector3(-0.38, -0.45, 0)))
			n.add_child(sphere(0.4, Color("#C2255C"), Vector3(0.38, -0.4, 0)))
			n.add_child(tube(PackedVector3Array([Vector3(-0.38, -0.1, 0), Vector3(-0.15, 0.4, 0), Vector3(0.05, 0.8, 0)]), 0.04, Color("#5C940D")))
			n.add_child(tube(PackedVector3Array([Vector3(0.38, -0.05, 0), Vector3(0.2, 0.45, 0), Vector3(0.05, 0.8, 0)]), 0.04, Color("#5C940D")))
			n.add_child(_leaf(Vector3(0.3, 0.82, 0), 0.3, 0.3))
		"lemon":
			n.add_child(sphere(0.75, Color("#FFE066"), Vector3.ZERO, Vector3(1.25, 0.85, 0.85)))
			n.add_child(sphere(0.15, Color("#FFE066"), Vector3(0.95, 0, 0)))
			n.add_child(sphere(0.15, Color("#FFE066"), Vector3(-0.95, 0, 0)))
		"watermelon":
			n.add_child(sphere(0.85, Color("#2F9E44"), Vector3.ZERO, Vector3(1.15, 0.95, 0.95)))
			for k in 5:
				var x := (k - 2) * 0.36
				n.add_child(sphere(0.85, Color("#1B5E20"), Vector3(x, 0, 0), Vector3(0.07, 0.93 * sqrt(maxf(0.1, 1.0 - pow(x / 1.0, 2))), 0.97)))
			n.add_child(cyl(0.04, 0.05, 0.25, brown, Vector3(0, 0.88, 0)))
		"kiwi":
			n.add_child(sphere(0.75, Color("#8D6E63"), Vector3.ZERO, Vector3(1.1, 0.9, 0.7)))
			n.add_child(sphere(0.62, Color("#94D82D"), Vector3(0, 0, 0.3), Vector3(1.1, 0.9, 0.5)))
			n.add_child(sphere(0.18, Color("#FFF9DB"), Vector3(0, 0, 0.56), Vector3(1.2, 0.9, 0.3)))
			for i in 10:
				var a := TAU * i / 10
				n.add_child(sphere(0.04, DARK, Vector3(cos(a) * 0.32, sin(a) * 0.26, 0.58)))
		"carrot":
			n.add_child(cyl(0.38, 0.06, 1.5, Color("#FD7E14"), Vector3(0, -0.2, 0)))
			for i in 3:
				n.add_child(_leaf(Vector3((i - 1) * 0.15, 0.75, 0), PI / 2 + (i - 1) * 0.4, 0.3))
		"peach":
			n.add_child(sphere(0.78, Color("#FFB4A2"), Vector3(0, -0.05, 0)))
			n.add_child(sphere(0.45, Color("#FF8787"), Vector3(0.25, -0.1, 0.5), Vector3(1, 1.2, 0.4)))
			n.add_child(_leaf(Vector3(0.2, 0.78, 0), 0.6, 0.32))
	return n


# ================================================================ 魚
const PATTERNS := {"plain": "沒有花紋", "stripes": "條紋", "dots": "點點"}


static func fish(body_c, pattern := "plain", fin_c = null, size := 1.0) -> Node3D:
	var n := Node3D.new()
	var bc := col(body_c)
	var fc := col(fin_c) if fin_c != null else bc.darkened(0.25)
	n.add_child(sphere(0.62, bc, Vector3.ZERO, Vector3(1.6, 1.0, 0.55)))
	# 尾巴（壓扁的三角錐）
	var tail := cyl(0.0, 0.55, 0.7, fc, Vector3(-1.15, 0, 0), Vector3(0, 0, PI / 2), 3)
	tail.scale = Vector3(1, 1, 0.35)
	n.add_child(tail)
	var fin := cyl(0.0, 0.35, 0.45, fc, Vector3(-0.1, 0.62, 0), Vector3(0, 0, 0.5), 3)
	fin.scale = Vector3(1, 1, 0.3)
	n.add_child(fin)
	n.add_child(sphere(0.16, "white", Vector3(0.6, 0.15, 0.25), Vector3(1, 1, 0.6)))
	n.add_child(sphere(0.08, DARK, Vector3(0.65, 0.15, 0.33)))
	n.add_child(sphere(0.07, bc.darkened(0.35), Vector3(0.95, -0.1, 0.12)))
	var pc := Color.WHITE if bc.get_luminance() < 0.7 else Color("#343A40")
	if pattern == "stripes":
		for x in [-0.45, 0.0, 0.42]:
			n.add_child(sphere(0.62, pc, Vector3(x, 0, 0), Vector3(0.12, 0.95 - absf(x) * 0.6, 0.57)))
	elif pattern == "dots":
		for p in [Vector2(-0.5, 0.15), Vector2(-0.15, -0.2), Vector2(0.15, 0.25), Vector2(-0.2, 0.32), Vector2(0.3, -0.15), Vector2(-0.6, -0.15)]:
			n.add_child(sphere(0.09, pc, Vector3(p.x, p.y, 0.32 * sqrt(maxf(0.05, 1.0 - pow(p.x / 1.0, 2) - pow(p.y / 0.62, 2)))), Vector3(1, 1, 0.5)))
	n.scale = Vector3.ONE * size
	return n


# ================================================================ 章魚（帽子＋拿東西）
const ITEMS := {"star": "星星", "fishy": "小魚", "flower": "花", "balloon": "氣球", "shell": "貝殼"}


static func item(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"star":
			var s := star(5, 0.4, 0.18, 0.15, "yellow")
			n.add_child(s)
		"fishy":
			n.add_child(fish("orange", "plain", null, 0.38))
		"flower":
			for i in 5:
				var a := TAU * i / 5
				n.add_child(sphere(0.15, "pink", Vector3(cos(a) * 0.17, sin(a) * 0.17, 0), Vector3(1, 1, 0.4)))
			n.add_child(sphere(0.1, "yellow", Vector3(0, 0, 0.05)))
		"balloon":
			n.add_child(sphere(0.32, "red", Vector3(0, 0.75, 0), Vector3(0.9, 1.05, 0.9)))
			n.add_child(tube(PackedVector3Array([Vector3(0, 0.42, 0), Vector3(0.05, 0.2, 0), Vector3(0, 0, 0)]), 0.015, DARK))
		"shell":
			var c := Color("#FFC9C9")
			for i in 5:
				var a := PI * (0.1 + 0.2 * i)
				n.add_child(sphere(0.1, c.darkened(0.08 * (i % 2)), Vector3(cos(a) * 0.17, sin(a) * 0.17 - 0.05, 0), Vector3(0.8, 2.2, 0.4)))
				n.get_child(-1).rotation.z = a - PI / 2
			n.add_child(sphere(0.12, c, Vector3(0, -0.08, 0.02), Vector3(1.4, 0.7, 0.4)))
	return n


static func hat(c, style := "top") -> Node3D:
	var n := Node3D.new()
	if style == "top":
		n.add_child(cyl(0.5, 0.5, 0.06, c, Vector3(0, 0, 0)))
		n.add_child(cyl(0.3, 0.32, 0.5, c, Vector3(0, 0.27, 0)))
		n.add_child(cyl(0.325, 0.325, 0.1, col(c).darkened(0.35), Vector3(0, 0.08, 0)))
	else:  # 毛線帽
		n.add_child(sphere(0.42, c, Vector3(0, 0.05, 0), Vector3(1, 0.7, 1)))
		n.add_child(sphere(0.13, "white", Vector3(0, 0.38, 0)))
	return n


static func octopus(hat_c, held: String, body_c := Color("#E599F7")) -> Node3D:
	var n := Node3D.new()
	n.add_child(sphere(0.75, body_c, Vector3(0, 0.35, 0), Vector3(1, 1.05, 0.95)))
	for sx in [-1, 1]:
		n.add_child(sphere(0.15, "white", Vector3(sx * 0.27, 0.35, 0.62), Vector3(1, 1.15, 0.5)))
		n.add_child(sphere(0.075, DARK, Vector3(sx * 0.27, 0.33, 0.7)))
	n.add_child(tube(PackedVector3Array([Vector3(-0.15, 0.08, 0.7), Vector3(0, 0.02, 0.73), Vector3(0.15, 0.08, 0.7)]), 0.03, DARK))
	for i in 6:
		var a := lerpf(-2.3, 2.3, i / 5.0)
		var dx := sin(a)
		var pts := PackedVector3Array()
		for k in 6:
			var t := k / 5.0
			pts.append(Vector3(dx * (0.3 + t * 0.55), -0.1 - t * 0.75 + t * t * 0.3, cos(a) * 0.25 + 0.1))
		n.add_child(tube(pts, 0.13, body_c.darkened(0.05), 0.4))
	var h := hat(hat_c)
	h.position = Vector3(0, 1.02, 0)
	h.rotation.z = -0.12
	n.add_child(h)
	if held != "":
		var it := item(held)
		it.position = Vector3(0.98, -0.25, 0.35)
		it.scale = Vector3.ONE * 1.25
		n.add_child(it)
	return n


# ================================================================ 動物（正面半身）
const ANIMALS := {"cat": "貓咪", "rabbit": "兔子", "bear": "小熊", "pig": "小豬", "frog": "青蛙", "elephant": "大象",
	"panda": "熊貓", "duck": "鴨子", "lion": "獅子", "mouse": "老鼠"}


static func animal(kind: String) -> Node3D:
	var n := Node3D.new()
	var c := Color("#F4A261")
	var head_y := 0.35
	match kind:
		"cat": c = Color("#FFA94D")
		"rabbit": c = Color("#F1F3F5")
		"bear": c = Color("#A9714B")
		"pig": c = Color("#FFB3C6")
		"frog": c = Color("#69DB7C")
		"elephant": c = Color("#A5B4C8")
		"panda": c = Color("#FAFAFA")
		"duck": c = Color("#FFE066")
		"lion": c = Color("#F6C350")
		"mouse": c = Color("#BAC1CC")
	# 身體
	n.add_child(sphere(0.62, c, Vector3(0, -0.75, -0.1), Vector3(1.05, 0.9, 0.85)))
	if kind == "panda":
		n.add_child(sphere(0.62, DARK, Vector3(0, -0.92, -0.12), Vector3(1.08, 0.55, 0.88)))
	# 鬃毛（獅子）
	if kind == "lion":
		for i in 14:
			var a := TAU * i / 14
			n.add_child(sphere(0.3, Color("#D9480F"), Vector3(cos(a) * 0.78, head_y + sin(a) * 0.74, -0.15)))
	# 耳朵
	match kind:
		"cat":
			for sx in [-1, 1]:
				var e := cyl(0.0, 0.25, 0.45, c, Vector3(sx * 0.45, head_y + 0.62, 0), Vector3(0, 0, -sx * 0.35), 4)
				n.add_child(e)
		"rabbit":
			for sx in [-1, 1]:
				n.add_child(sphere(0.18, c, Vector3(sx * 0.25, head_y + 1.05, 0), Vector3(0.9, 3.0, 0.6)))
				n.add_child(sphere(0.1, Color("#FFC9D6"), Vector3(sx * 0.25, head_y + 1.05, 0.08), Vector3(0.9, 3.4, 0.5)))
		"bear", "panda":
			for sx in [-1, 1]:
				n.add_child(sphere(0.24, DARK if kind == "panda" else c.darkened(0.1), Vector3(sx * 0.55, head_y + 0.55, -0.05)))
		"pig":
			for sx in [-1, 1]:
				n.add_child(cyl(0.0, 0.2, 0.3, c.darkened(0.08), Vector3(sx * 0.45, head_y + 0.6, 0.05), Vector3(0.6, 0, -sx * 0.4), 3))
		"elephant":
			for sx in [-1, 1]:
				n.add_child(sphere(0.55, c.darkened(0.05), Vector3(sx * 0.85, head_y + 0.05, -0.2), Vector3(0.7, 1.05, 0.25)))
		"mouse":
			for sx in [-1, 1]:
				n.add_child(sphere(0.38, c, Vector3(sx * 0.6, head_y + 0.55, -0.1), Vector3(1, 1, 0.3)))
				n.add_child(sphere(0.25, Color("#FFC9D6"), Vector3(sx * 0.6, head_y + 0.55, -0.02), Vector3(1, 1, 0.25)))
		"lion":
			for sx in [-1, 1]:
				n.add_child(sphere(0.16, c, Vector3(sx * 0.5, head_y + 0.55, 0)))
	# 頭
	var hs := Vector3(1.05, 0.95, 0.9)
	if kind == "frog":
		hs = Vector3(1.2, 0.8, 0.85)
	n.add_child(sphere(0.66, c, Vector3(0, head_y, 0), hs))
	# 眼睛
	if kind == "frog":
		for sx in [-1, 1]:
			n.add_child(sphere(0.24, c, Vector3(sx * 0.4, head_y + 0.5, 0.1)))
			n.add_child(sphere(0.16, "white", Vector3(sx * 0.4, head_y + 0.52, 0.25)))
			n.add_child(sphere(0.08, DARK, Vector3(sx * 0.4, head_y + 0.52, 0.38)))
		n.add_child(tube(PackedVector3Array([Vector3(-0.4, head_y - 0.1, 0.48), Vector3(0, head_y - 0.25, 0.55), Vector3(0.4, head_y - 0.1, 0.48)]), 0.04, DARK))
	else:
		for sx in [-1, 1]:
			if kind == "panda":
				n.add_child(sphere(0.17, DARK, Vector3(sx * 0.25, head_y + 0.08, 0.5), Vector3(1, 1.3, 0.5)))
				n.add_child(sphere(0.06, "white", Vector3(sx * 0.25, head_y + 0.1, 0.58)))
			else:
				n.add_child(sphere(0.09, DARK, Vector3(sx * 0.24, head_y + 0.1, 0.55), Vector3(1, 1.25, 0.6)))
				n.add_child(sphere(0.03, "white", Vector3(sx * 0.24 + 0.03, head_y + 0.15, 0.62)))
	# 口鼻
	match kind:
		"cat", "lion", "mouse":
			n.add_child(sphere(0.07, Color("#FF6B81") if kind != "lion" else DARK, Vector3(0, head_y - 0.08, 0.6)))
			for sx in [-1, 1]:
				for k in 2:
					n.add_child(tube(PackedVector3Array([Vector3(sx * 0.15, head_y - 0.1 - k * 0.07, 0.57), Vector3(sx * 0.5, head_y - 0.05 - k * 0.12, 0.45)]), 0.012, DARK))
		"rabbit":
			n.add_child(sphere(0.06, Color("#FF6B81"), Vector3(0, head_y - 0.08, 0.6)))
			for sx in [-1, 1]:
				n.add_child(box(Vector3(0.09, 0.12, 0.03), "white", Vector3(sx * 0.05, head_y - 0.25, 0.58)))
		"bear", "panda":
			n.add_child(sphere(0.22, Color("#F8E1C8") if kind == "bear" else Color("#FFFFFF"), Vector3(0, head_y - 0.15, 0.5), Vector3(1.2, 0.85, 0.6)))
			n.add_child(sphere(0.08, DARK, Vector3(0, head_y - 0.08, 0.63), Vector3(1.3, 0.9, 0.6)))
		"pig":
			n.add_child(sphere(0.2, Color("#FF8FAB"), Vector3(0, head_y - 0.12, 0.58), Vector3(1.25, 0.9, 0.5)))
			for sx in [-1, 1]:
				n.add_child(sphere(0.045, Color("#C2255C"), Vector3(sx * 0.08, head_y - 0.12, 0.68)))
		"elephant":
			var pts := PackedVector3Array()
			for k in 8:
				var t := k / 7.0
				pts.append(Vector3(sin(t * 2.2) * 0.25, head_y - 0.05 - t * 0.85, 0.55 + t * 0.15))
			n.add_child(tube(pts, 0.13, c, 0.7))
		"duck":
			n.add_child(sphere(0.25, "orange", Vector3(0, head_y - 0.15, 0.6), Vector3(1.3, 0.45, 0.8)))
	return n


# ================================================================ 小柯機器人（大頭盔）
static func robot() -> Node3D:
	var n := Node3D.new()
	n.name = "Robot"
	var white := Color("#F8F9FA")
	var blue := Color("#4C9AFF")
	n.add_child(sphere(0.55, white, Vector3(0, -0.85, 0), Vector3(1, 0.9, 0.85)))
	n.add_child(sphere(0.22, blue, Vector3(0, -0.8, 0.45), Vector3(1, 1, 0.4)))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.3, 0)
	n.add_child(head)
	head.add_child(sphere(0.85, white, Vector3.ZERO, Vector3(1.1, 1.0, 1.0)))
	head.add_child(sphere(0.66, Color("#1E2A3A"), Vector3(0, -0.02, 0.45), Vector3(1.15, 0.82, 0.72)))
	for sx in [-1, 1]:
		head.add_child(sphere(0.13, Color("#5CF2FF"), Vector3(sx * 0.27, 0.05, 0.93), Vector3(1, 1.25, 0.4)))
		head.get_child(-1).material_override = mat(Color("#5CF2FF"), 0.3, 2.2)
		head.add_child(sphere(0.12, blue, Vector3(sx * 0.95, 0, 0), Vector3(0.6, 1, 1)))
	head.add_child(tube(PackedVector3Array([Vector3(-0.18, -0.2, 0.9), Vector3(0, -0.26, 0.93), Vector3(0.18, -0.2, 0.9)]), 0.03, Color("#5CF2FF")))
	head.get_child(-1).get_child(0).material_override = mat(Color("#5CF2FF"), 0.3, 2.0)
	head.add_child(cyl(0.03, 0.03, 0.4, Color("#868E96"), Vector3(0, 1.0, 0)))
	var ball := sphere(0.1, "orange", Vector3(0, 1.22, 0))
	ball.material_override = mat("orange", 0.3, 1.2)
	head.add_child(ball)
	for sx in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmL" if sx < 0 else "ArmR"
		arm.position = Vector3(sx * 0.55, -0.65, 0)
		arm.add_child(tube(PackedVector3Array([Vector3.ZERO, Vector3(sx * 0.25, -0.25, 0.05), Vector3(sx * 0.35, -0.5, 0.1)]), 0.09, white))
		arm.add_child(sphere(0.13, blue, Vector3(sx * 0.35, -0.55, 0.1)))
		n.add_child(arm)
	return n


# ================================================================ 其他道具
static func icecream(scoops: Array, cherry := false) -> Node3D:
	var n := Node3D.new()
	n.add_child(cyl(0.45, 0.05, 1.1, Color("#E0A458"), Vector3(0, -0.55, 0)))
	for i in scoops.size():
		n.add_child(sphere(0.45, scoops[i], Vector3(0, 0.1 + i * 0.5, 0)))
	if cherry:
		n.add_child(sphere(0.15, Color("#C2255C"), Vector3(0, 0.1 + scoops.size() * 0.5 - 0.05, 0)))
	return n


static func flower(petals: int, c, center := "yellow") -> Node3D:
	var n := Node3D.new()
	n.add_child(cyl(0.05, 0.05, 1.2, Color("#2F9E44"), Vector3(0, -0.75, -0.05)))
	n.add_child(_leaf(Vector3(0.3, -0.8, 0), 0.4, 0.32))
	for i in petals:
		var a := PI / 2 + TAU * i / petals
		var p := sphere(0.25, c, Vector3(cos(a) * 0.38, sin(a) * 0.38, 0), Vector3(1.0, 0.65, 0.35))
		p.rotation.z = a
		n.add_child(p)
	n.add_child(sphere(0.22, center, Vector3(0, 0, 0.08), Vector3(1, 1, 0.6)))
	return n


static func balloon(c, mark := "") -> Node3D:
	var n := Node3D.new()
	n.add_child(sphere(0.6, c, Vector3(0, 0.25, 0), Vector3(0.9, 1.08, 0.9)))
	n.add_child(cyl(0.0, 0.09, 0.14, c, Vector3(0, -0.45, 0), Vector3(PI, 0, 0)))
	n.add_child(tube(PackedVector3Array([Vector3(0, -0.5, 0), Vector3(0.1, -0.85, 0), Vector3(-0.05, -1.2, 0)]), 0.015, Color("#868E96")))
	if mark == "star":
		var s := star(5, 0.2, 0.09, 0.05, "white")
		s.position = Vector3(0, 0.3, 0.55)
		n.add_child(s)
	elif mark == "heart":
		var h := heart(0.36, "white")
		h.position = Vector3(0, 0.3, 0.52)
		h.scale = Vector3(1, 1, 0.3)
		n.add_child(h)
	elif mark == "dot":
		n.add_child(sphere(0.14, "white", Vector3(0, 0.3, 0.52), Vector3(1, 1, 0.3)))
	return n


## 形狀積木：cube / ball / cylinder / cone / star / heart
const SHAPES := {"cube": "正方體", "ball": "球", "cylinder": "圓柱", "cone": "三角錐", "star": "星星", "heart": "愛心"}


static func shape(kind: String, c, size := 1.0) -> Node3D:
	var n := Node3D.new()
	match kind:
		"cube":
			var b := box(Vector3.ONE * 1.1, c)
			b.rotation = Vector3(0.35, 0.6, 0)
			n.add_child(b)
		"ball":
			n.add_child(sphere(0.65, c))
		"cylinder":
			var cy := cyl(0.5, 0.5, 1.1, c)
			cy.rotation.x = 0.35
			n.add_child(cy)
		"cone":
			var co := cyl(0.0, 0.65, 1.2, c, Vector3.ZERO, Vector3(0.2, 0, 0), 4)
			n.add_child(co)
		"star":
			n.add_child(star(5, 0.75, 0.33, 0.35, c))
		"heart":
			n.add_child(heart(1.2, c))
	n.scale = Vector3.ONE * size
	return n


## 由格子組成的積木（方向／鏡像題）；cells 是 Vector2i 陣列
static func blocks(cells: Array, c, unit := 0.5) -> Node3D:
	var n := Node3D.new()
	var center := Vector2.ZERO
	for p in cells:
		center += Vector2(p)
	center /= cells.size()
	for p in cells:
		var b := box(Vector3.ONE * unit * 0.94, c, Vector3((p.x - center.x) * unit, (p.y - center.y) * unit, 0))
		n.add_child(b)
	# 第一格加一個圓點，讓方向更容易看出
	var p0: Vector2i = cells[0]
	n.add_child(sphere(unit * 0.2, "white", Vector3((p0.x - center.x) * unit, (p0.y - center.y) * unit, unit * 0.47), Vector3(1, 1, 0.4)))
	return n


## 小汽車（側面，車頭朝 +X）
static func car(c) -> Node3D:
	var n := Node3D.new()
	n.add_child(box(Vector3(1.8, 0.5, 0.8), c, Vector3(0, -0.1, 0)))
	n.add_child(box(Vector3(0.95, 0.45, 0.75), c, Vector3(-0.15, 0.35, 0)))
	n.add_child(box(Vector3(0.4, 0.32, 0.02), Color("#A5D8FF"), Vector3(0.12, 0.37, 0.39)))
	n.add_child(box(Vector3(0.35, 0.32, 0.02), Color("#A5D8FF"), Vector3(-0.38, 0.37, 0.39)))
	n.add_child(sphere(0.1, "yellow", Vector3(0.9, 0.0, 0.25)))
	n.get_child(-1).material_override = mat("yellow", 0.3, 1.0)
	for x in [-0.55, 0.55]:
		n.add_child(cyl(0.27, 0.27, 0.2, DARK, Vector3(x, -0.38, 0.38), Vector3(PI / 2, 0, 0)))
		n.add_child(cyl(0.12, 0.12, 0.22, Color("#DEE2E6"), Vector3(x, -0.38, 0.39), Vector3(PI / 2, 0, 0)))
	return n


## 分類盒（開口朝上、正面貼圖案）
static func bin(c, sign_node: Node3D) -> Node3D:
	var n := Node3D.new()
	var cc := col(c)
	n.add_child(box(Vector3(2.0, 0.1, 1.2), cc.darkened(0.2), Vector3(0, -0.6, 0)))
	n.add_child(box(Vector3(2.0, 1.2, 0.1), cc, Vector3(0, 0, 0.55)))
	n.add_child(box(Vector3(2.0, 1.2, 0.1), cc.darkened(0.1), Vector3(0, 0, -0.55)))
	n.add_child(box(Vector3(0.1, 1.2, 1.2), cc.darkened(0.05), Vector3(-0.95, 0, 0)))
	n.add_child(box(Vector3(0.1, 1.2, 1.2), cc.darkened(0.05), Vector3(0.95, 0, 0)))
	n.add_child(box(Vector3(1.1, 0.9, 0.04), "white", Vector3(0, 0, 0.62)))
	if sign_node:
		sign_node.position = Vector3(0, 0, 0.75)
		sign_node.scale *= 0.55
		n.add_child(sign_node)
	return n


## 倒蓋的杯子
static func cup(c := Color("#FF8787")) -> Node3D:
	var n := Node3D.new()
	n.add_child(cyl(0.45, 0.72, 1.3, c))
	n.add_child(cyl(0.74, 0.74, 0.1, col(c).darkened(0.2), Vector3(0, -0.62, 0)))
	n.add_child(torus(0.05, 0.12, col(c).lightened(0.3), Vector3(0, 0.7, 0)))
	for i in 3:
		n.add_child(torus(0.02, 0.05, "white", Vector3(-0.3 + i * 0.3, 0.0, 0.58), Vector3(PI / 2, 0, 0)))
	return n


## 一團樹葉（躲貓貓）
static func leaf_cluster(r: float, shade := 0) -> Node3D:
	var n := Node3D.new()
	var greens := [Color("#2F9E44"), Color("#37B24D"), Color("#40C057"), Color("#51CF66"), Color("#2B8A3E")]
	for i in 7:
		var a := TAU * i / 7.0 + shade
		var d := r * (0.35 if i > 0 else 0.0)
		var l := sphere(r * 0.6, greens[(i + shade) % greens.size()], Vector3(cos(a) * d, sin(a) * d, 0.05 * i), Vector3(1.0, 0.8, 0.35))
		l.rotation.z = a
		n.add_child(l)
	return n


static func tree(h := 3.0, c := Color("#40C057")) -> Node3D:
	var n := Node3D.new()
	n.add_child(cyl(0.18, 0.28, h * 0.5, Color("#8D6E63"), Vector3(0, h * 0.25, 0)))
	n.add_child(sphere(h * 0.3, c, Vector3(0, h * 0.62, 0)))
	n.add_child(sphere(h * 0.22, c.lightened(0.1), Vector3(h * 0.15, h * 0.78, 0.1)))
	n.add_child(sphere(h * 0.2, c.darkened(0.1), Vector3(-h * 0.17, h * 0.72, 0.05)))
	return n


static func seaweed(h := 2.0, c := Color("#2B8A3E")) -> Node3D:
	var pts := PackedVector3Array()
	for k in 8:
		var t := k / 7.0
		pts.append(Vector3(sin(t * 5.0) * 0.18, t * h, 0))
	return tube(pts, 0.1, c, 0.4)


static func coral(c := Color("#FF8787")) -> Node3D:
	var n := Node3D.new()
	for i in 4:
		var a := lerpf(-0.8, 0.8, i / 3.0)
		n.add_child(tube(PackedVector3Array([Vector3.ZERO, Vector3(sin(a) * 0.3, 0.5, 0), Vector3(sin(a) * 0.6, 0.9 + 0.2 * (i % 2), 0)]), 0.09, c, 0.6))
	return n


static func cloud(w := 2.0) -> Node3D:
	var n := Node3D.new()
	for i in 4:
		n.add_child(sphere(w * (0.25 + 0.08 * (i % 2)), "white", Vector3((i - 1.5) * w * 0.25, (i % 2) * w * 0.1, 0)))
	return n
