import sys
import struct
from PIL import Image


RANGES = [
    ("ASCII", 0x20, 0x60),
    ("Shift-JIS", 0x8100, 0x9FFF),
    ("Shift-JIS", 0xE000, 0xEAFF),
    ("Shift-JIS", 0xF000, 0xF0FF),
]


def count_glyphs():
    total = 0
    for name, start, end in RANGES:
        count = end - start + 1
        total += count
        print(f"{name} range {hex(start)}–{hex(end)} : {count} glyphs")
    print(f"Total glyphs expected: {total}")
    return total


def decompress_lzss(data, expected_size):
    src = 0
    dst = bytearray()

    while len(dst) < expected_size:
        control = data[src]
        src += 1

        for bit in range(8):
            if len(dst) >= expected_size:
                break

            if (control >> bit) & 1 == 0:
                dst.append(data[src])
                src += 1
            else:
                a = data[src]
                b = data[src + 1]
                src += 2

                distance = ((a >> 6) << 8) | b
                length = (a & 0x3F) + 3

                for _ in range(length):
                    ref = len(dst) - distance - 1
                    if ref < 0:
                        dst.append(0)
                    else:
                        dst.append(dst[ref])

                    if len(dst) >= expected_size:
                        break

    return dst


def decode_4bpp(buffer, width, height):
    pitch = (width + 1) >> 1
    pixels = []

    for y in range(height):
        row = []
        for x in range(pitch):
            byte = buffer[y * pitch + x]

            hi = (byte >> 4) & 0xF
            lo = byte & 0xF

            row.append(hi * 17)
            if len(row) < width:
                row.append(lo * 17)

        pixels.append(row)

    return pixels


def read_glyph(data, offset):
    charcode = struct.unpack_from("<H", data, offset)[0]
    width = data[offset + 2]
    height = data[offset + 3]
    offx = data[offset + 4]
    offy = data[offset + 5]
    comp_size = struct.unpack_from("<H", data, offset + 6)[0]

    comp_data = data[offset + 8: offset + 8 + comp_size]

    pitch = (width + 1) >> 1
    expected = pitch * height

    raw = decompress_lzss(comp_data, expected)

    pixels = decode_4bpp(raw, width, height)

    return {
        "code": charcode,
        "width": width,
        "height": height,
        "pixels": pixels,
    }


def build_image(glyphs):
    cols = 64
    max_w = max(g["width"] for g in glyphs)
    max_h = max(g["height"] for g in glyphs)

    rows = (len(glyphs) + cols - 1) // cols

    img = Image.new("L", (cols * max_w, rows * max_h), 0)

    for i, g in enumerate(glyphs):
        gx = (i % cols) * max_w
        gy = (i // cols) * max_h

        for y in range(g["height"]):
            for x in range(g["width"]):
                img.putpixel((gx + x, gy + y), g["pixels"][y][x])

    return img


def main():
    if len(sys.argv) < 2:
        print("Usage: python fnt_to_png.py font.fnt")
        return

    filename = sys.argv[1]

    with open(filename, "rb") as f:
        data = f.read()

    magic = data[0:4]
    if magic != b"FNT3":
        print("Invalid FNT file")
        return

    filesize = struct.unpack_from("<I", data, 4)[0]

    print(f"File size: {filesize} bytes\n")
    total = count_glyphs()

    print("\nReading glyph links...")

    link_offset = 0x10
    links = []

    for i in range(total):
        off = struct.unpack_from("<I", data, link_offset + i * 4)[0]
        links.append(off)

    glyphs = []

    print("Decoding glyphs...")

    for off in links:
        if off == 0:
            continue
        glyphs.append(read_glyph(data, off))

    print(f"Decoded glyphs: {len(glyphs)}")

    print("Building image...")

    img = build_image(glyphs)

    outname = filename + ".png"
    img.save(outname)

    print(f"Saved PNG: {outname}")


if __name__ == "__main__":
    main()
