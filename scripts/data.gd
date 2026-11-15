class_name Data
extends RefCounted
## 五大主題樂園、10 種小遊戲 × 3 種難度 = 30 關；共用語音台詞與遊戲說明。

const DIFF_NAMES := ["簡單", "中等", "困難"]
const DIFF_AGES := ["約 3～4 歲", "約 4～6 歲", "約 7～10 歲"]

const PARKS := [
	{"id": "rainbow", "name": "彩虹遊樂場", "skill": "視覺辨識", "color": "#F25C6E", "music": "m02_rainbow",
		"goal": "分辨看到的東西哪裡一樣、哪裡不一樣，練習圖形與表情的辨識。", "games": ["carousel", "oddone"]},
	{"id": "blocks", "name": "積木工坊", "skill": "視覺空間關係", "color": "#5085D4", "music": "m03_blocks",
		"goal": "觀察顏色、形狀、大小和方向，建立空間概念。", "games": ["sort", "direction"]},
	{"id": "juice", "name": "小柯果汁吧", "skill": "視覺記憶與順序記憶", "color": "#AD7542", "music": "m04_juice",
		"goal": "記住看過的東西和出現的順序，練習短期視覺記憶。", "games": ["juice", "cups"]},
	{"id": "ocean", "name": "海洋搜查隊", "skill": "主題背景區辨", "color": "#379191", "music": "m05_ocean",
		"goal": "在很多東西重疊、很亂的畫面裡，專心找出指定的目標。", "games": ["fishfind", "octopus"]},
	{"id": "forest", "name": "森林躲貓貓", "skill": "視覺完形", "color": "#3A9944", "music": "m06_forest",
		"goal": "只看到一部分、被擋住的東西，也能猜出它是什麼。", "games": ["bush", "fog"]},
]

## 各樂園配色改由 scripts/pal.gd 依主色相對推算（Pal.park(id)）

## script：遊戲腳本；demo：示範語音
const GAMES := {
	"carousel": {"name": "旋轉木馬找表情", "park": "rainbow", "script": "res://scripts/games/carousel.gd", "rounds": 5,
		"desc": "旋轉木馬上坐著好多張臉，看著和左邊卡片一樣表情的那張臉。",
		"levels": ["兩種表情，木馬轉得慢", "四種表情，木馬轉快一點", "七種表情，有些很像，要看仔細"]},
	"oddone": {"name": "哪個不一樣", "park": "rainbow", "script": "res://scripts/games/oddone.gd", "rounds": 5,
		"desc": "一排東西裡有一個和別人不一樣，把它找出來。",
		"levels": ["四個東西，顏色不一樣", "六個東西，形狀或數量不一樣", "九個東西，只差一點點"]},
	"sort": {"name": "分類收納箱", "park": "blocks", "script": "res://scripts/games/sort.gd", "rounds": 6,
		"desc": "中間出現一個積木，看著和它一樣的收納箱，積木就會飛進去。",
		"levels": ["兩個箱子，依顏色分類", "三個箱子，依形狀分類", "四個箱子，顏色和形狀都要一樣"]},
	"direction": {"name": "方向找一找", "park": "blocks", "script": "res://scripts/games/direction.gd", "rounds": 5,
		"desc": "找出方向和左邊卡片一模一樣的那一個。",
		"levels": ["小汽車朝四個方向", "箭頭有八個方向", "積木會翻面（鏡像），要看清楚"]},
	"juice": {"name": "果汁配方", "park": "juice", "script": "res://scripts/games/juice.gd", "rounds": 4,
		"desc": "記住配方上水果出現的順序，再照順序把水果放進果汁機。",
		"levels": ["記兩種水果", "記三種水果", "記四到五種水果"]},
	"cups": {"name": "杯子藏寶", "park": "juice", "script": "res://scripts/games/cups.gd", "rounds": 5,
		"desc": "記住東西藏在哪個杯子下面，杯子蓋起來以後找出來。",
		"levels": ["三個杯子藏一樣東西", "四個杯子藏兩樣東西", "六個杯子藏三樣東西"]},
	"fishfind": {"name": "找到那條魚", "park": "ocean", "script": "res://scripts/games/fishfind.gd", "rounds": 5,
		"desc": "海裡有好多魚游來游去，找出和卡片一樣顏色、一樣花紋的魚。",
		"levels": ["六條魚，顏色都不一樣", "十條魚，有些顏色或花紋一樣", "十六條魚擠在一起，還有海草擋住"]},
	"octopus": {"name": "章魚小偵探", "park": "ocean", "script": "res://scripts/games/octopus.gd", "rounds": 5,
		"desc": "每隻章魚戴不同的帽子、拿不同的東西，找出題目說的那一隻。",
		"levels": ["只看帽子顏色", "帽子顏色和手上的東西都要對", "很多章魚擠在一起，兩個特徵都要對"]},
	"bush": {"name": "樹叢躲貓貓", "park": "forest", "script": "res://scripts/games/bush.gd", "rounds": 5,
		"desc": "有動物躲在樹叢後面，看看露出來的地方，選出是哪一種動物。看不出來可以用提示撥開樹葉。",
		"levels": ["露出一半，三個選項", "露出三分之一，四個選項", "只露出一點點，五個選項"]},
	"fog": {"name": "迷霧猜猜看", "park": "forest", "script": "res://scripts/games/fog.gd", "rounds": 5,
		"desc": "東西藏在雲霧裡，雲霧會一塊一塊散開，越早猜對越厲害。",
		"levels": ["雲霧散得快，三個選項", "雲霧散得慢，四個選項", "選項長得很像，五個選項"]},
}

## 共用語音（遊戲各自的語音寫在各遊戲腳本的 VOICE）
const VOICE := {
	"welcome": "歡迎來到小柯機器人眼動探險島！我是小柯。用眼睛看著按鈕，等圈圈畫滿，就可以選取囉。",
	"pick_profile": "請選擇你的名字，或是新增一位小朋友。",
	"pick_park": "想去哪一座樂園玩呢？用眼睛看著它。",
	"pick_level": "選一個關卡吧。顏色越淺越簡單，越深越難。",
	"demo_start": "小柯先示範一次給你看喔。",
	"your_turn": "換你囉！",
	"good1": "答對了！", "good2": "好棒喔！", "good3": "你真厲害！", "good4": "太棒了！", "good5": "完全正確！",
	"try1": "再找找看喔。", "try2": "不是這個喔，再試一次。", "try3": "沒關係，再看仔細一點。",
	"gaze_lost": "小柯看不到你的眼睛囉，請看著螢幕。",
	"level_done": "過關了！你好厲害！",
	"stars3": "拿到三顆星星，完美！", "stars2": "拿到兩顆星星，很不錯喔！", "stars1": "拿到一顆星星，下次會更好！",
	"rest": "已經玩了一段時間囉，閉上眼睛休息一下，看看遠方吧。",
	"paused": "暫停了，休息一下。",
	"park_rainbow": "彩虹遊樂場。在這裡要分辨東西哪裡一樣、哪裡不一樣。",
	"park_blocks": "積木工坊。在這裡要觀察顏色、形狀和方向。",
	"park_juice": "小柯果汁吧。在這裡要記住看過的東西和順序。",
	"park_ocean": "海洋搜查隊。在很亂的海底，找出指定的目標。",
	"park_forest": "森林躲貓貓。東西只露出一部分，猜猜它是什麼。",
	"report": "這是眼動評估報告，可以看到每一關的作答時間、錯誤次數，還有眼睛看過的路線。",
	"bye": "謝謝你來玩，下次見！",
}

## 遊戲說明（文字＋語音 help_NN；第一行標題、第二行起內容）
const HELP := [
	["歡迎來到眼動探險島", "這是給三到十歲小朋友的眼睛遊戲。\n不用滑鼠、不用手，只要用眼睛看，就能玩。\n島上有五座主題樂園，每座樂園有六個關卡。"],
	["用眼睛選東西", "眼睛看著按鈕或是物品，旁邊會出現一個圈圈。\n一直看著，等圈圈畫滿，就選好了。\n眼睛移開，圈圈就會消失，不會選錯。"],
	["搭配眼動鼠", "請先打開眼動鼠，遊戲會自動連線。\n連線後，眼動鼠會暫停自己的點擊，讓遊戲用眼睛選取。\n沒有眼動儀的時候，也可以用滑鼠點或用滑鼠停留。"],
	["五大主題樂園", "彩虹遊樂場：視覺辨識。\n積木工坊：視覺空間關係。\n小柯果汁吧：視覺記憶與順序記憶。\n海洋搜查隊：主題背景區辨。\n森林躲貓貓：視覺完形。"],
	["三種難度", "綠色是簡單，適合三到四歲。\n黃色是中等，適合四到六歲。\n紅色是困難，適合七到十歲。\n小柯會依照年齡建議難度，也可以自己選。"],
	["每一關怎麼玩", "上方會告訴你要做什麼，按喇叭可以再聽一次。\n左邊卡片是要找的目標。\n第一次玩會先看小柯示範。\n答對會拿到星星，答錯沒關係，再試一次就好。"],
	["評估報告", "每玩完一關，會記錄作答時間、錯誤次數、使用提示的次數。\n森林躲貓貓還會記錄答對時露出多少。\n報告裡可以看到眼睛看過的路線和注視的順序。"],
	["給家長與老師", "按鍵盤 Esc 或右上角的暫停鍵，可以暫停或回到選單。\n設定裡可以調整看多久才選取、游標大小與音量。\n評估紀錄只存在這台電腦裡，可以匯出成網頁報告。"],
]


static func park(id: String) -> Dictionary:
	for p in PARKS:
		if p.id == id:
			return p
	return {}


static func game_info(gid: String) -> Dictionary:
	var g: Dictionary = GAMES[gid].duplicate()
	g["id"] = gid
	g["color"] = park(g.park).color
	return g


## 樂園內 6 關的順序：（遊戲 A 簡單、遊戲 B 簡單、A 中等、B 中等、A 困難、B 困難）
static func park_levels(park_id: String) -> Array:
	var p := park(park_id)
	var out: Array = []
	for d in 3:
		for g in p.games:
			out.append({"game": g, "diff": d, "id": "%s_%d" % [g, d], "no": out.size() + 1})
	return out


static func level_title(level_id: String) -> String:
	var gid := level_id.substr(0, level_id.rfind("_"))
	var d := int(level_id.get_slice("_", level_id.get_slice_count("_") - 1))
	if not GAMES.has(gid):
		return level_id
	return "%s（%s）" % [GAMES[gid].name, DIFF_NAMES[d]]
