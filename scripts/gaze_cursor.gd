class_name GazeCursor
extends Control
## 視線游標：一顆會眨眼的小星星，停留選取時外圈慢慢畫滿。

static var hidden_for_capture := false
static var level_progress := 0.0
static var level_frame := 0

var _t := 0.0
var _pos := Vector2(-999, -999)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	if Gaze.valid:
		_pos = Gaze.point if _pos.x < -900 else _pos.lerp(Gaze.point, minf(1.0, delta * 25.0))
	queue_redraw()


func _prog() -> float:
	var f := Engine.get_process_frames()
	var p := 0.0
	if f - GazeButton.cursor_frame <= 1:
		p = GazeButton.cursor_progress
	if f - level_frame <= 1:
		p = maxf(p, level_progress)
	return clampf(p, 0.0, 1.0)


func _draw() -> void:
	if hidden_for_capture or not bool(Game.settings.show_cursor) or not Gaze.valid:
		return
	if Gaze.source == "mouse" and Gaze.bot_point == null and not Gaze.linked:
		# 用滑鼠玩時，系統游標就在那裡；只畫進度圈
		var pm := _prog()
		if pm > 0.0:
			draw_arc(_pos, 30, -PI / 2, -PI / 2 + TAU * pm, 40, Color(1, 0.85, 0.2), 8, true)
		return
	var s := float(Game.settings.cursor_size)
	var c := _pos
	draw_circle(c, s * 0.62, Color(1, 1, 1, 0.22))
	# 星星
	var pts := PackedVector2Array()
	var rot := sin(_t * 1.5) * 0.15
	for i in 10:
		var a := -PI / 2 + rot + TAU * i / 10.0
		var r := s * (0.38 if i % 2 == 0 else 0.17)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color("#FFD43B"))
	pts.append(pts[0])
	draw_polyline(pts, Color("#F08C00"), 3.0, true)
	# 眼睛（每 3 秒眨一次）
	var blink := fmod(_t, 3.2) < 0.12
	for sx in [-1, 1]:
		var e := c + Vector2(sx * s * 0.08, -s * 0.02)
		if blink:
			draw_line(e - Vector2(s * 0.035, 0), e + Vector2(s * 0.035, 0), Color("#5C3D00"), 2.5)
		else:
			draw_circle(e, s * 0.04, Color("#5C3D00"))
	var p := _prog()
	draw_arc(c, s * 0.58, 0, TAU, 48, Color(1, 1, 1, 0.5), 4, true)
	if p > 0.0:
		draw_arc(c, s * 0.58, -PI / 2, -PI / 2 + TAU * p, 48, Color("#FF6B6B"), 8, true)
	if Gaze.bot_point != null:
		draw_string(get_theme_default_font(), c + Vector2(-s * 0.5, s * 0.95), "示範", HORIZONTAL_ALIGNMENT_CENTER, s, 22, Color("#E8590C"))
