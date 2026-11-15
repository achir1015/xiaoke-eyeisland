# 小遊戲開發說明（給實作者）

專案：`E:\眼動儀\xiaoke-eyeisland`（Godot 4.7.2，GDScript，gl_compatibility）。給 3～10 歲孩子用「眼動儀注視停留」選取的 3D 視知覺遊戲。

## 必讀檔案
- `scripts/level.gd`：所有遊戲的基底類別 `Level`（流程、選取、回饋、排版工具）。**不要修改**。
- `scripts/models.gd`：程序化 3D 模型 `M.*`（臉、水果、魚、章魚、動物、積木、杯子、樹葉、汽車、盒子…）。**不要修改**；需要新模型就寫在自己的遊戲腳本裡（static func）。
- `scripts/data.gd`：遊戲清單 `GAMES`（名稱、回合數、三種難度說明）。
- `scripts/pal.gd`：相對配色。`theme`＝`Pal.park(id)`（base／wall2／wall／floor／bar／light／dark／text／analog_a／analog_b／comp 互補色／accent）。非題目內容的顏色一律從 theme 取，不寫死。**不要修改**。
- `scripts/games/carousel.gd`：已完成的範例遊戲，照它的寫法。

## 遊戲腳本規則
- 檔案 `scripts/games/<id>.gd`，第一行 `extends Level`。
- `const VOICE := {"<id>_xxx": "要唸的中文句子。", ...}` —— 所有本遊戲會用到的語音都列在這裡（語音檔之後由工具依此產生；鍵名用遊戲 id 開頭、只用英數底線）。動態題目（例如不同顏色）就把所有組合都列出來。
- `build()`：一次性背景佈置（背景牆／地板／環境光已由基底依樂園主題色做好，**不要再設天空或背景**；可加符合主題色系的裝飾，顏色請取 `theme.accent`、`theme.wall`、`theme.floor`、`park_color`）。
- `new_round(i)`：產生回合內容，**全部加到 `round_root`**（每回合自動清空）；`set_prompt("畫面文字", ["語音id", ...])`；需要時 `set_target(模型)` 放左邊目標卡；用 `add_pickable(node, 半徑, {"name": "報告顯示名稱", "target": 是否正確答案})` 註冊可看選的物件（**先 add_pickable 再 pop_in**）；準備好讓孩子作答時呼叫 `ready_to_answer()`（記憶類遊戲的「記憶展示階段」結束後才呼叫）。可用 `await wait(秒)` 做動畫。
- `on_pick(node, data)`：孩子選到物件時呼叫。對 → `good(node)`；錯 → `bad(node)`；整回合完成 → `clear_pickables()` 後 `await wait(0.6)` 再 `finish_round()`（每回合只能呼叫一次）。
- `bot_target() -> Node3D`：自動示範／測試時該選哪個（多步驟回合回傳下一個正確的）。不能選時回傳 null。
- 有提示功能就在 `build()` 設 `has_hint = true`，覆寫 `on_hint()`（基底已記錄提示次數）。
- 完形類（遮蔽）遊戲在 `finish_round()` 前呼叫 `set_coverage(答對時露出比例 0～1)`。
- 難度 `diff`：0 簡單（3～4 歲）、1 中等（4～6 歲）、2 困難（7～10 歲），照 `data.gd` 的 `levels` 說明設計。
- 亂數一律用 `rng`；工具：`grid(n, rect, cols)`、`scatter(n, 最小距離, rect)`、`pick_n`、`shuffled`、`pop_in`、`show_toast`。

## 畫面座標
鏡頭在 (0,0,12) 看 -Z，fov 38。z=0 平面可見約 x∈[-7.3,7.3]、y∈[-4.1,4.1]。上方 HUD 約佔 y>2.9。左邊 x≈-5.75 是目標卡（y≈0.9）和小柯（y≈-2.5），**遊戲物件放在 `Level.AREA`（x -4.3～6.3、y -3.75～2.6）內**。物件大小約 1.2～2.2 單位，可看選半徑通常 0.9～1.3（眼動儀不精準，目標要大、彼此要分開；困難關可以重疊但半徑判定仍要合理）。

## 測試（必做）
```bash
cd "E:/眼動儀/xiaoke-eyeisland"
G="/e/從零建置 Godot 賽車遊戲/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --path . --resolution 1280x720 -- --test --no-link --play=<id>:<難度> --autoplay [--demo] [--wrong=0.3] --shots=<截圖資料夾> --quit
```
成功會印出 `RESULT ... stars=... errors=...`。三種難度都要跑，`--wrong=0.3` 也要跑（測答錯流程），用 Read 看截圖確認畫面清楚好看、物件不被 HUD／目標卡擋住、配色與樂園主題一致。輸出裡 `Unreferenced static string`、`leaked` 是 Godot 結束時的正常訊息，可忽略；其他 `SCRIPT ERROR`／`ERROR` 都要修好。GDScript 注意：從 Variant 推斷型別會被當錯誤，請明寫型別（例如 `var x: String = arr[i]`）。
