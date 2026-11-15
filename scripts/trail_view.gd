class_name TrailView
extends Control
## 眼球軌跡圖：一般版（路徑＋起點／終點）與數字版（注視順序編號）。

var tex: Texture2D
var round_data := {}
var mode := "path"          # path / numbered
var aspect := 16.0 / 9.0
var show_aoi := true


func _ready() -> void:
	resized.connect(queue_redraw)


func set_data(t: Texture2D, r: Dictionary, a: float) -> void:
	tex = t
	round_data = r
	aspect = a
	queue_redraw()


func _img_rect() -> Rect2:
	var w := size.x
	var h := w / aspect
	if h > size.y:
		h = size.y
		w = h * aspect
	return Rect2((size - Vector2(w, h)) / 2, Vector2(w, h))


func _draw() -> void:
	var r := _img_rect()
	draw_rect(r, Color("#DEE2E6"))
	if tex:
		draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.72))
	var font := get_theme_default_font()
	if show_aoi:
		for a in round_data.get("aois", []):
			var c := r.position + Vector2(float(a.x), float(a.y)) * r.size
			var rad := float(a.r) * r.size.x
			draw_arc(c, rad, 0, TAU, 40, Color("#2F9E44") if a.target else Color(1, 1, 1, 0.8), 3.0 if a.target else 2.0, true)
	var samples: Array = round_data.get("samples", [])
	if mode == "path":
		var prev = null
		var n := samples.size()
		var first = null
		var last = null
		for i in n:
			var s = samples[i]
			if float(s[1]) < 0.0:
				prev = null
				continue
			var p := r.position + Vector2(float(s[1]), float(s[2])) * r.size
			if prev != null:
				var t := float(i) / maxf(1, n - 1)
				draw_line(prev, p, Color(0.2 + 0.8 * t, 0.45, 1.0 - 0.7 * t, 0.85), 3.0, true)
			if first == null:
				first = p
			last = p
			prev = p
		if first != null:
			draw_circle(first, 13, Color("#2F9E44"))
			draw_string(font, first + Vector2(-9, 7), "起", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		if last != null:
			draw_circle(last, 13, Color("#E03131"))
			draw_string(font, last + Vector2(-9, 7), "終", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	else:
		var fx := Report.fixations(samples, aspect)
		var prevc = null
		for i in fx.size():
			var f: Dictionary = fx[i]
			var c := r.position + Vector2(float(f.x), float(f.y)) * r.size
			if prevc != null:
				draw_line(prevc, c, Color(0.1, 0.3, 0.8, 0.6), 2.5, true)
			prevc = c
		for i in fx.size():
			var f: Dictionary = fx[i]
			var c := r.position + Vector2(float(f.x), float(f.y)) * r.size
			var rad := clampf(8.0 + float(f.dur) * 30.0, 10.0, 34.0)
			draw_circle(c, rad, Color(1.0, 0.55, 0.1, 0.55))
			draw_arc(c, rad, 0, TAU, 32, Color("#D9480F"), 2.0, true)
			var label := str(i + 1)
			var fs := 18
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-tw / 2, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if samples.is_empty():
		draw_string(font, r.get_center() - Vector2(120, 0), "這一回合沒有視線紀錄", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#495057"))
