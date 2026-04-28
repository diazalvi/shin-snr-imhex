import os
import sys
import struct
from PIL import Image

def decompress_lzss(data, compressed_size):
    """Decompresses the TXA3 LZSS data."""
    if compressed_size == 0:
        return data

    input_ptr = 0
    output = bytearray()
    
    while input_ptr < compressed_size:
        control = data[input_ptr]
        input_ptr += 1
        
        for bit in range(8):
            if input_ptr >= compressed_size:
                break
                
            # Bit 0: Literal byte
            if not (control & (1 << bit)):
                output.append(data[input_ptr])
                input_ptr += 1
            else:
                # Bit 1: Compressed match (2 bytes)
                if input_ptr + 1 >= compressed_size:
                    break
                    
                a = data[input_ptr]
                b = data[input_ptr + 1]
                input_ptr += 2
                
                if not (a & 0x80):
                    # Distance optimized (a7 == 0)
                    count = ((a >> 3) & 0x0F) + 3
                    dist = (((a & 0x07) << 8) | b) * 4 + 132
                else:
                    # Count optimized (a7 == 1)
                    count = ((a & 0x7F) << 3 | (b >> 5)) + 3
                    dist = (b & 0x1F) * 4 + 4
                
                # Copy from back-reference
                for _ in range(count):
                    # Relative distance check
                    ref_idx = len(output) - dist
                    if ref_idx >= 0:
                        output.append(output[ref_idx])
                    else:
                        output.append(0) # Padding for safety
    return output

def convert_txa(file_path):
    with open(file_path, 'rb') as f:
        # --- Main Header ---
        magic = f.read(4)
        if magic != b'TXA3':
            print(f"Error: Invalid magic {magic}. Expected TXA3.")
            return

        f.seek(0x08)
        data_start = struct.unpack('<I', f.read(4))[0]
        comp_size = struct.unpack('<I', f.read(4))[0]
        
        f.seek(0x14)
        num_subimages = struct.unpack('<I', f.read(4))[0]

        # --- Read Subimage Headers ---
        subheaders = []
        current_header_pos = 0x20
        for _ in range(num_subimages):
            f.seek(current_header_pos)
            h_size = struct.unpack('<H', f.read(2))[0]
            index = struct.unpack('<H', f.read(2))[0]
            width = struct.unpack('<H', f.read(2))[0]
            height = struct.unpack('<H', f.read(2))[0]
            pitch = struct.unpack('<H', f.read(2))[0]
            
            f.seek(current_header_pos + 0x0C)
            data_offset = struct.unpack('<I', f.read(4))[0]
            
            # Read name (Zero-terminated Shift-JIS)
            f.seek(current_header_pos + 0x10)
            name_bytes = bytearray()
            while True:
                char = f.read(1)
                if char == b'\x00' or not char:
                    break
                name_bytes.extend(char)
            
            try:
                name = name_bytes.decode('shift-jis')
            except UnicodeDecodeError:
                name = f"subimage_{index}"

            subheaders.append({
                'width': width,
                'height': height,
                'pitch': pitch,
                'offset': data_offset,
                'name': name
            })
            current_header_pos += h_size

        # --- Decompress Graphic Data ---
        f.seek(data_start)
        raw_compressed = f.read(comp_size)
        decompressed_data = decompress_lzss(raw_compressed, comp_size)

        # --- Process Subimages ---
        base_filename = os.path.splitext(os.path.basename(file_path))[0]
        
        for sub in subheaders:
            img_data = bytearray()
            start = sub['offset']
            
            # Extract pixels based on pitch
            for y in range(sub['height']):
                row_start = start + (y * sub['pitch'])
                row_end = row_start + (sub['width'] * 4)
                img_data.extend(decompressed_data[row_start:row_end])
            
            if not img_data:
                continue

            # Convert B8G8R8A8 to RGBA for Pillow
            # Pillow's "RGBA" is R, G, B, A. We have B, G, R, A.
            img = Image.frombytes("RGBA", (sub['width'], sub['height']), bytes(img_data), "raw", "BGRA")
            
            output_name = f"{base_filename}_{sub['name']}.png"
            img.save(output_name)
            print(f"Saved: {output_name}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python txa_to_png.py <file.txa>")
    else:
        convert_txa(sys.argv[1])
