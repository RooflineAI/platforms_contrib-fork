visibility(["//cpu/x86_64/...", "//private"])

X86_64_FEATURES = {
    "v1": ["cmov", "cx8", "fpu", "fxsr", "mmx", "osfxsr", "sce", "sse", "sse2"],
    "v2": ["cx16", "lahf_sahf", "popcnt", "sse3", "sse4_1", "sse4_2", "ssse3"],
    "v3": ["avx", "avx2", "bmi1", "bmi2", "f16c", "fma3", "lzcnt", "movbe", "osxsave"],
    "v4": ["avx512bw", "avx512cd", "avx512dq", "avx512f", "avx512vl"],
}

X86_64_LEVELS = X86_64_FEATURES.keys()

# Optional features outside the x86-64 levels. Use cpu_features names
# (https://github.com/google/cpu_features) where available; otherwise use lowercase names
# with `.` and `-` replaced by `_`.
X86_64_FEATURES_WITHOUT_LEVEL = [
    "adx",
    "aes",
    "amx_avx512",
    "amx_bf16",
    "amx_complex",
    "amx_fp16",
    "amx_int8",
    "amx_tf32",
    "amx_tile",
    "apxf",
    "avx10_1",
    "avx10_2",
    "avx512_bf16",
    "avx512_fp16",
    "avx512_vp2intersect",
    "avx512bitalg",
    "avx512ifma",
    "avx512vbmi",
    "avx512vbmi2",
    "avx512vnni",
    "avx512vpopcntdq",
    "avx_vnni",
    "avxifma",
    "avxneconvert",
    "avxvnniint16",
    "avxvnniint8",
    "cldemote",
    "clflushopt",
    "clwb",
    "clzero",
    "cmpccxadd",
    "enqcmd",
    "erms",
    "fma4",
    "fs_rep_cmpsb_scasb",
    "fs_rep_mov",
    "fs_rep_stosb",
    "fsgsbase",
    "fz_rep_movsb",
    "gfni",
    "hreset",
    "invpcid",
    "kl",
    "lwp",
    "movdir64b",
    "movdiri",
    "movrs",
    "mwaitx",
    "pclmulqdq",
    "pconfig",
    "pku",
    "prefetchi",
    "prfchw",
    "ptwrite",
    "raoint",
    "rdpid",
    "rdpru",
    "rdrnd",
    "rdseed",
    "rtm",
    "serialize",
    "sgx",
    "sha",
    "sha512",
    "shstk",
    "sm3",
    "sm4",
    "sse4a",
    "tbm",
    "tsxldtrk",
    "uintr",
    "usermsr",
    "vaes",
    "vpclmulqdq",
    "waitpkg",
    "wbnoinvd",
    "widekl",
    "xop",
    "xsave",
    "xsavec",
    "xsaveopt",
    "xsaves",
]

# Feature prerequisites used by constraint_setting.refines_constraint_value.
# Unlisted features refine @platforms//cpu:x86_64.
X86_64_FEATURE_REFINEMENTS = {
    "avx512_bf16": "avx512f",
    "avx512_fp16": "avx512f",
    "avx512_vp2intersect": "avx512f",
    "avx512bitalg": "avx512f",
    "avx512ifma": "avx512f",
    "avx512vbmi": "avx512f",
    "avx512vbmi2": "avx512f",
    "avx512vnni": "avx512f",
    "avx512vpopcntdq": "avx512f",
    "amx_bf16": "amx_tile",
    "amx_complex": "amx_tile",
    "amx_fp16": "amx_tile",
    "amx_int8": "amx_tile",
    "amx_avx512": "amx_tile",
    "amx_tf32": "amx_tile",
    "xsavec": "xsave",
    "xsaveopt": "xsave",
    "xsaves": "xsave",
    "vaes": "aes",
    "vpclmulqdq": "pclmulqdq",
    "widekl": "kl",
    "avx10_2": "avx10_1",
}

def _features_up_to(level):
    features = []
    for lvl in X86_64_LEVELS:
        features += X86_64_FEATURES[lvl]
        if lvl == level:
            break
    return features

# Each level includes the features of all lower levels.
FEATURES_UP_TO = {level: _features_up_to(level) for level in X86_64_LEVELS}
