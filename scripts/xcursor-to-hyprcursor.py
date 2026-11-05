#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Add a hyprcursor build to an XCursor-only cursor theme, in place.

XCursor themes render at one pixel size on every monitor, so they shrink on
fractionally scaled outputs. Hyprland resizes hyprcursor themes per monitor.
This writes manifest.hl and hyprcursors/ next to the theme's cursors/ dir; the
XCursor files stay for apps that read them.

Usage: xcursor-to-hyprcursor.py THEME_DIR [nearest|bilinear|none]
  nearest (default) keeps pixel-art cursors sharp when upscaled.

Needs python3 (stdlib only) and hyprcursor-util (hyprcursor package).
"""
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

XCURSOR_IMAGE = 0xFFFD0002


def png(w, h, argb):
    rows = []
    for y in range(h):
        row = bytearray(b"\x00")
        for p in argb[y * w:(y + 1) * w]:
            row += bytes(((p >> 16) & 255, (p >> 8) & 255, p & 255, p >> 24))
        rows.append(bytes(row))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
            + chunk(b"IEND", b""))


def xcursor_images(path):
    data = open(path, "rb").read()
    if data[:4] != b"Xcur":
        raise ValueError(f"{path}: not an XCursor file")
    count = struct.unpack("<I", data[12:16])[0]
    images = []
    for i in range(count):
        kind, nominal, pos = struct.unpack("<III", data[16 + i * 12:28 + i * 12])
        if kind != XCURSOR_IMAGE:
            continue
        _, _, _, _, w, h, xhot, yhot, delay = struct.unpack("<9I", data[pos:pos + 36])
        pixels = struct.unpack(f"<{w * h}I", data[pos + 36:pos + 36 + 4 * w * h])
        images.append((nominal, w, h, xhot, yhot, delay, pixels))
    return images


def build_source(theme_dir, src, name, resize):
    cursors = os.path.join(theme_dir, "cursors")
    # Symlinked names are aliases of one shape.
    shapes = {}
    for entry in sorted(os.listdir(cursors)):
        shapes.setdefault(os.path.realpath(os.path.join(cursors, entry)), []).append(entry)

    os.makedirs(os.path.join(src, "hyprcursors"))
    with open(os.path.join(src, "manifest.hl"), "w") as f:
        f.write(f"name = {name}\ndescription = {name} (converted from XCursor)\n"
                "version = 1\ncursors_directory = hyprcursors\n")

    for real, names in shapes.items():
        images = xcursor_images(real)
        if not images:
            continue
        base = os.path.basename(real)
        canon = base if base in names else names[0]
        out = os.path.join(src, "hyprcursors", canon)
        os.makedirs(out)
        _, w, h, xhot, yhot = images[0][:5]
        meta = [f"resize_algorithm = {resize}", f"hotspot_x = {xhot / w:.4f}", f"hotspot_y = {yhot / h:.4f}"]
        aliases = [n for n in names if n != canon]
        if aliases:
            meta.append("define_override = " + ";".join(aliases))
        for i, (nominal, w, h, _, _, delay, pixels) in enumerate(images):
            frame = f"{nominal}_{i}.png"
            with open(os.path.join(out, frame), "wb") as f:
                f.write(png(w, h, pixels))
            meta.append(f"define_size = {nominal}, {frame}" + (f", {delay}" if len(images) > 1 else ""))
        with open(os.path.join(out, "meta.hl"), "w") as f:
            f.write("\n".join(meta) + "\n")


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__.split("\n\n")[2])
    theme_dir = os.path.abspath(sys.argv[1])
    resize = sys.argv[2] if len(sys.argv) == 3 else "nearest"
    name = os.path.basename(theme_dir)
    if not os.path.isdir(os.path.join(theme_dir, "cursors")):
        sys.exit(f"{theme_dir}: no cursors/ dir, not an XCursor theme")
    if shutil.which("hyprcursor-util") is None:
        sys.exit("hyprcursor-util not found (install the hyprcursor package)")

    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "src")
        build_source(theme_dir, src, name, resize)
        subprocess.run(["hyprcursor-util", "--create", src, "-o", tmp], check=True, stdout=subprocess.DEVNULL)
        built = os.path.join(tmp, f"theme_{name}")
        shutil.rmtree(os.path.join(theme_dir, "hyprcursors"), ignore_errors=True)
        shutil.copytree(os.path.join(built, "hyprcursors"), os.path.join(theme_dir, "hyprcursors"))
        shutil.copy2(os.path.join(built, "manifest.hl"), os.path.join(theme_dir, "manifest.hl"))
    print(f"{name}: hyprcursor build written to {theme_dir}")


if __name__ == "__main__":
    main()
