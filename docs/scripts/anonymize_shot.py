#!/usr/bin/env python3
"""Mask content regions on a real SnapKadr screenshot for landing mocks."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PALETTE = [
    (42, 42, 50),
    (60, 60, 70),
    (90, 90, 100),
    (124, 58, 237),
    (56, 189, 248),
    (192, 38, 211),
    (249, 115, 22),
    (34, 197, 94),
]


def _font(size: int) -> ImageFont.ImageFont:
    for p in (
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()


def fill_blocks(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int], seed: int = 0) -> None:
    x0, y0, x1, y1 = box
    # fake titlebar strip kept slightly lighter
    d.rectangle((x0, y0, x1, min(y0 + 22, y1)), fill=(36, 36, 44))
    y = y0 + 34
    i = 0
    while y < y1 - 12:
        h = 8 + (seed + i) % 7
        frac = 0.4 + ((seed + i * 3) % 55) / 100
        w = max(24, int((x1 - x0 - 28) * frac))
        c = PALETTE[(seed + i) % len(PALETTE)] if i % 5 == 0 else (70, 70, 82)
        d.rounded_rectangle((x0 + 14, y, x0 + 14 + w, y + h), 3, fill=c)
        y += h + 10
        i += 1


def fill_stripes(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int], seed: int = 0) -> None:
    x0, y0, x1, y1 = box
    d.rectangle((x0, y0, x1, min(y0 + 22, y1)), fill=(36, 36, 44))
    # avatar row
    for i in range(4):
        cx = x0 + 28 + i * 36
        cy = y0 + 48
        d.ellipse((cx, cy, cx + 24, cy + 24), fill=PALETTE[(seed + i) % len(PALETTE)])
    for y in range(y0 + 90, y1 - 16, 16):
        d.rounded_rectangle((x0 + 16, y, x1 - 16, min(y + 8, y1 - 8)), 3, fill=(55, 55, 65))


def fill_grid(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int], seed: int = 0) -> None:
    x0, y0, x1, y1 = box
    cols, rows = 3, 4
    pad, gap = 14, 8
    cw = max(8, (x1 - x0 - 2 * pad - (cols - 1) * gap) // cols)
    ch = max(8, (y1 - y0 - 2 * pad - (rows - 1) * gap) // rows)
    for r in range(rows):
        for c in range(cols):
            xx = x0 + pad + c * (cw + gap)
            yy = y0 + pad + r * (ch + gap)
            d.rounded_rectangle(
                (xx, yy, xx + cw, yy + ch),
                8,
                fill=PALETTE[(seed + r * cols + c) % len(PALETTE)],
            )


def fill_oval(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    d.ellipse(box, fill=(70, 70, 80))
    x0, y0, x1, y1 = box
    d.ellipse(
        (
            x0 + int((x1 - x0) * 0.25),
            y0 + int((y1 - y0) * 0.2),
            x1 - int((x1 - x0) * 0.25),
            y0 + int((y1 - y0) * 0.55),
        ),
        fill=(110, 110, 120),
    )


def fill_solid(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color=(28, 28, 34)) -> None:
    d.rectangle(box, fill=color)


KIND_FN = {
    "blocks": fill_blocks,
    "stripes": fill_stripes,
    "grid": fill_grid,
    "oval": fill_oval,
    "solid": fill_solid,
}


def anonymize_regions(
    img: Image.Image,
    regions: list[tuple[int, int, int, int, str]],
    seed: int = 0,
) -> Image.Image:
    out = img.convert("RGB").copy()
    d = ImageDraw.Draw(out)
    for i, (x0, y0, x1, y1, kind) in enumerate(regions):
        box = (int(x0), int(y0), int(x1), int(y1))
        if kind != "oval":
            d.rectangle(box, fill=(28, 28, 34))
        fn = KIND_FN.get(kind)
        if fn is None:
            raise ValueError(f"unknown kind: {kind}")
        if kind in ("blocks", "stripes", "grid"):
            fn(d, box, seed + i)  # type: ignore[misc]
        elif kind == "oval":
            fill_oval(d, box)
        else:
            fill_solid(d, box)
    return out


def paint_labels(
    img: Image.Image,
    labels: list[tuple[int, int, str, int]],
) -> Image.Image:
    """labels: (x, y, text, size)"""
    out = img.convert("RGB").copy()
    d = ImageDraw.Draw(out)
    for x, y, text, size in labels:
        d.text((x, y), text, fill=(161, 161, 170), font=_font(size))
    return out


def parse_region(s: str) -> tuple[int, int, int, int, str]:
    # x0,y0,x1,y1,kind
    parts = s.split(",")
    if len(parts) != 5:
        raise argparse.ArgumentTypeError(f"region must be x0,y0,x1,y1,kind got {s!r}")
    return int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]), parts[4]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--region", action="append", default=[], type=parse_region)
    ap.add_argument("--regions-json", type=Path, help='JSON list of [x0,y0,x1,y1,"kind"]')
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--scale", type=float, default=1.0, help="Upscale output for small bases")
    args = ap.parse_args()

    regions = list(args.region)
    if args.regions_json:
        data = json.loads(args.regions_json.read_text())
        for item in data:
            regions.append((item[0], item[1], item[2], item[3], item[4]))
    if not regions:
        raise SystemExit("need --region or --regions-json")

    img = Image.open(args.inp)
    if args.scale and args.scale != 1.0:
        w, h = img.size
        img = img.resize((int(w * args.scale), int(h * args.scale)), Image.Resampling.LANCZOS)
        regions = [
            (
                int(x0 * args.scale),
                int(y0 * args.scale),
                int(x1 * args.scale),
                int(y1 * args.scale),
                kind,
            )
            for x0, y0, x1, y1, kind in regions
        ]

    out = anonymize_regions(img, regions, seed=args.seed)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out, "PNG", optimize=True)
    print(f"wrote {args.out} {out.size}")


if __name__ == "__main__":
    main()
