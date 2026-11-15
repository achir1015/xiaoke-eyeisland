extends Node
## 全域狀態：版本、小朋友檔案、設定、過關星星、評估紀錄存取。

const APP_VERSION := "1.0.1"
const APP_NAME := "小柯機器人眼動探險島"
const AUTHOR := "系統開發：吳玉柱 先生 與 Claude AI Opus 5.5"

var settings := {
	"dwell_ms": 1200,        # 看著多久算選取
	"show_cursor": true,     # 顯示視線游標（小星星）
	"cursor_size": 56,
	"magnet": true,          # 視線靠近就吸附到最近的目標
	"click_ok": true,        # 也接受滑鼠點擊（照顧者／測試）
	"auto_eyemouse": true,   # 進入遊戲自動啟動眼動鼠
	"record_gaze": true,     # 記錄視線軌跡做評估報告
	"break_min": 15,         # 連續玩幾分鐘提醒休息（0 = 不提醒）
}
var profiles: Array = []     # [{id, name, age, color, created}]
var current := {}            # 目前的小朋友
var progress := {}           # profile_id -> {level_id: best_stars}
var seen_demo := {}          # profile_id -> {game_id: true}
var no_save := false
var play_started_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "--test":
			no_save = true
	_load()
	play_started_ms = Time.get_ticks_msec()


func _path() -> String:
	return "user://save.json"


func _load() -> void:
	if not FileAccess.file_exists(_path()):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	if typeof(d) != TYPE_DICTIONARY:
		return
	for k in d.get("settings", {}):
		settings[k] = d.settings[k]
	profiles = d.get("profiles", [])
	progress = d.get("progress", {})
	seen_demo = d.get("seen_demo", {})
	var cur := str(d.get("current", ""))
	for p in profiles:
		if str(p.id) == cur:
			current = p


func save() -> void:
	if no_save:
		return
	var d := {"settings": settings, "profiles": profiles, "progress": progress, "seen_demo": seen_demo,
		"current": str(current.get("id", ""))}
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


func add_profile(pname: String, age: int) -> Dictionary:
	var colors := ["#FF8A80", "#FFD180", "#A5D6A7", "#80D8FF", "#B39DDB", "#F8BBD0", "#FFE57F", "#80CBC4"]
	var p := {"id": "p%d" % Time.get_unix_time_from_system(), "name": pname, "age": age,
		"color": colors[profiles.size() % colors.size()], "created": Time.get_datetime_string_from_system()}
	profiles.append(p)
	current = p
	save()
	return p


func remove_profile(pid: String) -> void:
	for i in profiles.size():
		if str(profiles[i].id) == pid:
			profiles.remove_at(i)
			break
	progress.erase(pid)
	if str(current.get("id", "")) == pid:
		current = profiles[0] if not profiles.is_empty() else {}
	save()


func pid() -> String:
	return str(current.get("id", "guest"))


func pname() -> String:
	return str(current.get("name", "小朋友"))


## 依年齡建議難度：3～4 歲簡單、4～6 歲中等、7 歲以上困難
func suggested_diff() -> int:
	var age := int(current.get("age", 5))
	if age <= 4:
		return 0
	if age <= 6:
		return 1
	return 2


func stars(level_id: String) -> int:
	return int(progress.get(pid(), {}).get(level_id, 0))


func set_stars(level_id: String, n: int) -> void:
	if not progress.has(pid()):
		progress[pid()] = {}
	if n > int(progress[pid()].get(level_id, 0)):
		progress[pid()][level_id] = n
	save()


func total_stars() -> int:
	var t := 0
	for k in progress.get(pid(), {}):
		t += int(progress[pid()][k])
	return t


func demo_seen(game_id: String) -> bool:
	return bool(seen_demo.get(pid(), {}).get(game_id, false))


func mark_demo(game_id: String) -> void:
	if not seen_demo.has(pid()):
		seen_demo[pid()] = {}
	seen_demo[pid()][game_id] = true
	save()


func dwell_s() -> float:
	return float(settings.dwell_ms) / 1000.0


# ---------------------------------------------------------------- 評估紀錄
func records_dir(profile_id := "") -> String:
	var d := "user://records/" + (profile_id if profile_id != "" else pid())
	DirAccess.make_dir_recursive_absolute(d)
	return d


## 存一次闖關紀錄：record 是字典（含 rounds，每回合 samples/aois/影像檔名）
func save_record(record: Dictionary, shots: Array) -> String:
	if no_save and not OS.get_cmdline_user_args().has("--save-records"):
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var dir := records_dir().path_join("%s_%s" % [stamp, record.level])
	DirAccess.make_dir_recursive_absolute(dir)
	for i in shots.size():
		var img: Image = shots[i]
		if img:
			img.save_jpg(dir.path_join("round_%d.jpg" % (i + 1)), 0.82)
	var f := FileAccess.open(dir.path_join("record.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(record))
	return dir


func list_records(profile_id := "") -> Array:
	var out: Array = []
	var base := records_dir(profile_id)
	var da := DirAccess.open(base)
	if not da:
		return out
	for d in da.get_directories():
		var p := base.path_join(d).path_join("record.json")
		if FileAccess.file_exists(p):
			var r = JSON.parse_string(FileAccess.get_file_as_string(p))
			if typeof(r) == TYPE_DICTIONARY:
				r["_dir"] = base.path_join(d)
				out.append(r)
	out.sort_custom(func(a, b): return str(a._dir) > str(b._dir))
	return out


func delete_record(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da:
		for f in da.get_files():
			da.remove(f)
	DirAccess.remove_absolute(dir)


func minutes_played() -> float:
	return (Time.get_ticks_msec() - play_started_ms) / 60000.0
