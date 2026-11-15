class_name GazeButton
extends Button
## 看著按鈕一段時間就會按下（同時也可以用滑鼠點）。按鈕會由左往右填滿，表示快要選到了。

static var modal: Control = null          # 有對話框時，只有對話框裡的按鈕有效
static var last_fire_ms := 0
static var cursor_progress := 0.0          # 給視線游標畫圈圈
static var cursor_frame := 0

@export var dwell_scale := 1.0             # 這顆按鈕要看多久（倍數）
@export var accent := Color("#4C9AFF")
var progress := 0.0
var gazed := false
var _pulse := 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func(): Snd.play("select"))
	if not is_in_group("gaze_btn"):
		add_to_group("gaze_btn")


static func make(text_: String, color := Color("#4C9AFF"), font_size := 30, min_size := Vector2(220, 96)) -> GazeButton:
	var b := GazeButton.new()
	b.text = text_
	b.accent = color
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	style(b, color)
	return b


static func style(b: Button, color: Color, radius := 26) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var c := color
		if st == "hover":
			c = color.lightened(0.12)
		elif st == "pressed":
			c = color.darkened(0.12)
		elif st == "disabled":
			c = Color(0.75, 0.75, 0.78)
		sb.bg_color = c
		sb.set_corner_radius_all(radius)
		sb.border_width_bottom = 7
		sb.border_color = c.darkened(0.28)
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		if st == "focus":
			sb.draw_center = false
			sb.border_width_bottom = 0
			sb.shadow_size = 0
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", color.darkened(0.45))
	b.add_theme_constant_override("outline_size", 6)


func active() -> bool:
	if disabled or not is_visible_in_tree():
		return false
	if modal and is_instance_valid(modal) and modal.is_visible_in_tree() and not modal.is_ancestor_of(self):
		return false
	return true


func _process(delta: float) -> void:
	var was := gazed
	gazed = false
	if active() and Gaze.valid and get_global_rect().has_point(Gaze.point):
		gazed = true
	if gazed and Time.get_ticks_msec() - last_fire_ms > 700:
		progress += delta / maxf(0.2, Game.dwell_s() * dwell_scale)
		cursor_progress = progress
		cursor_frame = Engine.get_process_frames()
		if progress >= 1.0:
			progress = 0.0
			last_fire_ms = Time.get_ticks_msec()
			_pulse = 1.0
			pressed.emit()
	else:
		progress = maxf(0.0, progress - delta * 3.0)
	if gazed != was or progress > 0.0 or _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 3.0)
		queue_redraw()
	pivot_offset = size / 2
	var target := 1.06 if gazed else 1.0
	scale = scale.lerp(Vector2.ONE * (target + _pulse * 0.08), minf(1.0, delta * 12.0))


func _draw() -> void:
	if progress > 0.0:
		var r := Rect2(Vector2.ZERO, Vector2(size.x * progress, size.y))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.32)
		sb.set_corner_radius_all(26)
		draw_style_box(sb, r)
	if gazed:
		var sb2 := StyleBoxFlat.new()
		sb2.draw_center = false
		sb2.set_border_width_all(5)
		sb2.border_color = Pal.hsv(accent.h + 0.5, 0.55, 1.0)   # 互補色外框
		sb2.set_corner_radius_all(28)
		draw_style_box(sb2, Rect2(Vector2(-4, -4), size + Vector2(8, 8)))
