#!/usr/bin/env python3
"""Measure the controls standing in the iPhone Duo's outer-display column.

Give it a screenshot of the CLOSED Duo (`xcrun simctl io <udid> screenshot x.png`,
1398 x 2034 px at 3x) and it finds every ring-shaped or circular object in the
trailing column and prints its centre in points from the trailing edge and its
top from the top edge. The system's own Wi-Fi ring sits 48pt in; every button
your app stands in the column must land on that same axis, and the first one
should start 168pt down (16 under the status cluster). A column hosted inside a
`.sheet` shows up here as every centre 8pt off, both ways.

    python3 measure_column.py inbox.png reader.png --scale 3

With two or more files the script also reports each file's column against the
first — the inbox strip is the reference.

Only Pillow is needed (pip install pillow).
"""
import argparse
import sys

from PIL import Image


def column_blobs(path, scale, column_pt=100, min_pt=20):
    """Find the dark-edged objects in the trailing column.

    Every pixel that differs from the column's own background by more than a
    threshold is 'ink'; ink rows are grouped into bands separated by clean rows,
    and each band's centre x is the mean x of its ink pixels — for a ring or a
    hairline circle that mean is the circle's centre.
    """
    im = Image.open(path).convert("L")
    w, h = im.size
    x0 = w - int(column_pt * scale)
    col = im.crop((x0, 0, w, h))
    px = col.load()
    cw, ch = col.size
    # Background PER COLUMN of pixels: the median down that column. The
    # simulator paints the display's rounded bezel as a grey band along the
    # last ~8pt, and the glass column is tinted; a single background value
    # would read both as ink on every row.
    col_bg = []
    for x in range(cw):
        vals = sorted(px[x, y] for y in range(0, ch, 3))
        col_bg.append(vals[len(vals) // 2])
    thr = 28
    rows = []
    for y in range(ch):
        xs = [x for x in range(cw) if abs(px[x, y] - col_bg[x]) > thr]
        rows.append(xs)
    blobs = []
    y = 0
    while y < ch:
        if rows[y]:
            top = y
            xs_all = []
            gap = 0
            while y < ch and gap < int(2 * scale):
                if rows[y]:
                    xs_all.extend(rows[y]); gap = 0
                else:
                    gap += 1
                y += 1
            bottom = y - gap
            height = bottom - top
            if height >= min_pt * scale and xs_all:
                cx = sum(xs_all) / len(xs_all)
                cy = (top + bottom) / 2
                blobs.append({
                    "top_pt": round(top / scale, 1),
                    "height_pt": round(height / scale, 1),
                    "centre_from_edge_pt": round((cw - cx) / scale, 1),
                    "centre_y_pt": round(cy / scale, 1),
                })
        else:
            y += 1
    return blobs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--scale", type=float, default=3.0, help="points to pixels (3 on the Duo)")
    ap.add_argument("--axis", type=float, default=48.0, help="expected centre from the trailing edge, pt")
    ap.add_argument("--tolerance", type=float, default=1.5)
    args = ap.parse_args()

    ref = None
    bad = 0
    for path in args.files:
        blobs = column_blobs(path, args.scale)
        print(f"\n{path}")
        print(f"  {'top':>7} {'height':>7} {'centre←edge':>12} {'centre y':>9}")
        for b in blobs:
            flag = "" if abs(b["centre_from_edge_pt"] - args.axis) <= args.tolerance else "  <- off the axis"
            if flag: bad += 1
            print(f"  {b['top_pt']:7.1f} {b['height_pt']:7.1f} {b['centre_from_edge_pt']:12.1f} {b['centre_y_pt']:9.1f}{flag}")
        if ref is None:
            ref = blobs
        elif ref and blobs:
            # Compare the first app control (skip the status cluster: anything
            # in the top 160pt is the system's).
            mine = [b for b in blobs if b["top_pt"] >= 160]
            theirs = [b for b in ref if b["top_pt"] >= 160]
            if mine and theirs:
                dy = mine[0]["top_pt"] - theirs[0]["top_pt"]
                dx = mine[0]["centre_from_edge_pt"] - theirs[0]["centre_from_edge_pt"]
                note = "" if abs(dy) <= args.tolerance and abs(dx) <= args.tolerance else "  <- NOT on the reference's pixels"
                print(f"  first control vs {args.files[0]}: dx {dx:+.1f}pt, dy {dy:+.1f}pt{note}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
