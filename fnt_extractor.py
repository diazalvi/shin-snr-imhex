import sys
import struct
import math
import os
from PIL import Image

def decompress_lzss(data, expected_size):
    """
    Decompresses LZSS data where:
    - Control byte bits (LSB to MSB) determine literal vs reference.
    - Bit 0: Literal byte.
    - Bit 1: 2-byte reference (10-bit distance, 6-bit length).
    """
    out = bytearray()
    idx = 0
    data_len = len(data)
    
    while len(out) < expected_size and idx < data_len:
        control = data[idx]
        idx += 1
        
        for i in range(8):
            if len(out) >= expected_size:
                break
                
            bit = (control >> i) & 1
            if bit == 0:
                if idx < data_len:
                    out.append(data[idx])
                    idx += 1
            else:
                if idx + 1 < data_len:
                    a = data[idx]
                    b = data[idx+1]
                    idx += 2
                    
                    # distance = a7..a6 | b7..b0
                    distance = (((a & 0xC0) >> 6) << 8) | b
                    # match size = (a5..a0) + 3
                    match_size = (a & 0x3F) + 3
                    
                    for _ in range(match_size):
                        ref_pos = len(out) - 1 - distance
                        out.append(out[ref_pos] if ref_pos >= 0 else 0)
    return out

def main():
    if len(sys.argv) < 2:
        print("Usage: python fnt_to_png.py <font.fnt>")
        sys.exit(1)
        
    filename = sys.argv[1]
    with open(filename, 'rb') as f:
        data = f.read()
        
    if data[0:4] != b'FNT3':
        print("Error: Invalid Magic. Expected FNT3.")
        sys.exit(1)

    # --- Header & Offset Table ---
    file_size = struct.unpack_from('<I', data, 4)[0]
    first_offset = struct.unpack_from('<I', data, 0x10)[0]
    num_glyphs = (first_offset - 0x10) // 4
    offsets = [struct.unpack_from('<I', data, 0x10 + i * 4)[0] for i in range(num_glyphs)]
    
    glyphs = []
    ranges = {"ASCII": 0, "8100-9FFF": 0, "E000-EAFF": 0, "F000-F0FF": 0, "Other": 0}
    
    # --- Glyph Processing ---
    for off in offsets:
        if off >= len(data): continue
        
        char_code, w, h, ox, oy, c_size = struct.unpack_from('<HBBBBH', data, off)
        
        # Shift-JIS Stats
        if 0x20 <= char_code <= 0x60: ranges["ASCII"] += 1
        elif 0x8100 <= char_code <= 0x9FFF: ranges["8100-9FFF"] += 1
        elif 0xE000 <= char_code <= 0xEAFF: ranges["E000-EAFF"] += 1
        elif 0xF000 <= char_code <= 0x60: ranges["F000-F0FF"] += 1
        else: ranges["Other"] += 1
            
        # Pitch: (width + 1) >> 1 for 4bpp
        pitch = (w + 1) >> 1
        expected_size = pitch * h
        
        comp_data = data[off + 8 : off + 8 + c_size]
        raw_data = decompress_lzss(comp_data, expected_size)
        
        glyphs.append({'w': w, 'h': h, 'data': raw_data, 'pitch': pitch})

    # --- Print Brief ---
    print(f"FNT3 Parsed: {num_glyphs} glyphs found.")
    for k, v in ranges.items():
        print(f"  {k}: {v}")

    # --- Render PNG ---
    max_w = max(g['w'] for g in glyphs)
    max_h = max(g['h'] for g in glyphs)
    cols = math.ceil(math.sqrt(len(glyphs)))
    rows = math.ceil(len(glyphs) / cols)
    
    out_img = Image.new('L', (cols * max_w, rows * max_h), 0)
    px = out_img.load()
    
    for i, g in enumerate(glyphs):
        base_x = (i % cols) * max_w
        base_y = (i // cols) * max_h
        
        for y in range(g['h']):
            for x in range(g['w']):
                byte_idx = y * g['pitch'] + (x >> 1)
                if byte_idx < len(g['data']):
                    val_byte = g['data'][byte_idx]
                    
                    # FIXED NIBBLE ORDER: 
                    # High nibble (bits 4-7) for even X (left)
                    # Low nibble (bits 0-3) for odd X (right)
                    if x % 2 == 0:
                        pixel_val = (val_byte >> 4) & 0x0F
                    else:
                        pixel_val = val_byte & 0x0F
                        
                    px[base_x + x, base_y + y] = pixel_val * 17

    out_name = os.path.splitext(filename)[0] + ".png"
    out_img.save(out_name)
    print(f"Success! Output saved to {out_name}")

if __name__ == '__main__':
    main()
