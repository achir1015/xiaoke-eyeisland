extends Node
## 版本更新：讀取網站 version.json 比對版本。
## Windows 下載安裝程式並自動安裝（安裝後自動重開）；其他平台開啟下載／安裝頁。

signal checked(has_update: bool, latest: String, notes: String)
signal progress(ratio: float, text: String)
signal failed(message: String)

const SITE := "https://achir1015.github.io/xiaoke-eyeisland/"
const REPO := "https://github.com/achir1015/xiaoke-eyeisland"
const DL := REPO + "/releases/latest/download/"

var latest := ""
var notes := ""
var has_update := false
var _http: HTTPRequest
var _dl: HTTPRequest
var _dl_path := ""
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_on_checked)


func current_version() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fake-version="):
			return a.get_slice("=", 1)
	return Game.APP_VERSION


func platform_name() -> String:
	if OS.has_feature("web"):
		return "線上版"
	match OS.get_name():
		"Windows": return "Windows"
		"macOS": return "macOS"
		"Android": return "Android"
		"iOS": return "iPhone／iPad"
	return OS.get_name()


func check() -> void:
	if _busy:
		return
	_busy = true
	var err := _http.request(SITE + "version.json?t=%d" % Time.get_unix_time_from_system())
	if err != OK:
		_busy = false
		failed.emit("無法連線（%d）" % err)


func _on_checked(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		failed.emit("無法取得版本資訊，請確認網路連線。")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("version"):
		failed.emit("版本資訊格式錯誤。")
		return
	latest = str(data.version)
	notes = str(data.get("notes", ""))
	has_update = compare(latest, current_version()) > 0
	checked.emit(has_update, latest, notes)


static func compare(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


func apply_update() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()")
		return
	match OS.get_name():
		"Windows": _download_windows()
		"macOS": OS.shell_open(DL + "XiaokeEyeIsland-macOS.dmg")
		"Android": OS.shell_open(DL + "XiaokeEyeIsland-Android.apk")
		"iOS": OS.shell_open(SITE + "ios/")
		_: OS.shell_open(SITE)


func _download_windows() -> void:
	if _dl:
		return
	var dir := OS.get_user_data_dir().path_join("update")
	DirAccess.make_dir_recursive_absolute(dir)
	_dl_path = dir.path_join("XiaokeEyeIsland-Setup-%s.exe" % latest)
	_dl = HTTPRequest.new()
	_dl.download_file = _dl_path
	_dl.max_redirects = 10
	_dl.timeout = 900.0
	_dl.use_threads = true
	add_child(_dl)
	_dl.request_completed.connect(_on_downloaded)
	if _dl.request(DL + "XiaokeEyeIsland-Setup.exe") != OK:
		_dl.queue_free()
		_dl = null
		failed.emit("下載失敗")
		return
	progress.emit(0.0, "開始下載…")


func _process(_dt: float) -> void:
	if _dl and _dl.get_http_client_status() == HTTPClient.STATUS_BODY:
		var total := _dl.get_body_size()
		var got := _dl.get_downloaded_bytes()
		if total > 0:
			progress.emit(float(got) / total, "下載中 %d / %d MB" % [got / 1048576, total / 1048576])


func _on_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_dl.queue_free()
	_dl = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(_dl_path):
		failed.emit("下載安裝程式失敗（%d / %d）。" % [result, code])
		return
	progress.emit(1.0, "下載完成，正在安裝新版…")
	var pid := OS.create_process(_dl_path, ["/SILENT", "/SP-", "/NOCANCEL", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS"])
	if pid <= 0:
		failed.emit("無法啟動安裝程式。")
		return
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()
