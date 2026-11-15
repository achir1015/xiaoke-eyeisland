class_name HelpArt
extends Control
## 遊戲說明的小動畫（每頁一種）。

var page := 0
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _star(c: Vector2, s: float, col := Color("#FFD43B")) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.45))
	draw_colored_polygon(pts, col)


func _round_rect(r: Rect2, c: Color, rad := 18) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(rad)
	draw_style_box(sb, r)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var font := get_theme_default_font()
	_round_rect(Rect2(Vector2.ZERO, size), Pal.menu().bar, 28)
	match page:
		0:
			draw_circle(Vector2(w / 2, h * 0.62), w * 0.38, Color("#8CE99A"))
			var cols := ["rainbow", "blocks", "juice", "ocean", "forest"].map(func(k): return Pal.park_color(k))
			for i in 5:
				var a := -PI / 2 + TAU * i / 5 + t * 0.3
				var c := Vector2(w / 2, h * 0.6) + Vector2(cos(a), sin(a) * 0.5) * w * 0.27
				draw_circle(c, 26 + sin(t * 3 + i) * 3, cols[i])
			_star(Vector2(w / 2, h * 0.3 + sin(t * 2) * 8), 30)
		1:
			var br := Rect2(w * 0.35, h * 0.35, w * 0.45, h * 0.3)
			var ph := fmod(t, 4.0)
			var p := clampf((ph - 1.2) / 1.6, 0, 1)
			_round_rect(br, Color("#40C057") if ph < 2.8 or ph > 3.3 else Color("#8CE99A"))
			if p > 0:
				_round_rect(Rect2(br.position, Vector2(br.size.x * p, br.size.y)), Color(1, 1, 1, 0.35))
			draw_string(font, br.position + Vector2(br.size.x / 2 - 30, br.size.y / 2 + 12), "開始", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
			var start := Vector2(w * 0.15, h * 0.85)
			var goal := br.get_center()
			var cpos := start.lerp(goal, clampf(ph / 1.0, 0, 1))
			_star(cpos, 22)
			draw_arc(cpos, 32, -PI / 2, -PI / 2 + TAU * p, 32, Color("#FF6B6B"), 6, true)
		2:
			draw_circle(Vector2(w * 0.2, h * 0.5), 46, Color.WHITE)
			draw_circle(Vector2(w * 0.2 + sin(t * 2) * 12, h * 0.5), 20, Color("#1C7ED6"))
			draw_circle(Vector2(w * 0.2 + sin(t * 2) * 12, h * 0.5), 8, Color.BLACK)
			draw_string(font, Vector2(w * 0.08, h * 0.82), "眼動鼠", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#343A40"))
			for k in 4:
				var x := w * 0.38 + k * 22 + fmod(t * 60, 22)
				draw_circle(Vector2(x, h * 0.5), 6, Color("#FAB005"))
			_round_rect(Rect2(w * 0.62, h * 0.28, w * 0.32, h * 0.44), Color("#FFDEEB"))
			_star(Vector2(w * 0.78 + sin(t * 2) * 20, h * 0.5), 20)
			draw_string(font, Vector2(w * 0.66, h * 0.82), "遊戲", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#343A40"))
		3:
			var names := ["辨識", "空間", "記憶", "背景", "完形"]
			var cols2 := ["rainbow", "blocks", "juice", "ocean", "forest"].map(func(k): return Pal.park_color(k))
			for i in 5:
				var c := Vector2(w * (0.14 + 0.18 * i), h * 0.5 + sin(t * 2 + i) * 10)
				draw_circle(c, 30, cols2[i])
				draw_string(font, c + Vector2(-26, 62), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#343A40"))
		4:
			var labels := ["簡單", "中等", "困難"]
			var cols3 := [0, 1, 2].map(func(d): return Pal.diff_color(Pal.menu().base, d))
			for i in 3:
				var bh := h * (0.25 + 0.18 * i) * (0.9 + 0.1 * sin(t * 2 + i))
				_round_rect(Rect2(w * (0.12 + 0.28 * i), h * 0.85 - bh, w * 0.2, bh), cols3[i])
				draw_string(font, Vector2(w * (0.13 + 0.28 * i), h * 0.95), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#343A40"))
		5:
			_round_rect(Rect2(w * 0.05, h * 0.05, w * 0.9, h * 0.15), Color.WHITE, 10)
			draw_string(font, Vector2(w * 0.1, h * 0.16), "🔊 找出開心的臉", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#343A40"))
			_round_rect(Rect2(w * 0.05, h * 0.3, w * 0.22, h * 0.4), Color("#FFF3BF"), 10)
			draw_circle(Vector2(w * 0.16, h * 0.5), 26, Color("#FFD66B"))
			for i in 3:
				var c := Vector2(w * (0.45 + 0.17 * i), h * 0.55)
				draw_circle(c, 30, Color("#FFD66B"))
			var ph := fmod(t, 3.0)
			var cc := Vector2(w * 0.45, h * 0.55).lerp(Vector2(w * 0.79, h * 0.55), clampf(ph / 1.2, 0, 1))
			_star(cc + Vector2(0, -50), 16)
			if ph > 1.8:
				_star(Vector2(w * 0.79, h * 0.55), 40 * (ph - 1.8), Color("#FAB005"))
		6:
			var pts := PackedVector2Array()
			for i in 30:
				var u := i / 29.0
				pts.append(Vector2(w * (0.1 + 0.8 * u), h * (0.5 + 0.3 * sin(u * 9.0 + t))))
			draw_polyline(pts, Color("#4C9AFF"), 3, true)
			for i in 5:
				var c: Vector2 = pts[i * 6 + 2]
				draw_circle(c, 16, Color(1, 0.55, 0.1, 0.7))
				draw_string(font, c + Vector2(-6, 7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
			draw_circle(pts[0], 10, Color("#2F9E44"))
			draw_circle(pts[29], 10, Color("#E03131"))
		7:
			_round_rect(Rect2(w * 0.12, h * 0.35, w * 0.25, h * 0.3), Color("#495057"), 12)
			draw_string(font, Vector2(w * 0.17, h * 0.55), "Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
			var c := Vector2(w * 0.7, h * 0.5)
			for i in 8:
				var a := TAU * i / 8 + t
				draw_line(c, c + Vector2(cos(a), sin(a)) * 70, Color("#868E96"), 18)
			draw_circle(c, 52, Color("#868E96"))
			draw_circle(c, 22, Color("#E7F5FF"))
