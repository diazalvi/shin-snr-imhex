#include <std/io.pat>
#pragma endian little
#pragma array_limit 2000000
#pragma pattern_limit 10485760
#include <std/mem.pat>
#include <std/core.pat>
#include <std/sys.pat>

//----------------------------------------------------------------------------
// Helpers
//----------------------------------------------------------------------------

// Null-terminated filename string (ImHex will read until \0)
struct FilenameStr {
    char value[];
};

//----------------------------------------------------------------------------
// Section: SE background sound filenames
//   offset pointer at 0x38, layout: u32 count, then count * 0x18-byte records
//   each record is a fixed 0x18-byte null-padded filename string
//----------------------------------------------------------------------------

struct SEBgFilenameRecord {
    char name[0x18];
};

struct MovieRecord {
    char name[0x12];
};

struct MovieSection {
    le u32 count          [[color("FF8800")]];   // orange
    MovieRecord filenames[count];
    char pad [2];
};

struct BGMRecord {
    char filename[0xc];
    char title [0x28];
};

struct MaskFilenameRecord {
    char name[0xC];
};

struct SEBgSection {
    le u32 count          [[color("FF8800")]];   // orange
    SEBgFilenameRecord filenames[count];
};

struct BGMSection {
    le u32 count          [[color("FF8800")]];   // orange
    BGMRecord filenames[count];
};

struct VoiceRecord {
    char filename[0x10];
    le u32 param1;
    le u32 param2;
};

struct VoiceSection {
    le u32 count          [[color("FF8800")]];   // orange
    VoiceRecord record[count];
};

struct MaskSection {
    le u32 count          [[color("FF8800")]];   // orange
    MaskFilenameRecord filenames[count];
};

bitfield EpisodeSize {
  episode: 4;
  length: 12;
};

struct TipsEntry{
    le EpisodeSize props;
    char text [props.length-2];
};

struct TipsSection {
    le u32 count          [[color("FF8800")]];   // orange
    TipsEntry tip[count];
};

bitfield CharType {
  opcode: 4;
  rest: 12;
};

struct CharVersion {
le CharType type;
match (type.opcode) {
    (0x02): {
        char char_name[0x8];
        char char_version[0x10];
    }
    (0x03): char description[type.rest - 2];       
    (_): {}
 }
};

struct CharEntry{
    le EpisodeSize props;
    u64 bodyStart = $;
    s64 bodySize = s64(props.length) - 2;
    //char text [props.length-2];
    if (bodySize > 0) {
      CharVersion version[while (($ - bodyStart) < bodySize)];
    }
};

struct CharSection {
    le u32 count          [[color("FF8800")]];   // orange
    CharEntry tip[count];
    char pad[2];
};

struct CharFlagsField {
    le u32 field;
};

struct CharFlagsEntry {
    le u16 size;     
    CharFlagsField field[(size - 2) >> 2];
};

struct CharFlagsSection {
    le u32 count          [[color("FF8800")]];   // orange
    CharFlagsEntry data[count];
    char pad[2];
};

//----------------------------------------------------------------------------
// Section: MusicBox heard flags
//   offset pointer at 0x48, layout: u32 count, then count * MusicBoxHeardRecord
//----------------------------------------------------------------------------

struct MusicBoxHeardRecord {
    le u8 data[6]   [[color("00FF00")]];   // bright green
};

struct PictureBoxRecord {
    le u8 values_count;
    le u8 type                    [[color("FF0000")]];   // bright red
    le u16 values[values_count]   [[color("00FF00")]];   // bright green
};

struct BustupEntry {
    le char name[0x18];
    le char emotion[0x10];
};

struct AnimeEntry {
    le char name[0x24];
};

struct PicEntry {
    le char name[0x1a];
};

struct PictureBoxSeenFlags {
    le u32 record_count   [[color("FFFF00")]];   // bright yellow
    PictureBoxRecord records[record_count];
};
struct MusicBoxHeardFlags {
    le u32 record_count   [[color("FFFF00")]];   // bright yellow
    MusicBoxHeardRecord records[record_count];
};
struct BustupSection {
    le u32 record_count   [[color("FFFF00")]];   // bright yellow
    BustupEntry bustup[record_count];
};

struct PicSection {
    le u32 record_count   [[color("FFFF00")]];   // bright yellow
    PicEntry bustup[record_count];
};

struct AnimeSection {
    le u32 record_count   [[color("FFFF00")]];   // bright yellow
    AnimeEntry anime[record_count];
};


//----------------------------------------------------------------------------
// Header — read section offsets from the pointer table
//----------------------------------------------------------------------------

struct SNRHeader {
    char magic[3];
    u8 _pad[0x1d];
    le u32 off_bytecode     [[color("AAAAAA"), comment("-> BytecodeSection")]];
    le u32 off_mask         [[color("AAAAAA"), comment("-> MaskSection")]];
    le u32 off_pic          [[color("AAAAAA"), comment("-> PicSection")]];
    le u32 off_bustup       [[color("AAAAAA"), comment("-> BustupSection")]];    
    le u32 off_anime        [[color("AAAAAA"), comment("-> AnimeSection")]];    
    le u32 off_bgm          [[color("AAAAAA"), comment("-> BGMSection")]];
    le u32 off_sebg         [[color("AAAAAA"), comment("-> SEBgSection")]];
    le u32 off_movie        [[color("AAAAAA"), comment("-> MovieSection")]];
    le u32 off_voice        [[color("AAAAAA"), comment("-> VoiceSection")]];  // 0x3C..0x3F gap between the two known pointers
    le u32 off_picturebox   [[color("AAAAAA"), comment("-> PictureBoxSeenFlags")]];
    le u32 off_musicbox     [[color("AAAAAA"), comment("-> MusicBoxHeardFlags")]];
    le u32 off_tips         [[color("AAAAAA"), comment("-> TipsSection")]];
    le u32 off_charflags    [[color("AAAAAA"), comment("-> CharFlagsSection")]];
    le u32 off_chars        [[color("AAAAAA"), comment("-> CharSection")]];
    
    // Future section offset pointers go here, aligned to their file positions.
    // Add:  le u32 off_newSection [[color("AAAAAA"), comment("-> NewSection")]];
    // Then define the struct and a placement below.
};

SNRHeader header @ 0x00;

//----------------------------------------------------------------------------
// Section placements (driven by header offsets)
//----------------------------------------------------------------------------

SEBgSection         se_bg_sounds       @ header.off_sebg;
VoiceSection        voice_data         @ header.off_voice;
MovieSection        movie_section      @ header.off_movie;
BGMSection          bgm_data           @ header.off_bgm;
PictureBoxSeenFlags picturebox_flags   @ header.off_picturebox;
MusicBoxHeardFlags  musicbox_flags     @ header.off_musicbox;
TipsSection         tips_section       @ header.off_tips;
MaskSection         mask_section       @ header.off_mask;
PicSection          pic_section        @ header.off_pic;
BustupSection       bustup_section     @ header.off_bustup;
AnimeSection        anime_section      @ header.off_anime;
CharSection         chars_section      @ header.off_chars;
CharFlagsSection    charflags_section  @ header.off_charflags;


// Future sections:
// NewSection  new_section @ header.off_newSection;

//----------------------------------------------------------------------------
// Opcode enum — full dispatch table
//----------------------------------------------------------------------------

enum OpCode : u8 {
    // 0x00 - 0x3F: Standard No-Op Stubs (scriptTrue)

    // Logic and Memory Operations
    OP_UNARY            = 0x40, // PTR_op_unary
    OP_ALU              = 0x41, // PTR_op_alu
    OP_STACK            = 0x42, // PTR_op_stack
    SET_VARS_MULT_RANGE = 0x43, // PTR_setVarsMultRange
    SET_VAR_FROM_ARRAY  = 0x44, // PTR_setVarFromArray
    SET_VARS_MULT_ARRAY = 0x45, // PTR_setVarsMultArray

    // Flow Control
    JMP_COND            = 0x46, // PTR_jumpConditional
    JMP_ABS             = 0x47, // PTR_jumpAbsolute
    CALL                = 0x48, // PTR_call
    RET                 = 0x49, // PTR_ret
    SWITCH              = 0x4A, // PTR_switch
    SWITCH_CALL         = 0x4B, // PTR_switch_call

    // Utilities
    RAND_RANGE          = 0x4C, // PTR_rand_range
    PUSH_MULT           = 0x4D, // PTR_push_multiple
    POP_MULT            = 0x4E, // PTR_pop_multiple

    // 0x4F-0x7F: scriptTrue stubs

    // 0x80 - 0x8E: System / Message / Scene Commands (all return false / yield)
    CMD_EXIT            = 0x80, // PTR_prepareCommandEXIT      — exit_code_src: i16
    CMD_SGET            = 0x81, // PTR_prepareCommandSGET      — dst_var_ref: i16, flag_id: i16
    CMD_SSET            = 0x82, // PTR_prepareCommandSSET      — value_src: i16, flag_id: i16
    CMD_WAIT            = 0x83, // PTR_prepareCommandWAIT      — duration_src: i16
    CMD_WAITKEY         = 0x84, // PTR_prepareCommandWAITKEY   — mode_src: i16
    CMD_MSGINIT         = 0x85, // PTR_prepareCommandMSGINIT   — window_type: i16, justify: i16
    CMD_MSGGET          = 0x86, // PTR_prepareCommandMSGGET    — packed_header: i32, string (inline)
    CMD_MSGWAIT         = 0x87, // PTR_prepareCommandMSGWAIT   — mode_src: i16
    CMD_MSGSIGNAL       = 0x88, // PTR_prepareCommandMSGSIGNAL — (no params)
    CMD_MSGCLOSE        = 0x89, // PTR_prepareCommandMSGCLOSE  — (no params)
    CMD_MSGCHECK        = 0x8A, // PTR_prepareCommandMSGCHECK  — packed_id: i32
    CMD_LOGSET          = 0x8B, // PTR_prepareCommandLOGSET    — string (inline)
    CMD_SELECT          = 0x8C, // PTR_prepareCommandSELECT    — complex; see struct
    CMD_WIPE            = 0x8D, // PTR_prepareCommandWIPE      — bitmask: i8, conditional words
    CMD_WIPEWAIT        = 0x8E, // PTR_prepareCommandWIPEWAIT  — (no params)

    // 0x8F-0x9B: scriptTrue stubs

    // 0x9C - 0xA6: Audio Commands
    CMD_BGMPLAY         = 0x9C, // PTR_prepareCommandBGMPLAY   — song_id, loop_count, volume_raw, fade_duration
    CMD_BGMSTOP         = 0x9D, // PTR_prepareCommandBGMSTOP   — fade_duration
    CMD_BGMVOL          = 0x9E, // PTR_prepareCommandBGMVOL    — volume_raw, fade_duration
    CMD_BGMWAIT         = 0x9F, // PTR_prepareCommandBGMWAIT   — duration_src
    CMD_SEPLAY          = 0xA0, // PTR_prepareCommandSEPLAY    — stream_id, se_id, loop_count, volume_raw, fade_duration
    CMD_SESTOP          = 0xA1, // PTR_prepareCommandSESTOP    — stream_id, fade_duration
    CMD_SESTOPALL       = 0xA2, // PTR_prepareCommandSESTOPALL — fade_duration
    CMD_SEVOL           = 0xA3, // PTR_prepareCommandSEVOL     — stream_id, volume_raw, fade_duration
    CMD_SEWAIT          = 0xA4, // PTR_prepareCommandSEWAIT    — stream_id, do_preload
    CMD_SEONCE          = 0xA5, // PTR_prepareCommandSEONCE    — sound_effect_id, volume_raw, do_preload
    CMD_VIBRATE         = 0xA6, // PTR_prepareCommandVIBRATE   — vibration_intensity, duration_ticks

    // 0xA7-0xAF: scriptTrue stubs

    // 0xB0 - 0xBD: Misc Commands
    CMD_SAVEINFO        = 0xB0, // PTR_prepareCommandSAVEINFO  — type: u16, string (inline)
    CMD_MOVIE           = 0xB1, // PTR_prepareCommandMOVIE     — movie_id: i16
    CMD_BGMSYNC         = 0xB2, // PTR_prepareCommandBGMSYNC   — threshold_duration: i16
    CMD_EVBEGIN         = 0xB3, // PTR_prepareCommandEVBEGIN   — (no params)
    CMD_EVEND           = 0xB4, // PTR_prepareCommandEVEND     — (no params)
    // 0xB5: scriptTrue stub
    CMD_AUTOSAVE        = 0xB6, // PTR_prepareCommandAUTOSAVE  — (no params)
    CMD_BGMPLAY2        = 0xB7, // PTR_prepareCommandBGMPLAY2  — new_song_id, old_song_id, loop_count, volume_raw, crossfade_delay
    CMD_BGMVOL2         = 0xB8, // PTR_prepareCommandBGMVOL2   — volume_raw, fade_duration
    CMD_VOICEPLAY       = 0xB9, // PTR_prepareCommandVOICEPLAY — stream_id, voice_id, loop_count, volume_raw, fade_duration
    CMD_VOICEWAIT       = 0xBA, // PTR_prepareCommandVOICEWAIT — wait_flags
    // 0xBB-0xBC: scriptTrue stubs
    CMD_TIPSGET         = 0xBD, // PTR_prepareCommandTIPSGET   — count: i8, [i16[] operand_table]

    // 0xBE - 0xCB: Layer / Canvas / Screen Commands
    CMD_THROPY          = 0xBE, // PTR_prepareCommandTHROPY    — thropy_id: i16
    CMD_CHAR            = 0xBF, // PTR_prepareCommandCHAR      — num_entries: i16, unnamed_operand: i16
    CMD_LAYERCLEAR      = 0xC0, // PTR_prepareCommandLAYERCLEAR — (no params)
    CMD_LAYERLOAD       = 0xC1, // PTR_prepareCommandLAYERLOAD  — layer_id, layer_type, field_mask: i8, [i16[] layer_params]
    CMD_LAYERCTRL       = 0xC2, // PTR_prepareCommandLAYERCTRL  — layer_id, i1, field_mask: i8, [i16[] layer_data]
    CMD_LAYERWAIT       = 0xC3, // PTR_prepareCommandLAYERWAIT  — layer_id, anim_type
    CMD_MASKLOAD        = 0xC4, // PTR_prepareCommandMASKLOAD   — param0, param1
    CMD_CANVAS          = 0xC5, // PTR_prepareCommandCANVAS     — canvas_id
    CMD_CANVASINIT      = 0xC6, // PTR_prepareCommandCANVASINIT — (no params)
    CMD_CANVASCTRL      = 0xC7, // PTR_prepareCommandCANVASCTRL — num_entries, field_mask: i8, [i16[] step_data]
    CMD_CANVASWAIT      = 0xC8, // PTR_prepareCommandCANVASWAIT — param0
    CMD_SCREENINIT      = 0xC9, // PTR_prepareCommandSCREENINIT — (no params)
    CMD_SCREENCTR       = 0xCA, // PTR_prepareCommandSCREENCTRL — canvas_id, field_mask: i8, [i16[] data]
    CMD_SCREENWAIT      = 0xCB, // PTR_prepareCommandSCREENWAIT — anim_type

    // 0xCC-0xEF: scriptTrue stubs

    // 0xF0 - 0xF1: Debug/Utility Commands
    CMD_MSGBOX          = 0xF0, // PTR_prepareCommandMSGBOX     — str8 message (inline)
    CMD_SNAPSHOT        = 0xF1  // PTR_prepareCommandSNAPSHOT   — str8 filename_base, index: i16
    // 0xF2-0xFF: scriptTrue stubs
};

enum LayerType : u16 {
    LAYER_TYPE_TILE     = 0x1,     
    LAYER_TYPE_PICTURE  = 0x2,
    LAYER_TYPE_BUSTUP   = 0x3,
    LAYER_TYPE_ANIME    = 0x4,
    LAYER_TYPE_RAIN     = 0x5,
    LAYER_TYPE_EFFECT   = 0x6    
};


//----------------------------------------------------------------------------
// Format helpers
//----------------------------------------------------------------------------

fn format_payload(auto payload) {
    return std::format("Args: {}", sizeof(payload));
};

//----------------------------------------------------------------------------
// Payload structs — logic / flow (0x40–0x4E)
//----------------------------------------------------------------------------

struct PayloadUnary { u8 mode; u16 op1; if (mode >= 0x80) { u16 op2; } } [[format("format_payload")]];

// 0x41  OP_ALU
// Encoding: mode:u8, dst_var:u16, [op1:u16 [, op2:u16]]
//
//   mode & 0x7F == 0x01  (CLR)  → no operands: dst = 0
//   mode  < 0x80         (binary) → one operand: dst op= op1
//   mode >= 0x80         (ternary) → two operands: dst = op1 op op2
//   (mode 0x81 is ternary CLR: dst = 0, still reads no extra operands)
struct PayloadALU {
    u8  mode;
    u16 dst_var;
    u16 op1;
   
    u8  base_op = mode & 0x7F;
    if (mode >= 0x80) {
        u16 op2;
    }
} [[format("format_payload")]];

// 0x42  OP_STACK — RPN expression evaluator
// Encoding: dst_var:u16, then stream of {op_code:i8, [operand:u16]}
// Loop reads i8 op codes; negative byte (bit 7 set) terminates and pops result into dst_var.
// PUSH (0x00) reads one i16 operand; all other codes are operator-only (no inline operand).
struct StackOp {
    s8 op_code;
    // other fields...
    
    if (op_code < 0) {
        break;
    }
};

struct PayloadStack {
    u16 dst_var;
    StackOp ops[while($ < addressof(this) + 1024)];
};

// 0x43  SET_VARS_MULT_RANGE — value_src: i16, count: i8, then count * i16 var_indices
struct PayloadSetVarsMultRange {
    u16 value_src;
    u8  count;
    u16 var_idx[count];
} [[format("format_payload")]];

// 0x44  SET_VAR_FROM_ARRAY — dst_var: i16, index_src: i16, table_size: i8, then table_size * i16 table_data
struct PayloadSetVarFromArray {
    u16 dst_var;
    u16 index_src;
    u8  table_size;
    u16 table_data[table_size];
} [[format("format_payload")]];

// 0x45  SET_VARS_MULT_ARRAY — value_src: i16, index_src: i16, table_size: i8, then table_size * i16 var_index_table
struct PayloadSetVarsMultArray {
    u16 value_src;
    u16 index_src;
    u8  table_size;
    u16 var_index_table[table_size];
} [[format("format_payload")]];

// 0x46  JMP_COND — mode: i8, op1: i16, op2: i16, target_addr: i32
struct PayloadJumpCond {
    u8  mode;
    u16 op1;
    u16 op2;
    u32 target_addr;
} [[format("format_payload")]];

struct PayloadJumpAbs  { u32 target_addr; }                [[format("format_payload")]];
struct PayloadCall     { u32 target_addr; }                [[format("format_payload")]];

// 0x4A / 0x4B  SWITCH / SWITCH_CALL — index_src: i16, table_size: i16, then table_size * u32 addresses
struct SwitchEntry { le u32 target_addr; };
struct PayloadSwitch {
    le u16 index_src;
    le u16 table_size;
    SwitchEntry entries[table_size];
} [[format("format_payload")]];

// 0x4C  RAND_RANGE — dst_var: i16, op1: i16, op2: i16
struct PayloadRandRange {
    u16 dst_var;
    u16 op1;
    u16 op2;
} [[format("format_payload")]];

// 0x4D  PUSH_MULT — count: i8, then count * i16 operands
struct PayloadPushMult {
    u8  count;
    u16 operands[count];
} [[format("format_payload")]];

// 0x4E  POP_MULT — count: i8, then count * i16 var_indices
struct PayloadPopMult {
    u8  count;
    u16 var_idx[count];
} [[format("format_payload")]];

//----------------------------------------------------------------------------
// Payload structs — 0x80–0x8E System / Message / Scene Commands
//----------------------------------------------------------------------------

// 0x80  CMD_EXIT — exit_code_src: i16
struct PayloadExit {
    le u16 exit_code_src;
} [[format("format_payload")]];

// 0x81  CMD_SGET — dst_var_ref: i16, flag_id_src: i16
struct PayloadSGet {
    le u16 dst_var_ref;
    le u16 flag_id_src;
} [[format("format_payload")]];

// 0x82  CMD_SSET — value_src: i16, flag_id_src: i16
struct PayloadSSet {
    le u16 value_src;
    le u16 flag_id_src;
} [[format("format_payload")]];

// 0x83  CMD_WAIT — duration_src: i16
struct PayloadWait {
    le u16 duration_src;
} [[format("format_payload")]];

// 0x84  CMD_WAITKEY — mode_src: i16
struct PayloadWaitKey {
    le u16 mode_src;
} [[format("format_payload")]];

// 0x85  CMD_MSGINIT — window_type_src: i16, justify_src: i16
struct PayloadMsgInit {
    le u16 window_type_src;
    le u16 justify_src;
} [[format("format_payload")]];

// 0x86 CMD_MSGGET — packed_header: u32, length: u16, string: char[]
struct PayloadMsgGet {
    le u32 packed_header;
    le u16 message_size;
    char message_str[message_size];
} [[format("format_payload")]];

// 0x87  CMD_MSGWAIT — mode_src: i16
struct PayloadMsgWait {
    le u16 mode_src;
} [[format("format_payload")]];

// 0x88  CMD_MSGSIGNAL — no parameters
// 0x89  CMD_MSGCLOSE  — no parameters

// 0x8A CMD_MSGCHECK — packed_id: u16 (operand)
struct PayloadMsgCheck {
    le u16 packed_id;
} [[format("format_payload")]];

// 0x8B CMD_LOGSET — length: u16, message: char[]
struct PayloadLogSet {
    le u16 length;
    char message[length];
} [[format("format_payload")]];

// 0x8C  CMD_SELECT — complex variable-length layout
//   flag_idx: i16, global_id: i16, dst_var: i16 (encoded ref), visibility_mask: i16 (resolved),
//   metadata string (str8: skipString8b), choices string (null-delimited segments, double-null terminated).
struct PayloadSelect {
    le u16 choice_base_flag_idc;
    le u16 flag_base_id;
    le u16 script_var_num;
    le u16 visibility_bitmask;
    u8 title_len;
    char title_str[title_len];
    u8 choices_len;
    char choices[choices_len];
} [[format("format_payload")]];

// 0x8D  CMD_WIPE — bitmask: i8, then 0–4 conditional i16 words.
//   Bit 0 → mask_snr_id:i16 (default -1)
//   Bit 1 → duration_ticks:i16 (default 0)
//   Bit 2 → wipe_height:i16 (default 0x100)
//   Bit 3 → direction_flags:i16 (default 0)
//   Bit 7 → bool1 (wait-for-completion flag; no extra word consumed)
struct PayloadWipe {
    u8 bitmask;
    if (bitmask & 0x01) { le u16 mask_snr_id; }
    if (bitmask & 0x02) { le u16 duration_ticks; }
    if (bitmask & 0x04) { le u16 wipe_height; }
    if (bitmask & 0x08) { le u16 direction_flags; }
} [[format("format_payload")]];

//----------------------------------------------------------------------------
// Payload structs — 0x9C–0xA6 Audio Commands
//----------------------------------------------------------------------------

// 0x9C  CMD_BGMPLAY — song_id, loop_count, volume_raw (0–255 → /255.0f), fade_duration
struct PayloadBgmPlay {
    le u16 song_id;
    le u16 loop_count;
    le u16 volume_raw;
    le u16 fade_duration;
} [[format("format_payload")]];

// 0x9D  CMD_BGMSTOP — fade_duration
struct PayloadBgmStop {
    le u16 fade_duration;
} [[format("format_payload")]];

// 0x9E  CMD_BGMVOL — volume_raw, fade_duration
struct PayloadBgmVol {
    le u16 volume_raw;
    le u16 fade_duration;
} [[format("format_payload")]];

// 0x9F  CMD_BGMWAIT — duration_src (stored as float internally)
struct PayloadBgmWait {
    le u16 duration_src;
} [[format("format_payload")]];

// 0xA0  CMD_SEPLAY — stream_id, se_id, loop_count, volume_raw, fade_duration
struct PayloadSePlay {
    le u16 stream_id;
    le u16 se_id;
    le u16 loop_count;
    le u16 volume_raw;
    le u16 fade_duration;
} [[format("format_payload")]];

// 0xA1  CMD_SESTOP — stream_id, fade_duration
struct PayloadSeStop {
    le u16 stream_id;
    le u16 fade_duration;
} [[format("format_payload")]];

// 0xA2  CMD_SESTOPALL — fade_duration
struct PayloadSeStopAll {
    le u16 fade_duration;
} [[format("format_payload")]];

// 0xA3  CMD_SEVOL — stream_id, volume_raw, fade_duration
struct PayloadSeVol {
    le u16 stream_id;
    le u16 volume_raw;
    le u16 fade_duration;
} [[format("format_payload")]];

// 0xA4  CMD_SEWAIT — stream_id, do_preload
struct PayloadSeWait {
    le u16 stream_id;
    le u16 do_preload;
} [[format("format_payload")]];

// 0xA5  CMD_SEONCE — sound_effect_id, volume_raw, do_preload
struct PayloadSeOnce {
    le u16 sound_effect_id;
    le u16 volume_raw;
    le u16 do_preload;
} [[format("format_payload")]];

// 0xA6  CMD_VIBRATE — vibration_intensity, duration_ticks
struct PayloadVibrate {
    le u16 vibration_intensity;
    le u16 duration_ticks;
} [[format("format_payload")]];

//----------------------------------------------------------------------------
// Payload structs — 0xB0–0xBD Misc Commands
//----------------------------------------------------------------------------

// 0xB0  CMD_SAVEINFO — type: i8, followed by inline null-terminated string
struct PayloadSaveInfo {
    le u16   type;
    char     saveinfo_str[];
} [[format("format_payload")]];

// 0xB1  CMD_MOVIE — movie_id: i16
struct PayloadMovie {
    le u16 movie_id;
} [[format("format_payload")]];

// 0xB2  CMD_BGMSYNC — threshold_duration: i16
struct PayloadBgmSync {
    le u16 threshold_duration;
} [[format("format_payload")]];

// 0xB3  CMD_EVBEGIN — no params
// 0xB4  CMD_EVEND   — no params
// 0xB6  CMD_AUTOSAVE — no params

// 0xB7  CMD_BGMPLAY2 — new_song_id, old_song_id, loop_count, volume_raw, crossfade_delay
struct PayloadBgmPlay2 {
    le u16 new_song_id;
    le u16 old_song_id;
    le u16 loop_count;
    le u16 volume_raw;
    le u16 crossfade_delay;
} [[format("format_payload")]];

// 0xB8  CMD_BGMVOL2 — volume_raw, fade_duration
struct PayloadBgmVol2 {
    le u16 volume_raw;
    le u16 fade_duration;
} [[format("format_payload")]];

// 0xB9  CMD_VOICEPLAY — stream_id, voice_id, loop_count, volume_raw, fade_duration
struct PayloadVoicePlay {
    le u16 stream_id;
    le u16 voice_id;
    le u16 loop_count;
    le u16 volume_raw;
    le u16 fade_duration;
} [[format("format_payload")]];

// 0xBA  CMD_VOICEWAIT — wait_flags: i16
struct PayloadVoiceWait {
    le u16 wait_flags;
} [[format("format_payload")]];

// 0xBD  CMD_TIPSGET — count: i8, then count * i16 operands (max 32)
struct PayloadTipsGet {
    u8  count;
    u16 operands[count];
} [[format("format_payload")]];

//----------------------------------------------------------------------------
// Payload structs — 0xBE–0xCB Layer / Canvas / Screen Commands
//----------------------------------------------------------------------------

// 0xBE  CMD_THROPY — thropy_id: i16
struct PayloadThropy {
    le u16 thropy_id;
} [[format("format_payload")]];

// 0xBF  CMD_CHAR — num_entries: i16, unnamed_operand: i16
struct PayloadChar {
    le u16 num_entries;
    le u16 unnamed_operand;
} [[format("format_payload")]];

// 0xC0  CMD_LAYERCLEAR — no params

// 0xC1  CMD_LAYERLOAD — layer_id: i16, layer_type: i16, field_mask: i8, [i16[] layer_params (8 max)]
// Bit N of field_mask controls whether layer_params[N] is present in bytecode; absent fields → 0.
struct PayloadLayerLoad {
    le u16       layer_id;
    le LayerType layer_type;
    u8           field_mask;
    if (field_mask & 0x01) { le u16 asset_id; }
    if (field_mask & 0x02) { le u16 paramb; }
    if (field_mask & 0x04) { le u16 width; }
    if (field_mask & 0x08) { le u16 height; }
    if (field_mask & 0x10) { le u16 x; }
    if (field_mask & 0x20) { le u16 y; }
    if (field_mask & 0x40) { le u16 paramc; }
    if (field_mask & 0x80) { le u16 paramd; }
} [[format("format_payload")]];

// 0xC2  CMD_LAYERCTRL — layer_id: i16, i1: i16, field_mask: i8, [i16[] layer_data (8 max)]
// Structurally identical to LAYERLOAD; i1 purpose TBD.
struct PayloadLayerCtrl {
    le u16 layer_id;
    le u16 i1;
    u8     field_mask;
    if (field_mask & 0x01) { le u16 param0; }
    if (field_mask & 0x02) { le u16 param1; }
    if (field_mask & 0x04) { le u16 param2; }
    if (field_mask & 0x08) { le u16 param3; }
    if (field_mask & 0x10) { le u16 param4; }
    if (field_mask & 0x20) { le u16 param5; }
    if (field_mask & 0x40) { le u16 param6; }
    if (field_mask & 0x80) { le u16 param7; }
} [[format("format_payload")]];

// 0xC3  CMD_LAYERWAIT — layer_id: i16, anim_type: i16
struct PayloadLayerWait {
    le u16 layer_id;
    le u16 anim_type;
} [[format("format_payload")]];

// 0xC4  CMD_MASKLOAD — param0: i16, param1: i16
struct PayloadMaskLoad {
    le u16 param0;
    le u16 param1;
} [[format("format_payload")]];

// 0xC5  CMD_CANVAS — canvas_id: i16
struct PayloadCanvas {
    le u16 canvas_id;
} [[format("format_payload")]];

// 0xC6  CMD_CANVASINIT — no params

// 0xC7  CMD_CANVASCTRL — num_entries: i16, field_mask: i8, [i16[] step_data (8 max, typed InterpolatorStep)]
struct PayloadCanvasCtrl {
    le u16 num_entries;
    u8     field_mask;
    if (field_mask & 0x01) { le u16 param0; }
    if (field_mask & 0x02) { le u16 param1; }
    if (field_mask & 0x04) { le u16 param2; }
    if (field_mask & 0x08) { le u16 param3; }
    if (field_mask & 0x10) { le u16 param4; }
    if (field_mask & 0x20) { le u16 param5; }
    if (field_mask & 0x40) { le u16 param6; }
    if (field_mask & 0x80) { le u16 param7; }
} [[format("format_payload")]];

// 0xC8  CMD_CANVASWAIT — param0: i16
struct PayloadCanvasWait {
    le u16 param0;
} [[format("format_payload")]];

// 0xC9  CMD_SCREENINIT — no params

// 0xCA  CMD_SCREENCTR — canvas_id: i16, field_mask: i8, [i16[] data (8 max)]
// Note: data[] lives at struct offset +0x10, not +0x04 (12-byte gap TBD).
struct PayloadScreenCtrl {
    le u16 canvas_id;
    u8     field_mask;
    if (field_mask & 0x01) { le u16 param0; }
    if (field_mask & 0x02) { le u16 param1; }
    if (field_mask & 0x04) { le u16 param2; }
    if (field_mask & 0x08) { le u16 param3; }
    if (field_mask & 0x10) { le u16 param4; }
    if (field_mask & 0x20) { le u16 param5; }
    if (field_mask & 0x40) { le u16 param6; }
    if (field_mask & 0x80) { le u16 param7; }
} [[format("format_payload")]];

// 0xCB  CMD_SCREENWAIT — anim_type: i16
struct PayloadScreenWait {
    le u16 anim_type;
} [[format("format_payload")]];

//----------------------------------------------------------------------------
// Payload structs — 0xF0–0xF1 Debug/Utility Commands
//----------------------------------------------------------------------------

// 0xF0  CMD_MSGBOX — str8: length-prefixed inline null-terminated string (via skipString8b)
struct PayloadMsgBox {
    u8   len;
    char message[len];
} [[format("format_payload")]];

// 0xF1 CMD_SNAPSHOT — length: u8, filename: char[], index: u16
struct PayloadSnapshot {
    u8 length;
    char filename_base[length];
    le u16 index;
} [[format("format_payload")]];

// Generic two-word fallback for opcodes whose layout is not yet confirmed.
struct PayloadGeneric { le u16 params[2]; } [[format("format_payload")]];

//----------------------------------------------------------------------------
// Instruction dispatch
//----------------------------------------------------------------------------

struct Instruction {
    OpCode opcode;

    match (opcode) {

        // ── Logic / Memory ──────────────────────────────────────────────────
        (OpCode::OP_UNARY):            PayloadUnary           unary;     // 0x40
        (OpCode::OP_ALU):              PayloadALU             alu;       // 0x41
        (OpCode::OP_STACK):            PayloadStack           stack;     // 0x42
        (OpCode::SET_VARS_MULT_RANGE): PayloadSetVarsMultRange smr;      // 0x43
        (OpCode::SET_VAR_FROM_ARRAY):  PayloadSetVarFromArray  sva;      // 0x44
        (OpCode::SET_VARS_MULT_ARRAY): PayloadSetVarsMultArray sma;      // 0x45

        // ── Flow Control ────────────────────────────────────────────────────
        (OpCode::JMP_COND):            PayloadJumpCond        jmp;       // 0x46
        (OpCode::JMP_ABS):             PayloadJumpAbs         jmp;       // 0x47
        (OpCode::CALL):                PayloadCall            call;      // 0x48
        (OpCode::RET):                 { }                               // 0x49 — no params
        (OpCode::SWITCH):              PayloadSwitch          sw;        // 0x4A
        (OpCode::SWITCH_CALL):         PayloadSwitch          sw;        // 0x4B

        // ── Utilities ───────────────────────────────────────────────────────
        (OpCode::RAND_RANGE):          PayloadRandRange       rr;        // 0x4C
        (OpCode::PUSH_MULT):           PayloadPushMult        pm;        // 0x4D
        (OpCode::POP_MULT):            PayloadPopMult         pm;        // 0x4E

        // ── System / Message / Scene Commands (0x80–0x8E) ───────────────────
        (OpCode::CMD_EXIT):            PayloadExit            exit;      // 0x80
        (OpCode::CMD_SGET):            PayloadSGet            sget;      // 0x81
        (OpCode::CMD_SSET):            PayloadSSet            sset;      // 0x82
        (OpCode::CMD_WAIT):            PayloadWait            wait;      // 0x83
        (OpCode::CMD_WAITKEY):         PayloadWaitKey         wkey;      // 0x84
        (OpCode::CMD_MSGINIT):         PayloadMsgInit         msginit;   // 0x85
        (OpCode::CMD_MSGGET):          PayloadMsgGet          msgget;    // 0x86 — variable length
        (OpCode::CMD_MSGWAIT):         PayloadMsgWait         msgwait;   // 0x87
        (OpCode::CMD_MSGSIGNAL):       { }                               // 0x88 — no params
        (OpCode::CMD_MSGCLOSE):        { }                               // 0x89 — no params
        (OpCode::CMD_MSGCHECK):        PayloadMsgCheck        msgcheck;  // 0x8A
        (OpCode::CMD_LOGSET):          PayloadLogSet          log;       // 0x8B — variable length
        (OpCode::CMD_SELECT):          PayloadSelect          select;    // 0x8C 
        (OpCode::CMD_WIPE):            PayloadWipe            wipe;      // 0x8D 
        (OpCode::CMD_WIPEWAIT):        { }                               // 0x8E — no params

        // ── Audio Commands (0x9C–0xA6) ──────────────────────────────────────
        (OpCode::CMD_BGMPLAY):         PayloadBgmPlay         bgmplay;   // 0x9C
        (OpCode::CMD_BGMSTOP):         PayloadBgmStop         bgmstop;   // 0x9D
        (OpCode::CMD_BGMVOL):          PayloadBgmVol          bgmvol;    // 0x9E
        (OpCode::CMD_BGMWAIT):         PayloadBgmWait         bgmwait;   // 0x9F
        (OpCode::CMD_SEPLAY):          PayloadSePlay          seplay;    // 0xA0
        (OpCode::CMD_SESTOP):          PayloadSeStop          sestop;    // 0xA1
        (OpCode::CMD_SESTOPALL):       PayloadSeStopAll       sestopall; // 0xA2
        (OpCode::CMD_SEVOL):           PayloadSeVol           sevol;     // 0xA3
        (OpCode::CMD_SEWAIT):          PayloadSeWait          sewait;    // 0xA4
        (OpCode::CMD_SEONCE):          PayloadSeOnce          seonce;    // 0xA5
        (OpCode::CMD_VIBRATE):         PayloadVibrate         vibrate;   // 0xA6

        // ── Misc Commands (0xB0–0xBD) ───────────────────────────────────────
        (OpCode::CMD_SAVEINFO):        PayloadSaveInfo        saveinfo;  // 0xB0 — variable length
        (OpCode::CMD_MOVIE):           PayloadMovie           movie;     // 0xB1
        (OpCode::CMD_BGMSYNC):         PayloadBgmSync         bgmsync;   // 0xB2
        (OpCode::CMD_EVBEGIN):         { }                               // 0xB3 — no params
        (OpCode::CMD_EVEND):           { }                               // 0xB4 — no params
        (OpCode::CMD_AUTOSAVE):        { }                               // 0xB6 — no params
        (OpCode::CMD_BGMPLAY2):        PayloadBgmPlay2        bgmplay2;  // 0xB7
        (OpCode::CMD_BGMVOL2):         PayloadBgmVol2         bgmvol2;   // 0xB8
        (OpCode::CMD_VOICEPLAY):       PayloadVoicePlay       voiceplay; // 0xB9
        (OpCode::CMD_VOICEWAIT):       PayloadVoiceWait       voicewait; // 0xBA
        (OpCode::CMD_TIPSGET):         PayloadTipsGet         tipsget;   // 0xBD

        // ── Layer / Canvas / Screen Commands (0xBE–0xCB) ────────────────────
        (OpCode::CMD_THROPY):          PayloadThropy          thropy;    // 0xBE
        (OpCode::CMD_CHAR):            PayloadChar            ch;        // 0xBF
        (OpCode::CMD_LAYERCLEAR):      { }                               // 0xC0 — no params
        (OpCode::CMD_LAYERLOAD):       PayloadLayerLoad       lload;     // 0xC1 — bitmask-gated
        (OpCode::CMD_LAYERCTRL):       PayloadLayerCtrl       lctrl;     // 0xC2 — bitmask-gated
        (OpCode::CMD_LAYERWAIT):       PayloadLayerWait       lwait;     // 0xC3
        (OpCode::CMD_MASKLOAD):        PayloadMaskLoad        mload;     // 0xC4
        (OpCode::CMD_CANVAS):          PayloadCanvas          canvas;    // 0xC5
        (OpCode::CMD_CANVASINIT):      { }                               // 0xC6 — no params
        (OpCode::CMD_CANVASCTRL):      PayloadCanvasCtrl      cctrl;     // 0xC7 — bitmask-gated
        (OpCode::CMD_CANVASWAIT):      PayloadCanvasWait      cwait;     // 0xC8
        (OpCode::CMD_SCREENINIT):      { }                               // 0xC9 — no params
        (OpCode::CMD_SCREENCTR):       PayloadScreenCtrl      sctrl;     // 0xCA — bitmask-gated
        (OpCode::CMD_SCREENWAIT):      PayloadScreenWait      swait;     // 0xCB

        // ── Debug/Utility (0xF0–0xF1) ───────────────────────────────────────
        (OpCode::CMD_MSGBOX):          PayloadMsgBox          msgbox;    // 0xF0 — str8
        (OpCode::CMD_SNAPSHOT):        PayloadSnapshot        snapshot;  // 0xF1 — str8 + i16

        // ── scriptTrue No-Op Stubs ───────────────────────────────────────────
        (0x00 ... 0x3F): { }
        (0x4F ... 0x7F): { }
        (0x8F ... 0x9B): { }
        (0xA7 ... 0xAF): { }
        (0xB5):          { }
        (0xBB ... 0xBC): { }
        (0xCC ... 0xEF): { }
        (0xF2 ... 0xFF): { }

        (_): {
            std::assert(false, std::format("Unrecognized Opcode at {:#X}", $ - 1));
        }
    }
};

// Loop through until the end of the file
Instruction script[while(!std::mem::eof())] @ header.off_bytecode;