#include <std/mem.pat>
#include <std/core.pat>
#include <std/string.pat>

// Format function to generate "data0", "data1", etc.
fn format_data_name(auto value) {
    return std::string::to_string(std::core::array_index());
    };

struct PictureSubHeader {
    le u32 flags            [[color("AAAAAA"), comment("-> BytecodeSection")]];
    le u16 xpos             [[color("333333"), comment("-> BytecodeSection")]];
    le u16 ypos             [[color("444477"), comment("-> BytecodeSection")]];
    le u16 width            [[color("BBBBBB"), comment("-> BytecodeSection")]];
    le u16 height           [[color("404040"), comment("-> BytecodeSection")]];
    le u32 payload_offset   [[color("606060"), comment("-> BytecodeSection")]];
    le u32 compressed_size  [[color("606060"), comment("-> BytecodeSection")]];
    char data[compressed_size] @ payload_offset [[format("format_data_name")]];
};

struct PIC3Header {
    char magic[4];
    le u32 file_size     [[color("808080"), comment("-> BytecodeSection")]];;
    le u16 origin_x      [[color("AAAAAA"), comment("-> BytecodeSection")]];
    le u16 origin_y      [[color("00AAAA"), comment("-> MaskSection")]];
    le u16 width         [[color("0000AA"), comment("-> BytecodeSection")]];
    le u16 height        [[color("00AA00"), comment("-> MaskSection")]];
    le u32 unk32b        [[color("DDDDCC"), comment("-> MaskSection")]];
    le u32 num_pictures  [[color("203060"), comment("-> MaskSection")]];
    PictureSubHeader sub[num_pictures];  
};

PIC3Header header @ 0x00;