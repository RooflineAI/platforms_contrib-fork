load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//cpu/x86_64:clang.bzl", "x86_64_clang_flags")
load("//cpu/x86_64:x86_64.bzl", "x86_64_level_constraints")
load("//cpu/x86_64:x86_64_private.bzl", "X86_64_CLANG_FEATURES", "X86_64_FEATURES")

_Flags = provider(fields = ["flags", "baseline", "sse", "no_amx_bf16"])

def _flags_impl(ctx):
    return [_Flags(flags = ctx.attr.flags, baseline = ctx.attr.baseline, sse = ctx.attr.sse, no_amx_bf16 = ctx.attr.no_amx_bf16)]

_flags = rule(
    implementation = _flags_impl,
    attrs = {
        "flags": attr.string_list(),
        "baseline": attr.bool(),
        "sse": attr.bool(),
        "no_amx_bf16": attr.bool(),
    },
)

def _baseline_test(env, target):
    values = target[_Flags]
    env.expect.that_bool(values.baseline).equals(True)
    env.expect.that_bool(values.sse).equals(True)
    env.expect.that_bool(values.no_amx_bf16).equals(True)
    for flag in ["-march=x86-64", "-mx87", "-mmmx", "-msse", "-msse2", "-mno-avx", "-mno-crc32", "-mno-apx-features=ppx"]:
        env.expect.that_bool(flag in values.flags).equals(True)
    env.expect.that_bool("-mno-ermsb" in values.flags).equals(False)

def _kernel_test(env, target):
    values = target[_Flags]
    env.expect.that_bool(values.baseline).equals(False)
    env.expect.that_bool(values.sse).equals(False)
    for flag in ["-mno-x87", "-mno-mmx", "-mno-sse", "-mno-sse2"]:
        env.expect.that_bool(flag in values.flags).equals(True)

def _v4_test(env, target):
    values = target[_Flags]
    for flag in ["-mavx512f", "-mavx512bw", "-mavx2", "-msse4.2", "-mcrc32"]:
        env.expect.that_bool(flag in values.flags).equals(True)

def clang_test_suite(name):
    native.platform(name = name + "_baseline", constraint_values = ["@platforms//cpu:x86_64"])
    native.platform(
        name = name + "_explicit_negatives",
        constraint_values = ["@platforms//cpu:x86_64"] + [
            "//cpu/x86_64/feature:" + (feature if feature in X86_64_FEATURES["v1"] else "no_" + feature)
            for feature in X86_64_CLANG_FEATURES
        ],
    )
    native.platform(
        name = name + "_kernel",
        constraint_values = ["@platforms//cpu:x86_64"] + [
            "//cpu/x86_64/feature:no_" + feature
            for feature in ["x87", "mmx", "sse", "sse2"]
        ],
    )
    native.platform(
        name = name + "_v4",
        constraint_values = ["@platforms//cpu:x86_64"] + x86_64_level_constraints("v4"),
    )
    _flags(
        name = name + "_flags",
        tags = ["manual"],
        flags = x86_64_clang_flags(),
        no_amx_bf16 = select({
            "//cpu/x86_64/feature:amx-bf16_disabled": True,
            "//conditions:default": False,
        }),
        baseline = select({"//cpu/x86_64:at_least_v1": True, "//conditions:default": False}),
        sse = select({
            "//cpu/x86_64/feature:sse_enabled": True,
            "//cpu/x86_64/feature:sse_disabled": False,
        }),
    )
    for platform, impl in [("baseline", _baseline_test), ("explicit_negatives", _baseline_test), ("kernel", _kernel_test), ("v4", _v4_test)]:
        analysis_test(
            name = name + "_" + platform + "_test",
            target = ":" + name + "_flags",
            impl = impl,
            config_settings = {"//command_line_option:platforms": str(Label("//cpu/x86_64/tests:" + name + "_" + platform))},
        )
