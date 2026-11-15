extends SceneTree

# 由 icon.svg 產生各平台 PNG 圖示：godot --headless -s res://tools/make_icons.gd

func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	for s in [16, 32, 48, 57, 64, 128, 180, 192, 256, 512, 1024]:
		var img := Image.new()
		img.load_svg_from_string(svg, s / 512.0)
		img.save_png("res://platform/icon_%d.png" % s)
	print("icons ok")
	quit()
