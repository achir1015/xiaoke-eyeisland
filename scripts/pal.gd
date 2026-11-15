class_name Pal
extends RefCounted
## 相對配色：由一個主色推算整組顏色。
##   同色相、不同明度／彩度 → 背景、面板、按鈕、邊框、文字（彼此一定搭）
##   類似色（色相 ±0.06）→ 點綴
##   互補色（色相 +0.5）→ 強調：目標框、提示鈕、選取圈


static func hsv(h: float, s: float, v: float) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), clampf(s, 0, 1), clampf(v, 0, 1))


## 五座樂園的主色：色相平均分開、彩度明度相同，所以並排時是一組
const PARK_HUES := {"rainbow": 0.98, "blocks": 0.6, "juice": 0.08, "ocean": 0.5, "forest": 0.35}
const MENU_HUE := 0.56


## 主色：彩度固定，明度往下調到感知亮度 ≈ 0.5（白字清楚、五色亮度一致）
static func main_color(h: float, s := 0.62) -> Color:
	var v := 0.95
	var c := hsv(h, s, v)
	while c.get_luminance() > 0.5 and v > 0.5:
		v -= 0.01
		c = hsv(h, s, v)
	return c


static func park_color(park_id: String) -> Color:
	return main_color(PARK_HUES.get(park_id, MENU_HUE))


static func scheme(base: Color) -> Dictionary:
	var h := base.h
	return {
		"base": base,
		"wall2": hsv(h, 0.10, 1.0),        # 背景上方（最淡）
		"wall": hsv(h, 0.30, 0.96),        # 背景下方
		"floor": hsv(h, 0.45, 0.82),       # 地板
		"ambient": hsv(h, 0.10, 1.0),      # 環境光
		"bar": hsv(h, 0.05, 1.0),          # 面板、橫條
		"light": hsv(h, 0.35, 1.0),        # 淺色按鈕
		"dark": hsv(h, 0.60, 0.55),        # 深色按鈕／邊框
		"text": hsv(h, 0.75, 0.28),        # 文字
		"analog_a": main_color(h + 0.06),
		"analog_b": main_color(h - 0.06),
		"comp": main_color(h + 0.5, 0.8),  # 互補色（強調，彩度較高）
		"comp_light": hsv(h + 0.5, 0.30, 1.0),
		"accent": [base, main_color(h + 0.06), main_color(h - 0.06), main_color(h + 0.5)],
	}


static func park(park_id: String) -> Dictionary:
	return scheme(park_color(park_id))


static func menu() -> Dictionary:
	return scheme(main_color(MENU_HUE))


## 難度：同一個主色由淺到深（越深越難）
static func diff_color(base: Color, d: int) -> Color:
	return hsv(base.h, [0.40, 0.62, 0.80][d], [0.98, 0.88, 0.68][d])
