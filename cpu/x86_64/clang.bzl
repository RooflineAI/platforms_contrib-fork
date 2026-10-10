"""Clang instruction-set flags selected from the target platform's constraints."""

load(":x86_64_private.bzl", "X86_64_CLANG_FEATURES")

_APX_FEATURES = ["ccmp", "cf", "egpr", "ndd", "nf", "ppx", "push2pop2", "zu"]

def x86_64_clang_flags():
    """Returns Clang 22 x86-64 flags from a complete, consistent feature profile.

    Use as toolchain flags or cc_* copts. Later -m flags can override this profile.
    CPU-model tuning and macros are separate. CPUID-only selectors, including
    ermsb and fsrm, are not forwarded. Native profiles inherit LLVM 22's incomplete
    OS-state checks for AVX10 and SHA512/SM3/SM4.
    """
    flags = select({
        Label("@platforms//cpu:x86_64"): ["-march=x86-64"],
    }, no_match_error = "x86_64_clang_flags() requires an x86-64 target platform")

    # Negatives come last so a baseline disable also disables its extensions.
    for enabled in [True, False]:
        for feature in X86_64_CLANG_FEATURES:
            prefix = "-m" if enabled else "-mno-"
            flag = [prefix + ("apx-features=" if feature in _APX_FEATURES else "") + feature]
            flags += select({
                Label("//cpu/x86_64/feature:" + feature + "_enabled"): flag if enabled else [],
                "//conditions:default": [] if enabled else flag,
            })
    return flags
