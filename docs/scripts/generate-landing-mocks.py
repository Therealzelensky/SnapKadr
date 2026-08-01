#!/usr/bin/env python3
"""Generate anonymized CleanShot-style landing mocks for SnapKadr/Кадр."""

from __future__ import annotations

from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "shots"

W, H = 1600, 1000

BG = (10, 10, 12)
ELEV = (20, 20, 24)
PANEL = (26, 26, 32)
PANEL2 = (32, 32, 40)
LINE = (42, 42, 50)
FG = (244, 244, 245)
MUTED = (161, 161, 170)
DIM = (90, 90, 100)
MAGENTA = (192, 38, 211)
VIOLET = (124, 58, 237)
CYAN = (56, 189, 248)
ORANGE = (249, 115, 22)
GREEN = (34, 197, 94)
RED = (239, 68, 68)
YELLOW = (234, 179, 8)
BLUE = (59, 130, 246)
PINK = (236, 72, 153)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    paths = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()


F11 = font(11)
F12 = font(12)
F13 = font(13)
F14 = font(14)
F15 = font(15)
F16 = font(16)
F18 = font(18)
F20 = font(20)
F22 = font(22)
F28 = font(28)


def lerp(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def rrect(d: ImageDraw.ImageDraw, xy, fill, radius=12, outline=None, width=1):
    d.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def grad_rect(d: ImageDraw.ImageDraw, xy, c1, c2, vertical=True):
    x0, y0, x1, y1 = xy
    if vertical:
        for y in range(y0, y1):
            t = (y - y0) / max(1, y1 - y0 - 1)
            d.line([(x0, y), (x1, y)], fill=lerp(c1, c2, t))
    else:
        for x in range(x0, x1):
            t = (x - x0) / max(1, x1 - x0 - 1)
            d.line([(x, y0), (x, y1)], fill=lerp(c1, c2, t))


def traffic(d, x, y):
    for i, c in enumerate([(255, 95, 87), (255, 189, 46), (40, 200, 64)]):
        d.ellipse([x + i * 18, y, x + 10 + i * 18, y + 10], fill=c)


def bars(d, x, y, w, rows, gap=10, h=10, color=None):
    for i in range(rows):
        ww = int(w * (0.55 + (i * 37 % 40) / 100))
        c = color or (DIM if i % 3 else MUTED)
        rrect(d, (x, y + i * (h + gap), x + ww, y + h + i * (h + gap)), c, 4)


def fake_window(d, xy, accent=VIOLET, kind="doc"):
    x0, y0, x1, y1 = xy
    rrect(d, xy, (28, 28, 34), 10, outline=LINE, width=1)
    rrect(d, (x0, y0, x1, y0 + 28), (36, 36, 44), 10)
    d.rectangle([x0, y0 + 18, x1, y0 + 28], fill=(36, 36, 44))
    traffic(d, x0 + 10, y0 + 9)
    if kind == "doc":
        rrect(d, (x0 + 16, y0 + 44, x1 - 16, y0 + 90), (245, 245, 247), 6)
        rrect(d, (x0 + 16, y0 + 100, x0 + 90, y0 + 108), accent, 3)
        bars(d, x0 + 16, y0 + 120, x1 - x0 - 40, 5, gap=12, h=8)
    elif kind == "music":
        cols = [MAGENTA, CYAN, VIOLET, ORANGE]
        for i, c in enumerate(cols):
            d.ellipse([x0 + 20 + i * 36, y0 + 50, x0 + 44 + i * 36, y0 + 74], fill=c)
        bars(d, x0 + 16, y0 + 100, x1 - x0 - 36, 4, gap=14, h=8)
    elif kind == "phone":
        # phone bezel
        rrect(d, xy, (18, 18, 22), 22, outline=(60, 60, 70), width=2)
        inner = (x0 + 10, y0 + 18, x1 - 10, y1 - 18)
        rrect(d, inner, (24, 24, 30), 14)
        colors = [MAGENTA, CYAN, ORANGE, GREEN, VIOLET, BLUE, PINK, YELLOW, RED, CYAN, ORANGE, MAGENTA]
        gw, gh = 3, 4
        pad = 14
        cell_w = (inner[2] - inner[0] - pad * 2 - (gw - 1) * 8) // gw
        cell_h = (inner[3] - inner[1] - pad * 2 - (gh - 1) * 8) // gh
        for r in range(gh):
            for c in range(gw):
                cx = inner[0] + pad + c * (cell_w + 8)
                cy = inner[1] + pad + r * (cell_h + 8)
                rrect(d, (cx, cy, cx + cell_w, cy + cell_h), colors[(r * gw + c) % len(colors)], 8)
    elif kind == "code":
        rrect(d, (x0 + 8, y0 + 36, x0 + 70, y1 - 8), (22, 22, 28), 6)
        for i in range(8):
            rrect(d, (x0 + 16, y0 + 48 + i * 18, x0 + 58, y0 + 56 + i * 18), DIM if i != 2 else MAGENTA, 3)
        bars(d, x0 + 86, y0 + 48, x1 - x0 - 110, 7, gap=14, h=7, color=(70, 70, 82))
        rrect(d, (x0 + 86, y0 + 48 + 2 * 21, x0 + 180, y0 + 56 + 2 * 21), CYAN, 3)


def draw_sidebar(d, x0, y0, x1, y1, active=1):
    rrect(d, (x0, y0, x1, y1), PANEL, 0)
    icons = ["▣", "▤", "◯", "◈"]
    for i, ic in enumerate(icons):
        yy = y0 + 24 + i * 48
        if i == active:
            rrect(d, (x0 + 8, yy - 8, x1 - 8, yy + 28), PANEL2, 8)
            d.text((x0 + 18, yy), ic, fill=MAGENTA, font=F16)
        else:
            d.text((x0 + 18, yy), ic, fill=MUTED, font=F16)


def draw_style_panel(d, x0, y0, x1, y1, aspect="Авто", blur=0.75, highlight=None):
    rrect(d, (x0, y0, x1, y1), PANEL, 0)
    d.text((x0 + 18, y0 + 16), "Стиль", fill=FG, font=F16)
    d.text((x0 + 18, y0 + 48), "Формат", fill=MUTED, font=F12)
    opts = ["Авто", "1:1", "16:9", "9:16"]
    bx = x0 + 18
    for o in opts:
        tw = 52 if o != "Авто" else 48
        active = o == aspect
        fill = MAGENTA if active else PANEL2
        rrect(d, (bx, y0 + 70, bx + tw, y0 + 94), fill, 8)
        d.text((bx + 10, y0 + 74), o, fill=FG if active else MUTED, font=F12)
        bx += tw + 6

    d.text((x0 + 18, y0 + 118), "Фон", fill=MUTED, font=F12)
    swatches = [VIOLET, BLUE, ORANGE, GREEN, MAGENTA, (40, 40, 48)]
    for i, c in enumerate(swatches):
        col, row = i % 3, i // 3
        sx = x0 + 18 + col * 54
        sy = y0 + 142 + row * 40
        rrect(d, (sx, sy, sx + 44, sy + 30), c, 6)
        if highlight == "bg" and i == 0:
            d.rounded_rectangle((sx - 2, sy - 2, sx + 46, sy + 32), radius=8, outline=FG, width=2)

    labels = [("Размытие", blur), ("Отступ", 0.35), ("Скругление", 0.45)]
    yy = y0 + 240
    for name, val in labels:
        hi = highlight == name
        d.text((x0 + 18, yy), name, fill=FG if hi else MUTED, font=F12)
        rrect(d, (x0 + 18, yy + 22, x1 - 18, yy + 30), LINE, 4)
        fill = MAGENTA if hi or name == "Размытие" else (90, 90, 100)
        rrect(d, (x0 + 18, yy + 22, x0 + 18 + int((x1 - x0 - 36) * val), yy + 30), fill, 4)
        yy += 52


def draw_timeline(d, x0, y0, x1, y1, highlight=None, playhead=0.42):
    rrect(d, (x0, y0, x1, y1), PANEL, 0)
    # transport
    d.ellipse([x0 + 16, y0 + 14, x0 + 40, y0 + 38], fill=MAGENTA)
    d.polygon([(x0 + 24, y0 + 20), (x0 + 24, y0 + 32), (x0 + 34, y0 + 26)], fill=FG)
    d.text((x0 + 52, y0 + 18), "00:18.40 / 00:41", fill=MUTED, font=F13)

    tracks = [
        ("Окно А", ORANGE, 0.08, 0.78, "window-a"),
        ("Окно В", CYAN, 0.18, 0.62, "window-b"),
        ("Телефон", PINK, 0.28, 0.72, "phone"),
        ("Зум", VIOLET, 0.35, 0.55, "zoom"),
        ("Аудио", GREEN, 0.05, 0.92, "audio"),
    ]
    label_w = 78
    track_x0 = x0 + label_w + 12
    track_x1 = x1 - 16
    tw = track_x1 - track_x0
    ty = y0 + 52
    for name, color, a, b, key in tracks:
        hi = highlight == key
        d.text((x0 + 14, ty + 2), name, fill=FG if hi else MUTED, font=F12)
        rrect(d, (track_x0, ty, track_x1, ty + 18), (18, 18, 22), 5)
        cx0 = track_x0 + int(tw * a)
        cx1 = track_x0 + int(tw * b)
        fill = color if not hi else lerp(color, FG, 0.15)
        rrect(d, (cx0, ty, cx1, ty + 18), fill, 5)
        if key == "zoom":
            d.text((cx0 + 8, ty + 1), "×2", fill=FG, font=F11)
        if hi:
            d.rounded_rectangle((track_x0 - 2, ty - 2, track_x1 + 2, ty + 20), radius=6, outline=MAGENTA, width=1)
        ty += 28

    # playhead
    px = track_x0 + int(tw * playhead)
    d.line([(px, y0 + 48), (px, y1 - 10)], fill=MAGENTA, width=2)


def draw_editor_chrome(
    d,
    title="Кадр Demo",
    mode="Кадр",
    aspect="Авто",
    timeline_hi=None,
    style_hi=None,
    sidebar_active=1,
):
    # window shell
    rrect(d, (40, 40, W - 40, H - 40), ELEV, 16)
    # titlebar
    rrect(d, (40, 40, W - 40, 88), PANEL, 16)
    d.rectangle([40, 72, W - 40, 88], fill=PANEL)
    traffic(d, 58, 58)
    tw = d.textlength(title, font=F15)
    d.text(((W - tw) / 2, 56), title, fill=MUTED, font=F15)
    rrect(d, (W - 160, 52, W - 60, 78), MAGENTA, 10)
    d.text((W - 140, 56), "Экспорт", fill=FG, font=F14)

    # left sidebar
    draw_sidebar(d, 40, 88, 96, H - 40 - 210, active=sidebar_active)

    # style panel
    draw_style_panel(d, W - 40 - 220, 88, W - 40, H - 40 - 210, aspect=aspect, highlight=style_hi)

    # canvas area
    canvas = (96, 88, W - 40 - 220, H - 40 - 210)
    rrect(d, canvas, BG, 0)

    # mode pills
    cx0, cy0, cx1, cy1 = canvas
    pills = ["Авто", "Кадр", "Маска"]
    px = cx0 + 24
    for p in pills:
        active = p == mode
        tw = 54
        rrect(d, (px, cy0 + 16, px + tw, cy0 + 40), MAGENTA if active else PANEL2, 12)
        d.text((px + 12, cy0 + 20), p, fill=FG if active else MUTED, font=F12)
        px += tw + 8

    # timeline
    draw_timeline(d, 40, H - 40 - 210, W - 40, H - 40, highlight=timeline_hi)
    return canvas


def scene_multi_window(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d)
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 40, cy0 + 70, cx0 + 420, cy1 - 40), VIOLET, "doc")
    fake_window(d, (cx0 + 360, cy0 + 100, cx0 + 700, cy1 - 120), CYAN, "music")
    fake_window(d, (cx0 + 620, cy0 + 160, cx0 + 820, cy1 - 40), MAGENTA, "phone")
    img.save(path, "PNG", optimize=True)


def scene_layout_before_record(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    # desktop wallpaper gradient
    grad_rect(d, (0, 0, W, H), (30, 20, 50), (10, 40, 70), True)
    # anonymized desktop windows behind
    fake_window(d, (180, 160, 620, 520), VIOLET, "doc")
    fake_window(d, (700, 200, 1180, 560), ORANGE, "code")
    # purple frame card
    rrect(d, (220, 120, W - 220, H - 120), None, 28, outline=VIOLET, width=3)
    # top capture bar
    bar1 = (340, 280, 1260, 340)
    rrect(d, bar1, (28, 28, 34, ), 18)
    # frosted dark
    rrect(d, bar1, (32, 32, 40), 18)
    d.text((370, 300), "Рамки ▾", fill=FG, font=F14)
    rrect(d, (480, 292, 700, 328), PANEL2, 10)
    d.text((498, 300), "Окно А  ×", fill=MUTED, font=F13)
    rrect(d, (712, 292, 900, 328), PANEL2, 10)
    d.text((730, 300), "Окно В  ×", fill=MUTED, font=F13)
    rrect(d, (920, 292, 980, 328), MAGENTA, 10)
    d.text((940, 298), "+", fill=FG, font=F20)
    d.text((1020, 300), "🗑", fill=MUTED, font=F14)
    # bottom bar
    bar2 = (420, 620, 1180, 690)
    rrect(d, bar2, (32, 32, 40), 20)
    d.text((450, 642), "✕", fill=MUTED, font=F18)
    rrect(d, (520, 634, 680, 676), (50, 20, 28), 14)
    d.ellipse([540, 646, 556, 662], fill=RED)
    d.text((570, 644), "Старт", fill=FG, font=F16)
    d.text((720, 644), "📷  ✕", fill=DIM, font=F16)
    d.text((820, 644), "🎙  ✕", fill=DIM, font=F16)
    d.text((920, 644), "🖥  ♪", fill=MUTED, font=F16)
    d.text((1080, 644), "⚙", fill=MUTED, font=F18)
    img.save(path, "PNG", optimize=True)


def scene_phone(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, timeline_hi="phone")
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 60, cy0 + 80, cx0 + 520, cy1 - 50), VIOLET, "doc")
    fake_window(d, (cx0 + 560, cy0 + 90, cx0 + 820, cy1 - 40), MAGENTA, "phone")
    # highlight ring on phone
    d.rounded_rectangle((cx0 + 552, cy0 + 82, cx0 + 828, cy1 - 32), radius=24, outline=MAGENTA, width=3)
    img.save(path, "PNG", optimize=True)


def scene_camera(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d)
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 50, cy0 + 70, cx0 + 780, cy1 - 40), CYAN, "code")
    # camera pip circle
    pip = (cx0 + 640, cy1 - 220, cx0 + 820, cy1 - 40)
    d.ellipse(pip, fill=(40, 40, 48), outline=MAGENTA, width=4)
    # anonymized face blobs
    d.ellipse([pip[0] + 40, pip[1] + 35, pip[2] - 40, pip[3] - 50], fill=(70, 70, 80))
    d.ellipse([pip[0] + 55, pip[1] + 50, pip[2] - 55, pip[1] + 95], fill=(110, 110, 120))
    d.text((pip[0] + 48, pip[3] - 36), "Камера", fill=MUTED, font=F12)
    img.save(path, "PNG", optimize=True)


def scene_tracks(path: Path, highlight: str, mode="Кадр"):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, timeline_hi=highlight, mode=mode)
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 50, cy0 + 70, cx0 + 420, cy1 - 50), VIOLET, "doc")
    fake_window(d, (cx0 + 380, cy0 + 110, cx0 + 700, cy1 - 90), CYAN, "music")
    fake_window(d, (cx0 + 640, cy0 + 150, cx0 + 840, cy1 - 40), PINK, "phone")
    img.save(path, "PNG", optimize=True)


def scene_autozoom(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, timeline_hi="zoom")
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 80, cy0 + 80, cx0 + 760, cy1 - 50), VIOLET, "doc")
    # zoom crop rect
    d.rounded_rectangle((cx0 + 220, cy0 + 160, cx0 + 520, cy0 + 420), radius=8, outline=MAGENTA, width=3)
    d.text((cx0 + 236, cy0 + 170), "×2 авто", fill=MAGENTA, font=F14)
    img.save(path, "PNG", optimize=True)


def scene_cursor(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d)
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 80, cy0 + 80, cx0 + 780, cy1 - 50), CYAN, "doc")
    # cursor with trail glow
    cx, cy = cx0 + 480, cy0 + 320
    d.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=(192, 38, 211, ))
    # draw solid circle then arrow
    d.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=MAGENTA)
    d.polygon([(cx - 2, cy - 10), (cx - 2, cy + 14), (cx + 14, cy + 6)], fill=FG)
    rrect(d, (cx + 24, cy - 8, cx + 110, cy + 14), PANEL2, 8)
    d.text((cx + 32, cy - 5), "клик", fill=FG, font=F12)
    img.save(path, "PNG", optimize=True)


def scene_manual_zoom(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, timeline_hi="zoom")
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 60, cy0 + 70, cx0 + 800, cy1 - 40), ORANGE, "code")
    # handles
    box = (cx0 + 200, cy0 + 150, cx0 + 560, cy0 + 430)
    d.rounded_rectangle(box, radius=6, outline=CYAN, width=2)
    for hx, hy in [(box[0], box[1]), (box[2], box[1]), (box[0], box[3]), (box[2], box[3])]:
        d.rectangle([hx - 5, hy - 5, hx + 5, hy + 5], fill=CYAN)
    d.text((box[0] + 12, box[1] + 10), "Зум вручную", fill=CYAN, font=F13)
    img.save(path, "PNG", optimize=True)


def scene_masks(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, mode="Маска", style_hi="Размытие")
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 70, cy0 + 80, cx0 + 780, cy1 - 50), VIOLET, "doc")
    # blur region
    rrect(d, (cx0 + 140, cy0 + 200, cx0 + 420, cy0 + 320), (60, 60, 70), 10)
    d.rounded_rectangle((cx0 + 140, cy0 + 200, cx0 + 420, cy0 + 320), radius=10, outline=MAGENTA, width=2)
    d.text((cx0 + 160, cy0 + 250), "размытие", fill=FG, font=F14)
    img.save(path, "PNG", optimize=True)


def scene_bg_card(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, style_hi="bg", aspect="16:9")
    cx0, cy0, cx1, cy1 = canvas
    # colorful padded background
    grad_rect(d, (cx0 + 30, cy0 + 60, cx1 - 30, cy1 - 30), VIOLET, MAGENTA, False)
    fake_window(d, (cx0 + 160, cy0 + 130, cx1 - 160, cy1 - 100), FG, "doc")
    img.save(path, "PNG", optimize=True)


def scene_device_frames(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, aspect="Авто")
    cx0, cy0, cx1, cy1 = canvas
    # macbook-like frame
    rrect(d, (cx0 + 40, cy0 + 100, cx0 + 520, cy1 - 80), (18, 18, 22), 16, outline=(70, 70, 80), width=3)
    fake_window(d, (cx0 + 60, cy0 + 120, cx0 + 500, cy1 - 100), CYAN, "doc")
    # phone frame
    fake_window(d, (cx0 + 560, cy0 + 90, cx0 + 820, cy1 - 50), MAGENTA, "phone")
    d.text((cx0 + 60, cy0 + 70), "Рамки устройств", fill=MUTED, font=F13)
    img.save(path, "PNG", optimize=True)


def scene_keys(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d)
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 60, cy0 + 70, cx0 + 800, cy1 - 40), VIOLET, "code")
    keys = [("⌘",), ("⇧",), ("S",)]
    kx = cx0 + 280
    ky = cy1 - 120
    for (lab,) in keys:
        rrect(d, (kx, ky, kx + 48, ky + 48), PANEL2, 10, outline=LINE, width=1)
        d.text((kx + 14, ky + 12), lab, fill=FG, font=F18)
        kx += 60
    rrect(d, (kx + 10, ky + 8, kx + 160, ky + 40), MAGENTA, 10)
    d.text((kx + 28, ky + 14), "снимок", fill=FG, font=F14)
    img.save(path, "PNG", optimize=True)


def scene_subtitles(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, timeline_hi="audio")
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 60, cy0 + 70, cx0 + 800, cy1 - 40), CYAN, "doc")
    # subtitle bar
    rrect(d, (cx0 + 180, cy1 - 130, cx0 + 680, cy1 - 70), (0, 0, 0), 10)
    d.text((cx0 + 220, cy1 - 112), "Добавьте окно и нажмите Старт", fill=FG, font=F16)
    img.save(path, "PNG", optimize=True)


def scene_aspect(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d, aspect="9:16")
    cx0, cy0, cx1, cy1 = canvas
    # tall phone canvas
    mid = (cx0 + cx1) // 2
    fake_window(d, (mid - 140, cy0 + 60, mid + 140, cy1 - 40), MAGENTA, "phone")
    d.text((mid - 120, cy0 + 70), "9:16", fill=MUTED, font=F14)
    img.save(path, "PNG", optimize=True)


def scene_export(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    canvas = draw_editor_chrome(d)
    cx0, cy0, cx1, cy1 = canvas
    fake_window(d, (cx0 + 80, cy0 + 80, cx0 + 760, cy1 - 50), VIOLET, "doc")
    # export sheet
    sheet = (cx0 + 200, cy0 + 140, cx0 + 640, cy0 + 420)
    rrect(d, sheet, PANEL, 16, outline=LINE, width=1)
    d.text((sheet[0] + 28, sheet[1] + 24), "Экспорт ролика", fill=FG, font=F18)
    d.text((sheet[0] + 28, sheet[1] + 70), "Формат", fill=MUTED, font=F13)
    rrect(d, (sheet[0] + 28, sheet[1] + 96, sheet[0] + 160, sheet[1] + 124), MAGENTA, 8)
    d.text((sheet[0] + 48, sheet[1] + 102), "MP4 1080p", fill=FG, font=F13)
    rrect(d, (sheet[0] + 28, sheet[1] + 160, sheet[0] + 400, sheet[1] + 176), LINE, 4)
    rrect(d, (sheet[0] + 28, sheet[1] + 160, sheet[0] + 300, sheet[1] + 176), GREEN, 4)
    d.text((sheet[0] + 28, sheet[1] + 190), "Почти готово…", fill=MUTED, font=F13)
    rrect(d, (sheet[0] + 28, sheet[1] + 240, sheet[0] + 200, sheet[1] + 280), MAGENTA, 12)
    d.text((sheet[0] + 70, sheet[1] + 250), "Сохранить", fill=FG, font=F15)
    img.save(path, "PNG", optimize=True)


def prefs_shell(d, active="Щёлк", title="Настройки — Щёлк.Кадр"):
    rrect(d, (200, 80, W - 200, H - 80), ELEV, 18)
    rrect(d, (200, 80, W - 200, 128), PANEL, 18)
    d.rectangle([200, 110, W - 200, 128], fill=PANEL)
    traffic(d, 220, 98)
    tw = d.textlength(title, font=F15)
    d.text(((W - tw) / 2, 96), title, fill=MUTED, font=F15)
    # sidebar
    side = (200, 128, 420, H - 80)
    rrect(d, side, PANEL, 0)
    items = ["Общие", "Кадр", "Щёлк", "Горячие клавиши", "Уведомления", "Версия"]
    yy = 160
    for name in items:
        hi = name == active
        if hi:
            rrect(d, (210, yy - 8, 410, yy + 28), PANEL2, 8)
            d.rectangle([200, yy - 4, 205, yy + 24], fill=MAGENTA)
        d.text((240, yy), name, fill=FG if hi else MUTED, font=F14)
        yy += 44
    return (420, 128, W - 200, H - 80)


def scene_snap_prefs(path: Path, focus="capture"):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    body = prefs_shell(d, "Щёлк")
    x0, y0, x1, y1 = body
    d.text((x0 + 32, y0 + 24), "Щёлк", fill=FG, font=F20)
    rows = [
        ("Папка сохранений", "Документы/Щёлк"),
        ("Формат", "PNG"),
        ("После снимка", "Открыть редактор"),
        ("Длинная страница", "Вкл" if focus == "long" else "Выкл"),
        ("Поверх всех окон", "Вкл" if focus == "overlay" else "Выкл"),
    ]
    yy = y0 + 70
    for label, val in rows:
        hi = (focus == "long" and "Длинная" in label) or (focus == "overlay" and "Поверх" in label) or (
            focus == "capture" and label == "После снимка"
        )
        rrect(d, (x0 + 24, yy, x1 - 24, yy + 52), PANEL2 if hi else (22, 22, 28), 10)
        d.text((x0 + 40, yy + 16), label, fill=FG, font=F14)
        d.text((x1 - 220, yy + 16), val, fill=MAGENTA if hi else MUTED, font=F14)
        yy += 64
    img.save(path, "PNG", optimize=True)


def scene_snap_annotate(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    # annotate workspace
    rrect(d, (120, 80, W - 120, H - 80), ELEV, 18)
    traffic(d, 140, 98)
    d.text((180, 96), "Пометки", fill=MUTED, font=F15)
    # tool rail
    tools = ["▸", "○", "□", "T", "✦", "▒"]
    tx = 160
    for i, t in enumerate(tools):
        fill = MAGENTA if i == 5 else PANEL2
        rrect(d, (tx, 140, tx + 44, 184), fill, 10)
        d.text((tx + 14, 150), t, fill=FG, font=F16)
        tx += 56
    # canvas with anonymized content + annotations
    rrect(d, (160, 210, W - 160, H - 140), (30, 30, 36), 12)
    fake_window(d, (220, 250, 900, 700), VIOLET, "doc")
    # blur rect
    rrect(d, (980, 280, 1320, 400), (55, 55, 65), 8)
    d.text((1040, 330), "пиксели", fill=MUTED, font=F14)
    # arrow
    d.line([(700, 420), (980, 320)], fill=ORANGE, width=4)
    d.polygon([(980, 320), (960, 310), (968, 336)], fill=ORANGE)
    # redacted bar
    rrect(d, (260, 520, 620, 560), RED, 6)
    img.save(path, "PNG", optimize=True)


def scene_snap_long(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    rrect(d, (400, 40, 1200, H - 40), ELEV, 20)
    traffic(d, 420, 58)
    d.text((520, 56), "Длинная страница", fill=MUTED, font=F14)
    # long scroll content
    y = 100
    for i in range(12):
        rrect(d, (440, y, 1160, y + 56), PANEL2 if i % 2 == 0 else (24, 24, 30), 8)
        bars(d, 460, y + 16, 600, 2, gap=10, h=8)
        if i == 3:
            rrect(d, (440, y, 1160, y + 56), None, 8, outline=MAGENTA, width=2)
        y += 68
    # scroll indicator
    rrect(d, (1170, 120, 1184, 700), LINE, 4)
    rrect(d, (1170, 200, 1184, 320), MAGENTA, 4)
    img.save(path, "PNG", optimize=True)


def scene_snap_ocr(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    rrect(d, (160, 100, W - 160, H - 100), ELEV, 16)
    traffic(d, 180, 118)
    d.text((240, 116), "Текст и QR", fill=MUTED, font=F15)
    fake_window(d, (220, 180, 980, 780), CYAN, "doc")
    # OCR boxes
    boxes = [(260, 280, 520, 320), (260, 360, 700, 400), (260, 440, 480, 480)]
    for b in boxes:
        d.rounded_rectangle(b, radius=4, outline=GREEN, width=2)
    # QR block
    rrect(d, (1040, 280, 1320, 560), PANEL2, 12)
    for r in range(6):
        for c in range(6):
            if (r + c) % 2 == 0 or (r < 2 and c < 2):
                rrect(
                    d,
                    (1060 + c * 40, 300 + r * 40, 1090 + c * 40, 330 + r * 40),
                    FG if (r * c) % 3 == 0 else DIM,
                    2,
                )
    d.text((1080, 600), "QR распознан", fill=GREEN, font=F14)
    rrect(d, (1040, 640, 1320, 690), MAGENTA, 10)
    d.text((1088, 654), "Скопировать текст", fill=FG, font=F14)
    img.save(path, "PNG", optimize=True)


def scene_snap_bg(path: Path):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    grad_rect(d, (0, 0, W, H), VIOLET, CYAN, False)
    # floating window card
    fake_window(d, (420, 200, 1180, 760), FG, "doc")
    rrect(d, (520, 820, 1080, 870), PANEL, 14)
    d.text((620, 834), "Фон · отступ · скругление", fill=MUTED, font=F14)
    img.save(path, "PNG", optimize=True)


def scene_suite(path: Path, active="Общие"):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    body = prefs_shell(d, active)
    x0, y0, x1, y1 = body
    if active == "Общие":
        d.text((x0 + 32, y0 + 24), "Общие", fill=FG, font=F20)
        cards = [("Щёлк", "Снимки и пометки", ORANGE), ("Кадр", "Запись и монтаж", MAGENTA)]
        xx = x0 + 32
        for title, sub, color in cards:
            rrect(d, (xx, y0 + 80, xx + 280, y0 + 220), PANEL2, 14)
            rrect(d, (xx + 20, y0 + 100, xx + 60, y0 + 140), color, 10)
            d.text((xx + 80, y0 + 108), title, fill=FG, font=F18)
            d.text((xx + 80, y0 + 140), sub, fill=MUTED, font=F13)
            xx += 310
        toggles = [("Запускать вместе", True), ("Иконка в меню", True), ("Звук при снимке", False)]
        yy = y0 + 260
        for lab, on in toggles:
            d.text((x0 + 40, yy), lab, fill=FG, font=F14)
            rrect(d, (x1 - 120, yy, x1 - 48, yy + 28), ORANGE if on else LINE, 14)
            knob = x1 - 76 if on else x1 - 112
            d.ellipse([knob, yy + 4, knob + 20, yy + 24], fill=FG)
            yy += 56
    elif active == "Версия":
        d.text((x0 + 32, y0 + 40), "Щёлк.Кадр", fill=FG, font=F28)
        d.text((x0 + 32, y0 + 90), "Бета 0.1.0", fill=MUTED, font=F16)
        rrect(d, (x0 + 32, y0 + 150, x0 + 280, y0 + 200), MAGENTA, 12)
        d.text((x0 + 60, y0 + 164), "Проверить обновления", fill=FG, font=F14)
        d.text((x0 + 32, y0 + 240), "Обновления устанавливаются сами", fill=MUTED, font=F14)
        rrect(d, (x0 + 32, y0 + 290, x1 - 32, y0 + 360), PANEL2, 12)
        d.text((x0 + 52, y0 + 316), "Актуально · последняя проверка только что", fill=GREEN, font=F14)
    img.save(path, "PNG", optimize=True)


SCENES: list[tuple[str, Callable[[Path], None]]] = [
    ("02-multi-window-mock.png", scene_multi_window),
    ("03-layout-before-record-mock.png", scene_layout_before_record),
    ("04-phone-in-frame-mock.png", scene_phone),
    ("05-camera-pip-mock.png", scene_camera),
    ("06-tracks-separate-mock.png", lambda p: scene_tracks(p, "window-a")),
    ("07-audio-tracks-mock.png", lambda p: scene_tracks(p, "audio")),
    ("08-timeline-assembly-mock.png", lambda p: scene_tracks(p, None)),
    ("09-autozoom-mock.png", scene_autozoom),
    ("10-cursor-mock.png", scene_cursor),
    ("11-manual-zoom-mock.png", scene_manual_zoom),
    ("12-masks-mock.png", scene_masks),
    ("13-bg-card-mock.png", scene_bg_card),
    ("14-device-frames-mock.png", scene_device_frames),
    ("15-keys-overlay-mock.png", scene_keys),
    ("16-subtitles-mock.png", scene_subtitles),
    ("17-aspect-mock.png", scene_aspect),
    ("18-export-mock.png", scene_export),
    ("19-snap-capture-mock.png", lambda p: scene_snap_prefs(p, "capture")),
    ("20-snap-annotate-mock.png", scene_snap_annotate),
    ("21-snap-long-mock.png", scene_snap_long),
    ("22-snap-ocr-mock.png", scene_snap_ocr),
    ("23-snap-overlay-mock.png", lambda p: scene_snap_prefs(p, "overlay")),
    ("24-snap-bg-mock.png", scene_snap_bg),
    ("25-suite-together-mock.png", lambda p: scene_suite(p, "Общие")),
    ("26-suite-prefs-mock.png", lambda p: scene_suite(p, "Общие")),
    ("27-updates-mock.png", lambda p: scene_suite(p, "Версия")),
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in SCENES:
        path = OUT / name
        fn(path)
        print(f"ok {name} ({path.stat().st_size // 1024}KB)")


if __name__ == "__main__":
    main()
