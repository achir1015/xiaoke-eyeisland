# 小柯機器人眼動探險島
<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/ea8c1bd2-18f1-404e-a1e2-6b718b4c6dd7" />
說明

https://github.com/user-attachments/assets/0567c2de-01ce-43c4-8377-81bc3d759435

給 3～10 歲孩子的 **3D 眼動視知覺遊戲**（Godot 4.7）。搭配「眼動鼠 EyeMouse」使用：孩子只要用眼睛看著物品或按鈕、等圈圈畫滿就能選取，不需要手。

## 五大主題樂園（30 關）

| 樂園 | 訓練目標 | 小遊戲 |
|---|---|---|
| 彩虹遊樂場 | 視覺辨識 | 旋轉木馬找表情、哪個不一樣 |
| 積木工坊 | 視覺空間關係 | 分類收納箱、方向找一找 |
| 小柯果汁吧 | 視覺記憶與順序記憶 | 果汁配方、杯子藏寶 |
| 海洋搜查隊 | 主題背景區辨 | 找到那條魚、章魚小偵探 |
| 森林躲貓貓 | 視覺完形 | 樹叢躲貓貓（可用提示撥開樹葉）、迷霧猜猜看 |

每個小遊戲有簡單（約 3～4 歲）、中等（約 4～6 歲）、困難（約 7～10 歲）三種難度；每樂園 6 關，共 30 關。系統依小朋友年齡標示建議難度。

## 特色
- **眼動鼠連線**：遊戲啟動時自動連到眼動鼠（127.0.0.1:47961）直接取得視線座標，眼動鼠暫停自己的點擊與游標；遊戲失去焦點或關閉時自動交還。沒有眼動鼠時用滑鼠位置操作（停留或點擊皆可）。
- **遊戲說明與語音**：8 頁動畫說明＋全程繁體中文語音（edge-tts 台灣華語），每關開場、題目、答對答錯都有語音；第一次玩每種遊戲會先由小柯示範。
- **相對配色**：每座樂園由一個主色相推算整組顏色（同色相深淺＋類似色點綴＋互補色強調），畫面一致不雜亂。
- **評估報告**：記錄難易度、作答時間、錯誤次數、提示次數、答對時目標露出比例（覆蓋率），以及每回合的眼球軌跡：一般版（路徑與起訖點）與數字版（注視順序），並計算注視點數、路徑長度、來回比對次數、首次看到目標時間。可匯出含軌跡圖的網頁報告（存到「文件\小柯眼動探險島報告」）。

## 安裝
- **Windows 11**：下載 `XiaokeEyeIsland-Setup.exe` 安裝（會建立桌面捷徑）。
- **macOS**（Intel／Apple 晶片皆可）：下載 `XiaokeEyeIsland-macOS.dmg`，把「小柯機器人眼動探險島」拖到「應用程式」。第一次開啟若被擋，請在 App 上按右鍵 →「打開」，或到「系統設定 → 隱私權與安全性」按「強制打開」。
- 兩個平台都請一併安裝 [眼動鼠](https://github.com/achir1015/eyemouse/releases/latest)（1.3.0 以上），遊戲啟動時會自動開啟並連線。

## 開發
- 語音：`python -I tools/gen_voice.py`（讀 `scripts/data.gd` 與 `scripts/games/*.gd` 的 `VOICE`）
- 音樂音效：`python -I tools/gen_audio.py`（原創程序合成）
- 圖示：`godot --headless -s res://tools/make_icons.gd`
- Windows 版：`bash tools/build_win.sh` → `../build/release/XiaokeEyeIsland-Setup.exe`
- macOS 版：專案複製到 Mac 的 `~/Developer/xiaoke-eyeisland`，`bash platform/macos/build-dmg.sh` → `~/Developer/xiaoke-eyeisland-build/XiaokeEyeIsland-macOS.dmg`（ad-hoc 簽章）
- 測試：`godot --path . -- --test --no-link --play=<遊戲>:<難度> --autoplay [--demo] [--wrong=0.3] --shots=<資料夾> --quit`
- 新增小遊戲：見 `docs/DEV_GAMES.md`

評估報告僅供家長、老師與治療師參考，不能取代專業評估。

系統開發：吳玉柱 先生 與 Claude AI Opus 5.5
