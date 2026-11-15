extends Node
## 視線輸入：優先連線眼動鼠（127.0.0.1:47961，直接拿到視線座標，眼動鼠暫停自己的點擊）；
## 連不上就用滑鼠位置（眼動鼠舊版、其他眼動儀或照顧者用滑鼠都能玩）。
## 也負責記錄視線軌跡給評估報告。

signal link_changed(linked: bool)

const PORT := 47961

var point := Vector2(-1000, -1000)   # 視線點（根視窗的畫面座標）
var valid := false                   # 目前有沒有視線
var source := "mouse"                # eyemouse / mouse / bot
var linked := false
var eyemouse_version := ""
var eyemouse_source := ""
var lost_for := 0.0                  # 已經多久沒有視線（秒）
var bot_point = null                 # 自動示範／測試：設定 Vector2 就覆蓋真實視線
var started_eyemouse := false

var _tcp: StreamPeerTCP
var _buf := PackedByteArray()
var _retry := 0.0
var _connecting_for := 0.0
var _link_pt := Vector2.ZERO
var _link_t := -10.0
var _lost_flag := false
var _focused := true
var _launch_tried := false

var _recording := false
var _rec: Array = []                 # [t, x, y]（x,y 為 0～1；沒視線時 -1）
var _rec_t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--no-link") or OS.has_feature("web"):
		return
	_try_connect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_send({"cmd": "game", "on": false})
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_send({"cmd": "game", "on": true})
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		shutdown()


func shutdown() -> void:
	if _tcp and _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_send({"cmd": "game", "on": false})
		_tcp.poll()
		_tcp.disconnect_from_host()
	_tcp = null


# ---------------------------------------------------------------- 眼動鼠連線
func _try_connect() -> void:
	_tcp = StreamPeerTCP.new()
	_tcp.set_no_delay(true)
	_tcp.connect_to_host("127.0.0.1", PORT)
	_connecting_for = 0.0


func _send(obj: Dictionary) -> void:
	if _tcp and _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_tcp.put_data((JSON.stringify(obj) + "\n").to_utf8_buffer())


func eyemouse_exe() -> String:
	if OS.get_name() == "Windows":
		var p := OS.get_environment("LOCALAPPDATA").path_join("Programs/EyeMouse/EyeMouse.exe")
		if FileAccess.file_exists(p):
			return p
	elif OS.get_name() == "macOS":
		for p in ["/Applications/眼動鼠.app", "/Applications/EyeMouse.app"]:
			if DirAccess.dir_exists_absolute(p):
				return p
	return ""


## 啟動眼動鼠（已安裝才會啟動；眼動鼠本身只允許一個執行個體，重複啟動只會叫出面板）
func launch_eyemouse() -> bool:
	var exe := eyemouse_exe()
	if exe == "":
		return false
	started_eyemouse = true
	if OS.get_name() == "macOS":
		OS.create_process("open", ["-g", exe, "--args", "--hidden"])
	else:
		OS.create_process(exe, ["--hidden", "--no-tutorial"])
	return true


func _set_linked(v: bool) -> void:
	if v == linked:
		return
	linked = v
	link_changed.emit(v)


func _poll_link(delta: float) -> void:
	if not _tcp:
		return
	_tcp.poll()
	var st := _tcp.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		_connecting_for += delta
		if _connecting_for > 1.5:
			_tcp.disconnect_from_host()
			st = StreamPeerTCP.STATUS_ERROR
	if st == StreamPeerTCP.STATUS_CONNECTED:
		if not linked:
			_set_linked(true)
			_send({"cmd": "hello", "name": Game.APP_NAME})
			_send({"cmd": "game", "on": _focused})
		var n := _tcp.get_available_bytes()
		if n > 0:
			var r := _tcp.get_data(n)
			if r[0] == OK:
				_buf.append_array(r[1])
				_parse()
	elif st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
		if linked:
			_set_linked(false)
		_retry += delta
		if _retry > 2.0:
			_retry = 0.0
			if not _launch_tried and bool(Game.settings.auto_eyemouse):
				_launch_tried = true
				launch_eyemouse()
			_try_connect()


func _parse() -> void:
	while true:
		var i := _buf.find(10)
		if i < 0:
			break
		var line := _buf.slice(0, i).get_string_from_utf8()
		_buf = _buf.slice(i + 1)
		var m = JSON.parse_string(line)
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if m.has("x"):
			_link_pt = Vector2(float(m.x), float(m.y))
			_link_t = Time.get_ticks_msec() / 1000.0
			_lost_flag = false
		elif m.has("lost"):
			_lost_flag = true
		elif str(m.get("ev", "")) == "hello":
			eyemouse_version = str(m.get("version", ""))
			eyemouse_source = str(m.get("source", ""))


## 螢幕物理像素 → 遊戲畫面座標（考慮視窗位置與縮放）
func screen_to_view(p: Vector2) -> Vector2:
	var win := Vector2(DisplayServer.window_get_position())
	var local := p - win
	return get_viewport().get_final_transform().affine_inverse() * local


func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


# ---------------------------------------------------------------- 每格更新
func _process(delta: float) -> void:
	_poll_link(delta)
	var now := Time.get_ticks_msec() / 1000.0
	if bot_point != null:
		source = "bot"
		point = bot_point
		valid = true
	elif linked and eyemouse_source != "mouse":
		source = "eyemouse"
		valid = not _lost_flag and now - _link_t < 0.35
		if valid:
			point = screen_to_view(_link_pt)
	else:
		source = "mouse"
		point = get_viewport().get_mouse_position()
		valid = true
		if linked:   # 眼動鼠用「滑鼠模擬」來源時，連線傳來的就是滑鼠位置
			source = "eyemouse"
			if now - _link_t < 0.35:
				point = screen_to_view(_link_pt)
	lost_for = 0.0 if valid else lost_for + delta
	if _recording:
		var vs := view_size()
		var t := (Time.get_ticks_msec() - _rec_t0) / 1000.0
		if valid:
			_rec.append([snappedf(t, 0.001), snappedf(point.x / vs.x, 0.0001), snappedf(point.y / vs.y, 0.0001)])
		else:
			_rec.append([snappedf(t, 0.001), -1, -1])


func begin_record() -> void:
	_rec = []
	_rec_t0 = Time.get_ticks_msec()
	_recording = bool(Game.settings.record_gaze)


func end_record() -> Array:
	_recording = false
	var r := _rec
	_rec = []
	return r


func status_text() -> String:
	if linked:
		var src: String = {"tobii": "Tobii 眼動儀", "tobii_head": "Tobii 頭控", "webcam": "攝影機眼控", "webcam_head": "攝影機頭控",
			"mouse": "滑鼠模擬"}.get(eyemouse_source, eyemouse_source)
		return "已連線眼動鼠 %s（%s）" % [eyemouse_version, src]
	if eyemouse_exe() != "":
		return "眼動鼠未連線（請開啟眼動鼠 1.3 以上版本）；目前用滑鼠位置"
	return "沒有找到眼動鼠；目前用滑鼠位置操作"
