class_name Report
extends RefCounted
## 評估指標計算：注視點（I-DT）、路徑長度、來回比對次數、首次注視目標時間。
## samples：[[t, x, y], ...]，x、y 為 0～1（相對畫面寬高），沒有視線時為 -1。


static func valid_ratio(samples: Array) -> float:
	if samples.is_empty():
		return 0.0
	var n := 0
	for s in samples:
		if float(s[1]) >= 0.0:
			n += 1
	return float(n) / samples.size()


## 路徑長度：以「畫面寬度」為 1 計算（y 依畫面比例換算）
static func path_length(samples: Array, aspect := 16.0 / 9.0) -> float:
	var total := 0.0
	var prev = null
	for s in samples:
		if float(s[1]) < 0.0:
			prev = null
			continue
		var p := Vector2(float(s[1]), float(s[2]) / aspect)
		if prev != null:
			total += p.distance_to(prev)
		prev = p
	return total


## I-DT 注視點偵測：散布 ≤ disp（畫面寬比例）且持續 ≥ min_dur 秒
## 回傳 [{x, y, t, dur}]
static func fixations(samples: Array, aspect := 16.0 / 9.0, disp := 0.035, min_dur := 0.1) -> Array:
	var out: Array = []
	var pts: Array = []
	for s in samples:
		if float(s[1]) >= 0.0:
			pts.append(s)
	var i := 0
	var n := pts.size()
	while i < n:
		var j := i
		var minx := INF
		var maxx := -INF
		var miny := INF
		var maxy := -INF
		while j < n:
			var x := float(pts[j][1])
			var y := float(pts[j][2]) / aspect
			var nminx := minf(minx, x)
			var nmaxx := maxf(maxx, x)
			var nminy := minf(miny, y)
			var nmaxy := maxf(maxy, y)
			if (nmaxx - nminx) + (nmaxy - nminy) > disp:
				break
			minx = nminx
			maxx = nmaxx
			miny = nminy
			maxy = nmaxy
			j += 1
		var dur := float(pts[j - 1][0]) - float(pts[i][0]) if j > i else 0.0
		if j - i >= 2 and dur >= min_dur:
			var sx := 0.0
			var sy := 0.0
			for k in range(i, j):
				sx += float(pts[k][1])
				sy += float(pts[k][2])
			out.append({"x": sx / (j - i), "y": sy / (j - i), "t": float(pts[i][0]), "dur": dur})
			i = j
		else:
			i += 1
	return out


## 注視點落在哪個 AOI（-1 = 都不是）
static func aoi_index(fx: Dictionary, aois: Array, aspect := 16.0 / 9.0) -> int:
	var best := -1
	var best_d := INF
	for k in aois.size():
		var a: Dictionary = aois[k]
		var d := Vector2(float(fx.x) - float(a.x), (float(fx.y) - float(a.y)) / aspect).length()
		if d <= float(a.r) * 1.25 and d < best_d:
			best_d = d
			best = k
	return best


## 單一回合的指標
static func round_metrics(r: Dictionary, aspect := 16.0 / 9.0) -> Dictionary:
	var samples: Array = r.get("samples", [])
	var aois: Array = r.get("aois", [])
	var fx := fixations(samples, aspect)
	var seq: Array = []
	var first_target := -1.0
	var visited := {}
	for f in fx:
		var k := aoi_index(f, aois, aspect)
		if k >= 0:
			if seq.is_empty() or seq[-1] != k:
				seq.append(k)
			visited[k] = true
			if first_target < 0.0 and bool(aois[k].target):
				first_target = float(f.t)
	var switches := maxi(0, seq.size() - 1)
	var mean_dur := 0.0
	for f in fx:
		mean_dur += float(f.dur)
	if not fx.is_empty():
		mean_dur /= fx.size()
	return {"fixations": fx.size(), "mean_fix": mean_dur, "path": path_length(samples, aspect), "switches": switches,
		"visited": visited.size(), "first_target": first_target, "valid": valid_ratio(samples)}


static func record_metrics(rec: Dictionary) -> Dictionary:
	var scr: Array = rec.get("screen", [1280, 720])
	var aspect := float(scr[0]) / maxf(1.0, float(scr[1]))
	var tot := {"fixations": 0, "path": 0.0, "switches": 0, "valid": 0.0, "first_target": 0.0, "ft_n": 0, "time": 0.0}
	var rounds: Array = rec.get("rounds", [])
	for r in rounds:
		var m := round_metrics(r, aspect)
		tot.fixations += m.fixations
		tot.path += m.path
		tot.switches += m.switches
		tot.valid += m.valid
		tot.time += float(r.time)
		if m.first_target >= 0.0:
			tot.first_target += m.first_target
			tot.ft_n += 1
	var n := maxf(1, rounds.size())
	return {"avg_time": tot.time / n, "fixations": tot.fixations, "path": tot.path, "switches": tot.switches,
		"avg_switch": tot.switches / n, "valid": tot.valid / n,
		"first_target": (tot.first_target / tot.ft_n) if tot.ft_n > 0 else -1.0}


static func fmt_pct(v: float) -> String:
	return "—" if v < 0.0 else "%d%%" % roundi(v * 100.0)


static func fmt_s(v: float) -> String:
	return "—" if v < 0.0 else "%.1f 秒" % v
