"""產生語音（edge-tts 台灣華語「曉臻」，童趣慢一點）。

用法：python -I tools/gen_voice.py [--force]
來源：
  scripts/data.gd 的 VOICE（共用台詞）、HELP（說明頁 → help_NN）、GAMES 的 desc（→ intro_<遊戲>）
  scripts/games/*.gd 的 const VOICE
只重做文字有變動的（記錄在 assets/voice/manifest.json）。輸出 assets/voice/<id>.ogg
"""
import asyncio
import glob
import json
import os
import re
import subprocess
import sys

import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voice")
VOICE = "zh-TW-HsiaoChenNeural"
REPL = [("／", "、"), ("～", "到"), ("→", "，"), ("•", ""), ("　", "，"), ("「", ""), ("」", ""), ("（", "，"), ("）", "，")]


def clean(t: str) -> str:
    t = t.replace("\\n", "\n")
    for a, b in REPL:
        t = t.replace(a, b)
    out = []
    for ln in (x.strip() for x in t.split("\n")):
        if not ln:
            continue
        if not re.search(r"[。！？：；，、]$", ln):
            ln += "。"
        out.append(ln)
    return "".join(out)


def dict_block(src: str, name: str) -> dict:
    m = re.search(r"const " + name + r" := \{(.*?)\n\}", src, re.S)
    if not m:
        return {}
    return dict(re.findall(r'"(\w+)": "((?:[^"\\]|\\.)*)"', m.group(1)))


def collect() -> dict:
    lines = {}
    data = open(os.path.join(ROOT, "scripts", "data.gd"), encoding="utf8").read()
    lines.update(dict_block(data, "VOICE"))
    hb = data[data.index("const HELP"):]
    hb = hb[:hb.index("\n]\n")]
    for i, (title, body) in enumerate(re.findall(r'\["([^"]+)", "((?:[^"\\]|\\.)*)"\]', hb)):
        lines["help_%02d" % i] = title + "。" + body
    gb = data[data.index("const GAMES"):data.index("## 共用語音")]
    for gid, name, desc in re.findall(r'"(\w+)": \{"name": "([^"]+)".*?"desc": "([^"]+)"', gb, re.S):
        lines["intro_" + gid] = name + "。" + desc
    for f in sorted(glob.glob(os.path.join(ROOT, "scripts", "games", "*.gd"))):
        lines.update(dict_block(open(f, encoding="utf8").read(), "VOICE"))
    return {k: clean(v) for k, v in lines.items()}


async def speak(text: str, name: str):
    mp3 = os.path.join(OUT, name + ".mp3")
    ogg = os.path.join(OUT, name + ".ogg")
    for attempt in range(4):
        try:
            await edge_tts.Communicate(text, VOICE, rate="-5%", pitch="+8Hz").save(mp3)
            break
        except Exception as e:  # noqa: BLE001 — 網路偶發錯誤重試
            print("retry", name, e, flush=True)
            await asyncio.sleep(2 + attempt * 2)
    else:
        raise RuntimeError("語音失敗：" + name)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", mp3, "-ac", "1", "-ar", "24000", "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(mp3)


async def main():
    os.makedirs(OUT, exist_ok=True)
    mf = os.path.join(OUT, "manifest.json")
    old = json.load(open(mf, encoding="utf8")) if os.path.exists(mf) else {}
    lines = collect()
    force = "--force" in sys.argv
    todo = [k for k, v in lines.items() if force or old.get(k) != v or not os.path.exists(os.path.join(OUT, k + ".ogg"))]
    print(f"共 {len(lines)} 句，要產生 {len(todo)} 句", flush=True)
    sem = asyncio.Semaphore(6)

    async def one(k):
        async with sem:
            await speak(lines[k], k)
            old[k] = lines[k]
            print("ok", k, flush=True)

    await asyncio.gather(*(one(k) for k in todo))
    for k in list(old):
        if k not in lines:
            old.pop(k)
    json.dump(old, open(mf, "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print("done", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
