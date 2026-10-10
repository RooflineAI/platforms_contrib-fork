visibility(["//cpu/x86_64/...", "//private", "//prebuilt"])

# Baseline features default to enabled; explicit negatives support freestanding code.
X86_64_FEATURES = {
    "v1": ["fxsr", "mmx", "sse", "sse2", "x87"],
    "v2": ["crc32", "cx16", "popcnt", "sahf", "sse3", "sse4.1", "sse4.2", "ssse3"],
    "v3": ["avx", "avx2", "bmi", "bmi2", "f16c", "fma", "lzcnt", "movbe", "xsave"],
    "v4": ["avx512bw", "avx512cd", "avx512dq", "avx512f", "avx512vl"],
}

X86_64_LEVELS = X86_64_FEATURES.keys()

# LLVM feature names, excluding the levels above and deprecated compatibility flags.
X86_64_FEATURES_WITHOUT_LEVEL = [
    "adx",
    "aes",
    "amx-avx512",
    "amx-bf16",
    "amx-complex",
    "amx-fp16",
    "amx-fp8",
    "amx-int8",
    "amx-movrs",
    "amx-tile",
    "avx10.1",
    "avx10.2",
    "avx512bf16",
    "avx512bitalg",
    "avx512bmm",
    "avx512fp16",
    "avx512ifma",
    "avx512vbmi",
    "avx512vbmi2",
    "avx512vnni",
    "avx512vp2intersect",
    "avx512vpopcntdq",
    "avxifma",
    "avxneconvert",
    "avxvnni",
    "avxvnniint16",
    "avxvnniint8",
    "ccmp",
    "cf",
    "cldemote",
    "clflushopt",
    "clwb",
    "clzero",
    "cmpccxadd",
    "egpr",
    "enqcmd",
    "fma4",
    "fsgsbase",
    "gfni",
    "hreset",
    "invpcid",
    "jmpabs",
    "kl",
    "lwp",
    "movdir64b",
    "movdiri",
    "movrs",
    "mwaitx",
    "ndd",
    "nf",
    "pclmul",
    "pconfig",
    "pku",
    "ppx",
    "prefetchi",
    "prfchw",
    "ptwrite",
    "push2pop2",
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
    "xsavec",
    "xsaveopt",
    "xsaves",
    "zu",
]

# Additional CPUID capabilities useful for BUILD selections.
X86_64_EXTRA_FEATURES = [
    "ermsb",
    "fsrc",
    "fsrm",
    "fsrs",
    "fzrm",
    "rdtscp",
]

X86_64_LLVM_FEATURES = sorted([
    feature
    for features in X86_64_FEATURES.values()
    for feature in features
] + X86_64_FEATURES_WITHOUT_LEVEL)

# Feature prerequisites used by constraint_setting.refines_constraint_value.
# Unlisted features refine @platforms//cpu:x86_64.
#
# Each prerequisite is implied, possibly transitively, by the feature in the LLVM version the
# detector is built with; the links point to these implications and need updating with LLVM.
X86_64_FEATURE_REFINEMENTS = {
    # https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/llvm/lib/TargetParser/X86TargetParser.cpp#L639-L646
    "amx-avx512": "amx-tile",
    "amx-bf16": "amx-tile",
    "amx-complex": "amx-tile",
    "amx-fp16": "amx-tile",
    "amx-fp8": "amx-tile",
    "amx-int8": "amx-tile",
    "amx-movrs": "amx-tile",
    # https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/llvm/lib/TargetParser/X86TargetParser.cpp#L671
    "avx10.2": "avx10.1",
    # https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/llvm/lib/TargetParser/X86TargetParser.cpp#L612-L625
    # https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/llvm/lib/TargetParser/X86TargetParser.cpp#L657
    "avx512bf16": "avx512f",
    "avx512bitalg": "avx512f",
    "avx512bmm": "avx512bw",
    "avx512fp16": "avx512f",
    "avx512ifma": "avx512f",
    "avx512vbmi": "avx512f",
    "avx512vbmi2": "avx512f",
    "avx512vnni": "avx512f",
    "avx512vp2intersect": "avx512f",
    "avx512vpopcntdq": "avx512f",
    # https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/llvm/lib/TargetParser/X86TargetParser.cpp#L606-L607
    "vaes": "aes",
    "vpclmulqdq": "pclmul",
    # https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/llvm/lib/TargetParser/X86TargetParser.cpp#L660
    "widekl": "kl",
    # https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/llvm/lib/TargetParser/X86TargetParser.cpp#L582-L584
    "xsavec": "xsave",
    "xsaveopt": "xsave",
    "xsaves": "xsave",
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
