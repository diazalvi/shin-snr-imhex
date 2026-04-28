import struct
import os
import shutil
import argparse
from PIL import Image

def process_masks_for_obsidian(snr_path, source_png_dir, obsidian_folder):
    if not os.path.isdir(source_png_dir):
        print(f"Error: Source directory '{source_png_dir}' not found.")
        return
    
    if not os.path.exists(obsidian_folder):
        os.makedirs(obsidian_folder)

    try:
        with open(snr_path, "rb") as f:
            # 1. Read table pointer from offset 0x24
            f.seek(0x24)
            table_pointer = struct.unpack("<I", f.read(4))[0]
            
            # 2. Read number of entries
            f.seek(table_pointer)
            num_entries = struct.unpack("<I", f.read(4))[0]
            
            print("| Index | Mask Name | Thumbnail |")
            print("|-------|-----------|-----------|")

            for i in range(num_entries):
                entry_pos = table_pointer + 4 + (i * 12)
                f.seek(entry_pos)
                
                name_bytes = f.read(12)
                clean_name = name_bytes.split(b'\x00')[0].decode("utf-8", errors="ignore")
                
                if not clean_name:
                    continue

                png_filename = f"{clean_name}.png"
                src_path = os.path.join(source_png_dir, png_filename)
                dst_path = os.path.join(obsidian_folder, png_filename)

                if os.path.exists(src_path):
                    shutil.copy2(src_path, dst_path)
                    
                    # Check dimensions using PIL
                    with Image.open(src_path) as img:
                        width, height = img.size
                    
                    # Scale if either side > 50px
                    # Obsidian syntax [[file\|50]] scales width & maintains aspect ratio
                    if width > 50 or height > 50:
                        thumbnail = f"![[{png_filename}\|50]]"
                    else:
                        thumbnail = f"![[{png_filename}]]"
                else:
                    thumbnail = "_Missing_"

                print(f"| {i} | {clean_name} | {thumbnail} |")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract SNR masks with 50px proportional scaling")
    parser.add_argument("snr_file", help="Path to main.snr")
    parser.add_argument("source_pngs", help="Path to source PNGs")
    parser.add_argument("obsidian_vault_folder", help="Target folder in Obsidian")
    
    args = parser.parse_args()
    process_masks_for_obsidian(args.snr_file, args.source_pngs, args.obsidian_vault_folder)

