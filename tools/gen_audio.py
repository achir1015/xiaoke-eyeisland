"""產生遊戲背景音樂（20 首、每首 3 分多鐘）與音效，全部原創程序合成。

用法：python -I tools/gen_audio.py [曲名 ... | sfx]
輸出：assets/music/*.ogg、assets/sfx/*.wav（需要 numpy、scipy、ffmpeg）
"""
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "assets", "music")
SFX = os.path.join(ROOT, "assets", "sfx")
rng = np.random.default_rng(20261115)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def lowpass(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def highpass(x, fc, order=2):
    b, a = butter(order, min(fc / (SR / 2), 0.99), "high")
    return lfilter(b, a, x)


def env(n, a=0.005, d=0.08, s=0.6, r=0.05):
    t = np.arange(n) / SR
    dur = n / SR
    e = np.ones(n) * s
    ai = t < a
    e[ai] = t[ai] / a
    di = (t >= a) & (t < a + d)
    e[di] = 1 - (1 - s) * (t[di] - a) / d
    ri = t > dur - r
    e[ri] *= np.clip((dur - t[ri]) / r, 0, 1)
    return e


def osc(kind, f, n, detune=0.0):
    t = np.arange(n) / SR
    ph = 2 * np.pi * f * t
    if kind == "saw":
        out = np.zeros(n)
        ds = (-detune, 0.0, detune) if detune else (0.0,)
        for d in ds:
            out += 2 * ((f * (1 + d) * t) % 1.0) - 1
        return out / len(ds)
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if kind == "pulse":
        return np.where((f * t) % 1.0 < 0.25, 0.6, -0.6)
    if kind == "tri":
        return 2 * np.abs(2 * ((f * t) % 1.0) - 1) - 1
    if kind == "pluck":
        return (np.sin(ph) * 0.6 + np.sin(2 * ph) * 0.25 + np.sin(3 * ph) * 0.12) * np.exp(-t * 4)
    if kind == "epiano":  # 電鋼琴：FM 鐘聲感
        mod = np.sin(ph * 2) * 1.6 * np.exp(-t * 3)
        return np.sin(ph + mod) * 0.7 + np.sin(ph) * 0.3
    if kind == "piano":
        return (np.sin(ph) + 0.5 * np.sin(2 * ph) * np.exp(-t * 3) + 0.25 * np.sin(3 * ph) * np.exp(-t * 5)) * np.exp(-t * 1.8) * 0.6
    if kind == "organ":
        return (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(4 * ph)) * 0.5
    if kind == "brass":
        b = osc("saw", f, n, 0.002)
        return lowpass(b, min(800 + f * 4, 7000))
    if kind == "string":
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t)
        return (2 * ((f * vib * t) % 1.0) - 1 + 2 * ((f * 1.004 * t) % 1.0) - 1) * 0.5
    if kind == "marimba":
        return (np.sin(ph) + 0.3 * np.sin(4 * ph) * np.exp(-t * 20)) * np.exp(-t * 7)
    if kind == "steel":  # 鋼鼓
        return (np.sin(ph) + 0.5 * np.sin(2.01 * ph) + 0.25 * np.sin(3.98 * ph)) * np.exp(-t * 3.5) * 0.6
    return np.sin(ph)


def add(buf, sig, start):
    s = int(start)
    if s >= len(buf) or s < 0:
        return
    e = min(len(buf), s + len(sig))
    buf[s:e] += sig[: e - s]


def _kick(n=int(0.35 * SR)):
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def _snare(n=int(0.25 * SR)):
    t = np.arange(n) / SR
    return highpass(rng.standard_normal(n), 1500) * np.exp(-t * 18) * 0.5 + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.5


def _hat(open_=False):
    n = int((0.22 if open_ else 0.05) * SR)
    t = np.arange(n) / SR
    return highpass(rng.standard_normal(n), 7000) * np.exp(-t * (14 if open_ else 60)) * 0.35


def _rim(n=int(0.06 * SR)):
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 1700 * t) + highpass(rng.standard_normal(n), 3000) * 0.4) * np.exp(-t * 70) * 0.5


def _shaker(n=int(0.07 * SR)):
    t = np.arange(n) / SR
    return highpass(rng.standard_normal(n), 5000) * np.sin(np.pi * t / (n / SR)) * 0.22


def _clap(n=int(0.2 * SR)):
    t = np.arange(n) / SR
    e = np.exp(-t * 22)
    for k in (0.01, 0.02):
        e += np.where(t > k, np.exp(-(t - k) * 40), 0) * 0.6
    return highpass(rng.standard_normal(n), 1200) * e * 0.4


def _brush(n=int(0.18 * SR)):
    t = np.arange(n) / SR
    return lowpass(highpass(rng.standard_normal(n), 2000), 6000) * np.exp(-t * 14) * 0.25


KICK, SNARE, HAT, OHAT, RIM, SHAKER, CLAP, BRUSH = _kick(), _snare(), _hat(), _hat(True), _rim(), _shaker(), _clap(), _brush()

CH = {
    "C": [48, 52, 55], "Cmaj7": [48, 52, 55, 59], "C7": [48, 52, 55, 58], "Cm": [48, 51, 55], "Cm7": [48, 51, 55, 58],
    "D": [50, 54, 57], "Dm": [50, 53, 57], "Dm7": [50, 53, 57, 60], "D7": [50, 54, 57, 60],
    "E": [52, 56, 59], "Em": [52, 55, 59], "Em7": [52, 55, 59, 62], "E7": [52, 56, 59, 62], "Eb": [51, 55, 58], "Ebmaj7": [51, 55, 58, 62],
    "F": [53, 57, 60], "Fmaj7": [53, 57, 60, 64], "Fm": [53, 56, 60], "Fm7": [53, 56, 60, 63], "F#m": [54, 57, 61],
    "G": [55, 59, 62], "G7": [55, 59, 62, 65], "Gm": [55, 58, 62], "Gm7": [55, 58, 62, 65],
    "A": [45, 49, 52], "Am": [45, 48, 52], "Am7": [45, 48, 52, 55], "A7": [45, 49, 52, 55], "Ab": [44, 48, 51], "Abmaj7": [44, 48, 51, 55],
    "Bb": [46, 50, 53], "Bbmaj7": [46, 50, 53, 57], "Bm": [47, 50, 54], "Bm7": [47, 50, 54, 57], "B7": [47, 51, 54, 57],
}

# 風格設定：鼓型、貝斯、和弦樂器、旋律樂器、琶音樂器、搖擺
STYLES = {
    "lounge": dict(drum="jazz", bass="walk", chord="epiano", lead="piano", arp=None, swing=0.62),
    "bossa": dict(drum="bossa", bass="bossa", chord="epiano", lead="marimba", arp=None, swing=0.5),
    "lofi": dict(drum="lofi", bass="soft", chord="epiano", lead="epiano", arp=None, swing=0.58),
    "funk": dict(drum="funk", bass="funk", chord="organ", lead="brass", arp="pulse", swing=0.54),
    "citypop": dict(drum="pop", bass="octave", chord="epiano", lead="square", arp="pluck", swing=0.5),
    "synth": dict(drum="pop", bass="octave", chord="string", lead="square", arp="square", swing=0.5),
    "epic": dict(drum="epic", bass="soft", chord="string", lead="brass", arp="pluck", swing=0.5),
    "tense": dict(drum="tense", bass="pulse", chord="string", lead="saw", arp="square", swing=0.5),
    "tropical": dict(drum="tropical", bass="bossa", chord="organ", lead="steel", arp="marimba", swing=0.5),
    "chip": dict(drum="pop", bass="octave", chord="pulse", lead="pulse", arp="square", swing=0.5),
    "march": dict(drum="march", bass="octave", chord="brass", lead="brass", arp="pluck", swing=0.5),
}


def song(style, bpm, prog, scale, seed, minutes=3.3, key=0):
    st = STYLES[style]
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    bars = int(round(minutes * 60 / bar / 8)) * 8
    n = int(bars * bar * SR) + int(2 * SR)
    drums, bass, chords, lead, arp = (np.zeros(n) for _ in range(5))
    s16 = beat / 4
    sw = st["swing"]

    def pos16(b, k):  # 搖擺：偶數 8 分音符後半拍延後
        t = b * bar + (k // 2) * (beat / 2)
        if k % 2:
            t += beat / 2 * (sw if k % 4 in (1, 3) else 0.5) if sw != 0.5 else s16
        return t * SR

    # 兩組旋律動機（A 段、B 段），每 8 小節換段
    motifs = [[int(r.choice(scale)) for _ in range(16)] for _ in range(3)]
    rhy = [[1 if r.random() < p else 0 for _ in range(16)] for p in (0.55, 0.45, 0.65)]
    for rr in rhy:
        rr[0] = 1
    plan = []  # 每 8 小節的段落：intro / A / B / break / C / outro
    blocks = bars // 8
    for i in range(blocks):
        if i == 0:
            plan.append("intro")
        elif i == blocks - 1:
            plan.append("outro")
        elif i % 4 == 3:
            plan.append("break")
        else:
            plan.append("ABC"[(i - 1) % 3] if i % 4 != 2 else "B")
    for b in range(bars):
        sec = plan[b // 8]
        kshift = key + (2 if b >= bars * 0.72 and sec != "outro" else 0)  # 尾段升調
        ch = [c + kshift for c in CH[prog[b % len(prog)]]]
        t0 = b * bar * SR
        full = sec in ("A", "B", "C")
        light = sec in ("intro", "break", "outro")
        fade = 1.0 if sec != "outro" else max(0.15, 1 - (b % 8) / 8)
        # ---- 鼓 ----
        dk = st["drum"]
        for k in range(16):
            p = pos16(b, k)
            if dk == "jazz":
                if k in (0, 6, 8, 14) or (k in (4, 12)):
                    add(drums, RIM * 0.6 if k in (4, 12) else HAT * 0.9, p)
                if not light and k in (0, 10):
                    add(drums, KICK * 0.35, p)
                if k in (4, 12):
                    add(drums, BRUSH, p)
            elif dk == "bossa":
                if k in (0, 6, 8, 14):
                    add(drums, KICK * 0.45, p)
                if k in (0, 3, 6, 10, 12):
                    add(drums, RIM * 0.7, p)
                add(drums, SHAKER * (0.9 if k % 2 == 0 else 0.5), p)
            elif dk == "lofi":
                if k in (0, 7, 10):
                    add(drums, lowpass(KICK, 2000) * 0.8, p)
                if k in (4, 12) and not (light and b % 8 < 4):
                    add(drums, lowpass(SNARE, 4000) * 0.6, p)
                if k % 2 == 0:
                    add(drums, HAT * 0.45, p)
            elif dk == "funk":
                if k in (0, 3, 8, 10):
                    add(drums, KICK, p)
                if k in (4, 12):
                    add(drums, SNARE, p)
                if k in (7, 15):
                    add(drums, SNARE * 0.2, p)
                add(drums, HAT * (0.7 if k % 2 == 0 else 0.4), p)
            elif dk == "pop":
                if k % 4 == 0 and not (sec == "intro" and b % 8 < 2):
                    add(drums, KICK, p)
                if k in (4, 12) and not light:
                    add(drums, CLAP * 0.8, p)
                    add(drums, SNARE * 0.4, p)
                if k % 2 == 1:
                    add(drums, HAT * 0.7, p)
                if k == 14 and sec == "C":
                    add(drums, OHAT, p)
            elif dk == "epic":
                if k in (0, 6, 8) and not light:
                    add(drums, KICK * 1.1, p)
                if k in (4, 12) and full:
                    add(drums, SNARE * 0.9, p)
                if sec == "C" and k % 2 == 0:
                    add(drums, lowpass(KICK, 300) * 0.5, p)
            elif dk == "tense":
                if k % 4 == 0:
                    add(drums, KICK, p)
                if k in (3, 11) and full:
                    add(drums, KICK * 0.6, p)
                if k in (4, 12) and not light:
                    add(drums, SNARE * 0.8, p)
                add(drums, HAT * 0.45, p)
            elif dk == "tropical":
                if k in (0, 8):
                    add(drums, KICK * 0.8, p)
                if k in (4, 12) and not light:
                    add(drums, CLAP * 0.7, p)
                if k in (3, 6, 11, 14):
                    add(drums, RIM * 0.5, p)
                add(drums, SHAKER * 0.6, p)
            elif dk == "march":
                if k in (0, 8):
                    add(drums, KICK, p)
                if not light and k in (4, 12, 14, 15):
                    add(drums, SNARE * (0.9 if k in (4, 12) else 0.35), p)
                if k % 2 == 0:
                    add(drums, HAT * 0.4, p)
        if b % 8 == 7 and full:  # 過門
            for k in (12, 13, 14, 15):
                add(drums, SNARE * 0.4, pos16(b, k))
        # ---- 貝斯 ----
        root = ch[0] - 24
        bk = st["bass"]
        if bk == "walk":
            nxt = CH[prog[(b + 1) % len(prog)]][0] + kshift - 24
            steps = [root, root + (ch[1] - ch[0]), root + 7, nxt - 1 if r.random() < 0.6 else nxt + 1]
            for i, nn in enumerate(steps):
                seg = osc("sine", midi(nn), int(beat * SR * 0.9)) + osc("tri", midi(nn), int(beat * SR * 0.9)) * 0.25
                add(bass, seg * env(len(seg), 0.01, 0.15, 0.5, 0.05) * 0.7, pos16(b, i * 4))
        elif bk == "bossa":
            for k, nn in ((0, root), (6, root + 7), (8, root + 7), (14, root)):
                seg = osc("sine", midi(nn + 12), int(s16 * 3 * SR))
                add(bass, seg * env(len(seg), 0.01, 0.2, 0.5, 0.05) * 0.7, pos16(b, k))
        elif bk == "soft":
            for k in (0, 8) if not light else (0,):
                seg = osc("sine", midi(root + 12), int(beat * (2 if not light else 4) * SR))
                add(bass, seg * env(len(seg), 0.02, 0.3, 0.6, 0.2) * 0.6, pos16(b, k))
        elif bk == "funk":
            pat = [(0, 0), (3, 12), (6, 0), (8, 0), (10, 10), (11, 12), (14, 7)]
            for k, iv in pat:
                seg = lowpass(osc("saw", midi(root + iv + 12), int(s16 * SR * 0.85), 0.003), 900)
                add(bass, seg * env(len(seg), 0.003, 0.05, 0.6, 0.02) * 0.6, pos16(b, k))
        elif bk in ("octave", "pulse"):
            stepk = 2 if bk == "octave" else 1
            for k in range(0, 16, stepk):
                nn = root + (12 if (bk == "octave" and k % 4 == 2) else 0) + 12
                seg = lowpass(osc("saw", midi(nn), int(s16 * stepk * SR * 0.85), 0.003), 700)
                add(bass, seg * env(len(seg), 0.003, 0.06, 0.6, 0.02) * (0.55 if not light else 0.3), pos16(b, k))
        # ---- 和弦 ----
        L = int(bar * SR)
        ck = st["chord"]
        if ck in ("string", "organ", "brass") or light:
            p = sum(osc(ck if ck != "pulse" else "string", midi(c + 12), L) for c in ch)
            p = lowpass(p, 2200) * env(L, 0.15 if ck == "string" else 0.02, 0.3, 0.75, 0.2)
            add(chords, p * 0.08, t0)
        else:  # 節奏和弦（電鋼琴、方波）
            hits = (0, 6, 10) if style in ("bossa", "lounge") else (0, 3, 8, 11) if style == "funk" else (0, 6, 8, 14)
            for k in hits:
                dur = int(s16 * 3 * SR)
                p = sum(osc(ck, midi(c + 12), dur) for c in ch)
                add(chords, lowpass(p, 3500) * env(dur, 0.004, 0.2, 0.4, 0.05) * 0.1, pos16(b, k))
        # ---- 琶音 ----
        if st["arp"] and not (sec == "intro" and b % 8 < 4):
            notes = ch + [ch[0] + 12, ch[1] + 12]
            stepk = 2 if style in ("citypop", "tropical", "epic", "march") else 1
            for k in range(0, 16, stepk):
                nn = notes[(k // stepk) % len(notes)] + 24
                seg = osc(st["arp"], midi(nn), int(s16 * stepk * SR * 0.8))
                add(arp, lowpass(seg, 4000) * env(len(seg), 0.002, 0.06, 0.25, 0.03) * 0.07, pos16(b, k))
        # ---- 旋律 ----
        if full or (sec == "break" and b % 2 == 0):
            mi = {"A": 0, "B": 1, "C": 2, "break": 1}[sec]
            mo, rh = motifs[mi], rhy[mi]
            for k in range(16):
                if not rh[k]:
                    continue
                nn = mo[(k + (b % 2) * 8) % 16] + kshift + (12 if sec == "C" else 0)
                if b % 4 == 3 and k >= 12:  # 樂句收在和弦音
                    nn = ch[0] + 24
                    if k > 12:
                        continue
                length = 1
                while k + length < 16 and not rh[k + length] and length < 4:
                    length += 1
                dur = int(s16 * length * SR * 0.95)
                seg = osc(st["lead"], midi(nn), dur, 0.003)
                vib = 1 + 0.003 * np.sin(2 * np.pi * 5.5 * np.arange(dur) / SR)
                seg = lowpass(seg * vib, 4500) * env(dur, 0.005, 0.1, 0.6, 0.05)
                add(lead, seg * 0.13 * (0.7 if sec == "break" else 1.0), pos16(b, k))
        for buf in (drums, bass, chords, lead, arp):
            s, e = int(t0), int(t0 + bar * SR)
            buf[s:e] *= fade

    def delay(x, sec, fb, mix):
        d = int(sec * SR)
        y = x.copy()
        for k in range(1, 4):
            y[d * k:] += x[:-d * k] * (fb ** k) * mix
        return y

    lead = delay(lead, beat * 0.75, 0.4, 0.5)
    arp = delay(arp, beat * 0.5, 0.35, 0.45)
    chords = delay(chords, beat * 1.5, 0.3, 0.35)
    if style == "lofi":  # 黑膠底噪
        crackle = (rng.random(n) < 0.0006) * rng.standard_normal(n) * 0.3 + lowpass(rng.standard_normal(n), 900) * 0.01
        drums += crackle
    left = drums * 0.8 + bass + chords * 0.9 + arp * 0.8 + lead
    right = drums * 0.8 + bass + chords + np.roll(arp, int(0.012 * SR)) * 0.9 + np.roll(lead, int(0.008 * SR)) * 0.95
    out = np.stack([left, right], axis=1)
    fo = int(2 * SR)
    out[-fo:] *= np.linspace(1, 0, fo)[:, None]
    out = np.tanh(out * 1.15) / np.tanh(1.15)
    out /= np.max(np.abs(out)) + 1e-9
    return (out * 0.88).astype(np.float32)


# 20 首：(檔名, 中文名, 風格, BPM, 和弦, 音階, 種子, 分鐘)
J = [62, 64, 67, 69, 72, 74, 76]
M = [60, 62, 63, 65, 67, 70, 72]
TRACKS = [
    ("m01_island", "探險島的早晨", "tropical", 104, ["C", "Am", "F", "G"], [72, 74, 76, 79, 81], 31, 3.2),
    ("m02_rainbow", "彩虹遊樂場", "citypop", 112, ["F", "G", "Em", "Am"], [69, 72, 74, 76, 79, 81], 32, 3.1),
    ("m03_blocks", "積木工坊", "chip", 118, ["C", "G", "Am", "F"], [72, 74, 76, 79, 81, 84], 33, 3.1),
    ("m04_juice", "果汁吧派對", "bossa", 120, ["Fmaj7", "Bbmaj7", "Gm7", "C7"], [65, 67, 69, 72, 74, 77], 34, 3.2),
    ("m05_ocean", "海底散步", "lofi", 82, ["Fmaj7", "Em7", "Dm7", "Cmaj7"], [64, 67, 69, 72, 74, 76], 35, 3.3),
    ("m06_forest", "森林捉迷藏", "tropical", 96, ["G", "Em", "C", "D"], [67, 69, 71, 74, 76, 79], 36, 3.2),
    ("m07_stars", "星星報告", "lounge", 92, ["Cmaj7", "Am7", "Dm7", "G7"], [72, 74, 76, 79, 81], 37, 3.0),
    ("m08_lullaby", "休息一下", "lofi", 68, ["Cmaj7", "Fmaj7", "Em7", "Am7"], [72, 74, 76, 79], 38, 2.5),
]


def write_ogg(name, data):
    os.makedirs(MUSIC, exist_ok=True)
    tmp = os.path.join(MUSIC, name + ".tmp.wav")
    wavfile.write(tmp, SR, data)
    out = os.path.join(MUSIC, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "1", out], check=True)
    os.remove(tmp)
    print("music", name, f"{len(data) / SR / 60:.2f} 分", os.path.getsize(out) // 1024, "KB", flush=True)


def write_wav(name, mono):
    os.makedirs(SFX, exist_ok=True)
    mono = mono / (np.max(np.abs(mono)) + 1e-9) * 0.9
    wavfile.write(os.path.join(SFX, name + ".wav"), SR, (mono * 32767).astype(np.int16))


def tone(f, dur, kind="sine", a=0.005, d=0.1, s=0.5, r=0.1):
    n = int(dur * SR)
    return osc(kind, f, n) * env(n, a, d, s, r)


def seq(notes, kind="pluck", gap=0.1, dur=0.3, total=None):
    total = total or (len(notes) * gap + dur + 0.2)
    s = np.zeros(int(total * SR))
    for i, nn in enumerate(notes):
        add(s, tone(midi(nn), dur, kind, r=dur * 0.6), i * gap * SR)
    return s


def make_sfx():
    s = tone(1500, 0.05, a=0.001, d=0.03, s=0.2, r=0.02)
    add(s, tone(3000, 0.03, a=0.001, d=0.02, s=0.1, r=0.01) * 0.4, 0)
    write_wav("click", s)
    write_wav("select", seq([79, 84], "marimba", 0.06, 0.25))
    write_wav("tick", tone(2200, 0.04, a=0.001, d=0.02, s=0.1, r=0.02) * 0.5)
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    f = 400 + 1400 * t / t[-1]
    write_wav("pop", np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18))
    write_wav("good", seq([72, 76, 79, 84], "marimba", 0.07, 0.4))
    write_wav("bad", lowpass(seq([64, 60], "square", 0.15, 0.25), 1200) * 0.6)
    write_wav("star", seq([84, 88, 91, 96], "steel", 0.06, 0.5))
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    sw = np.concatenate([lowpass(noise[k:k + 256], 300 + 5000 * k / n) for k in range(0, n, 256)])[:n]
    write_wav("whoosh", sw * np.sin(np.pi * t / t[-1]))
    s = np.zeros(int(2.6 * SR))
    for nn, st_, du in [(72, 0, .15), (76, .15, .15), (79, .3, .15), (84, .45, .5), (79, 1.0, .15), (84, 1.15, 1.2)]:
        add(s, tone(midi(nn), du, "marimba" if False else "pluck", s=0.6, r=0.2) * 0.6 + tone(midi(nn + 12), du, "sine") * 0.3, st_ * SR)
    write_wav("fanfare", s)
    s = np.zeros(int(0.6 * SR))
    for i in range(3):
        n2 = int(0.12 * SR)
        t2 = np.arange(n2) / SR
        f2 = 600 + 900 * t2 / t2[-1] + i * 200
        add(s, np.sin(2 * np.pi * np.cumsum(f2) / SR) * np.exp(-t2 * 20) * 0.6, i * 0.13 * SR)
    write_wav("bubble", s)
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    write_wav("leaf", lowpass(highpass(rng.standard_normal(n), 1500), 5000) * np.exp(-t * 9) * np.sin(np.pi * t / t[-1]))
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    whirr = lowpass(rng.standard_normal(n), 900) * 0.5 + np.sin(2 * np.pi * (120 + 30 * np.sin(t * 20)) * t) * 0.4
    write_wav("blend", whirr * np.minimum(1, t * 6) * np.minimum(1, (t[-1] - t) * 6))
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    write_wav("cup", (np.sin(2 * np.pi * 180 * t) + lowpass(rng.standard_normal(n), 800) * 0.6) * np.exp(-t * 18))
    write_wav("drop", seq([88, 81], "sine", 0.07, 0.25))
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    write_wav("chime", (np.sin(2 * np.pi * 880 * t) + 0.5 * np.sin(2 * np.pi * 1320 * t) + 0.3 * np.sin(2 * np.pi * 1760 * t)) * np.exp(-t * 3))
    write_wav("hint", seq([76, 81, 88], "steel", 0.09, 0.4))
    print("sfx ok")


def main():
    only = sys.argv[1:]
    for name, _zh, style, bpm, prog, scale, seed, mins in TRACKS:
        if only and name not in only:
            continue
        if not only and os.path.exists(os.path.join(MUSIC, name + ".ogg")):
            continue
        write_ogg(name, song(style, bpm, prog, scale, seed, mins))
    if not only or "sfx" in only:
        make_sfx()


if __name__ == "__main__":
    main()
