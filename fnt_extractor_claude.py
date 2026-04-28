#!/usr/bin/env python3
"""
FNT3 font image converter: converts .fnt font files to PNG glyph sheets.

Usage:
    python fnt_to_png.py <input.fnt> [output.png]

The .fnt format:
  - Little Endian
  - Grayscale 4bpp (high nibble = left pixel, low nibble = right pixel)
  - LZSS-compressed glyph data
  - Shift-JIS encoded characters
"""

import sys
import struct
import math
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


# ---------------------------------------------------------------------------
# Shift-JIS glyph index ranges
# ---------------------------------------------------------------------------
GLYPH_RANGES = [
    (0x0020, 0x0060, "ASCII printable (half-width)"),          # 0x41 = 65, but spec says 64
    (0x8100, 0x9FFF, "Shift-JIS block 1 (kanji/kana)"),
    (0xE000, 0xEAFF, "Shift-JIS block 2 (kanji continued)"),
    (0xF000, 0xF0FF, "Shift-JIS block 3 (private use / special)"),
]

def build_code_list():
    """Return ordered list of all Shift-JIS codes covered by the font."""
    codes = []
    for start, end, _ in GLYPH_RANGES:
        for code in range(start, end + 1):
            codes.append(code)
    return codes


def print_glyph_summary(code_list):
    print("\n=== Shift-JIS glyph range summary ===")
    for start, end, label in GLYPH_RANGES:
        count = end - start + 1
        print(f"  0x{start:04X}–0x{end:04X}  {count:5d} glyphs  [{label}]")
    print(f"  {'TOTAL':20s}  {len(code_list):5d} glyphs")
    print()


# ---------------------------------------------------------------------------
# LZSS decompressor
# ---------------------------------------------------------------------------
def lzss_decompress(data: bytes, expected_size: int) -> bytes:
    """
    LZSS decompression as specified:
      - control byte: LSB processed first (bit 0, then 1, … 7)
      - 0-bit  → literal byte
      - 1-bit  → 2-byte back-reference
          byte1 = a (a7..a0), byte2 = b (b7..b0)
          distance  = ((a & 0xC0) << 2) | b   → 10 bits:  a[7:6] as high 2, b as low 8
          match_len = (a & 0x3F) + 3           → 6-bit count field + 3
          copy byte-by-byte from out[cur - distance], advancing src each step
          (handles overlapping / self-referential runs correctly)
      - stop when expected_size bytes have been written
    """
    out = bytearray()
    pos = 0
    n = len(data)

    while len(out) < expected_size:
        # Need at least one byte for the control word
        if pos >= n:
            break
        ctrl = data[pos]
        pos += 1

        for bit_idx in range(8):
            if len(out) >= expected_size:
                break

            if (ctrl >> bit_idx) & 1 == 0:
                # --- Literal ---
                if pos >= n:
                    break
                out.append(data[pos])
                pos += 1
            else:
                # --- Back-reference: need exactly 2 bytes ---
                if pos + 1 >= n:   # need pos and pos+1 both valid → pos+1 < n
                    # If we're here and still short, the stream is truncated;
                    # pad with zeros so expand_4bpp never crashes.
                    break
                a = data[pos]
                b = data[pos + 1]
                pos += 2

                # distance: top-2 bits from a, all 8 bits from b  →  10-bit value
                distance  = ((a & 0xC0) << 2) | b
                match_len = (a & 0x3F) + 3

                src = len(out) - distance
                for _ in range(match_len):
                    if len(out) >= expected_size:
                        break
                    # Bytes before the start of the buffer are treated as 0x00
                    out.append(out[src] if src >= 0 else 0)
                    src += 1

    # Guarantee the caller always gets exactly expected_size bytes
    if len(out) < expected_size:
        out.extend(b'\x00' * (expected_size - len(out)))

    return bytes(out)


# ---------------------------------------------------------------------------
# 4bpp → 8bpp row expansion
# ---------------------------------------------------------------------------
def expand_4bpp(data: bytes, width: int, height: int) -> list[list[int]]:
    """Convert packed 4bpp data to a 2D list of 8-bit grayscale values."""
    pitch = (width + 1) >> 1
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            byte = data[y * pitch + (x >> 1)]
            if x & 1 == 0:
                nibble = (byte >> 4) & 0x0F   # high nibble = left pixel
            else:
                nibble = byte & 0x0F           # low nibble = right pixel
            row.append(nibble * 17)            # scale 0-15 → 0-255
        rows.append(row)
    return rows


# ---------------------------------------------------------------------------
# FNT3 parser
# ---------------------------------------------------------------------------
def parse_fnt(path: str):
    with open(path, "rb") as f:
        raw = f.read()

    # Main header
    magic = raw[0:4]
    if magic != b"FNT3":
        raise ValueError(f"Bad magic: {magic!r}, expected b'FNT3'")
    file_size = struct.unpack_from("<I", raw, 4)[0]
    print(f"File: {path}")
    print(f"Magic: {magic.decode()}, reported size: {file_size} bytes, actual: {len(raw)} bytes")

    code_list = build_code_list()
    print_glyph_summary(code_list)

    total_glyphs = len(code_list)
    offset_table_start = 0x10
    # Each glyph link is a 32-bit offset
    glyphs = {}

    for idx, code in enumerate(code_list):
        link_offset = offset_table_start + idx * 4
        glyph_offset = struct.unpack_from("<I", raw, link_offset)[0]
        if glyph_offset == 0:
            continue  # no glyph for this code

        # Glyph header
        char_code  = struct.unpack_from("<H", raw, glyph_offset + 0)[0]
        width      = raw[glyph_offset + 2]
        height     = raw[glyph_offset + 3]
        offset_x   = raw[glyph_offset + 4]
        offset_y   = raw[glyph_offset + 5]
        comp_size  = struct.unpack_from("<H", raw, glyph_offset + 6)[0]

        if width == 0 or height == 0:
            continue

        comp_data = raw[glyph_offset + 8 : glyph_offset + 8 + comp_size]
        pitch = (width + 1) >> 1
        expected_size = pitch * height

        try:
            pixel_data = lzss_decompress(comp_data, expected_size)
        except Exception as e:
            print(f"  Warning: LZSS decompression failed for code 0x{code:04X}: {e}")
            continue

        if len(pixel_data) < expected_size:
            print(f"  Warning: short decompress for 0x{code:04X}: "
                  f"got {len(pixel_data)} bytes, expected {expected_size} — skipping")
            continue

        try:
            rows = expand_4bpp(pixel_data, width, height)
        except Exception as e:
            print(f"  Warning: 4bpp expand failed for code 0x{code:04X}: {e}")
            continue

        glyphs[code] = {
            "char_code": char_code,
            "width": width,
            "height": height,
            "offset_x": offset_x,
            "offset_y": offset_y,
            "rows": rows,
        }

    print(f"Successfully decoded {len(glyphs)} / {total_glyphs} glyphs.")
    return glyphs, code_list


# ---------------------------------------------------------------------------
# PNG sheet renderer
# ---------------------------------------------------------------------------
CELL_PAD = 2          # pixels of padding around each cell
COLS = 64             # glyphs per row in output sheet


def render_sheet(glyphs: dict, code_list: list, out_path: str):
    if not glyphs:
        print("No glyphs to render.")
        return

    # Determine cell size from the maximum glyph dimensions
    max_w = max(g["width"]  for g in glyphs.values())
    max_h = max(g["height"] for g in glyphs.values())
    cell_w = max_w + CELL_PAD * 2
    cell_h = max_h + CELL_PAD * 2

    # Only render codes that have a glyph
    active = [c for c in code_list if c in glyphs]
    rows_count = math.ceil(len(active) / COLS)

    img_w = cell_w * COLS
    img_h = cell_h * rows_count

    print(f"Rendering {len(active)} glyphs onto {img_w}×{img_h} px sheet ({COLS} columns × {rows_count} rows) …")

    img = Image.new("L", (img_w, img_h), color=0)   # black background

    for i, code in enumerate(active):
        g = glyphs[code]
        col = i % COLS
        row = i // COLS
        base_x = col * cell_w + CELL_PAD
        base_y = row * cell_h + CELL_PAD

        for y, pixel_row in enumerate(g["rows"]):
            for x, val in enumerate(pixel_row):
                img.putpixel((base_x + x, base_y + y), val)

    img.save(out_path, "PNG")
    print(f"Saved: {out_path}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Convert FNT3 font file to PNG glyph sheet.")
    parser.add_argument("input",  help="Input .fnt file")
    parser.add_argument("output", nargs="?", help="Output .png file (default: <input>.png)")
    args = parser.parse_args()

    in_path  = args.input
    out_path = args.output or Path(in_path).with_suffix(".png").name

    glyphs, code_list = parse_fnt(in_path)
    render_sheet(glyphs, code_list, out_path)


if __name__ == "__main__":
    main()
