load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//cpu/x86_64:x86_64.bzl", "x86_64_level_constraints")
load("//cpu/x86_64:x86_64_private.bzl", "X86_64_CLANG_FEATURES", "X86_64_FEATURES")

_Selections = provider(fields = ["baseline", "v4", "sse", "avx", "no_amx_bf16"])

def _selections_impl(ctx):
    return [_Selections(
        baseline = ctx.attr.baseline,
        v4 = ctx.attr.v4,
        sse = ctx.attr.sse,
        avx = ctx.attr.avx,
        no_amx_bf16 = ctx.attr.no_amx_bf16,
    )]

_selections = rule(
    implementation = _selections_impl,
    attrs = {
        "baseline": attr.bool(),
        "v4": attr.bool(),
        "sse": attr.string(),
        "avx": attr.string(),
        "no_amx_bf16": attr.bool(),
    },
)

def _baseline_test(env, target):
    values = target[_Selections]
    env.expect.that_bool(values.baseline).equals(True)
    env.expect.that_bool(values.v4).equals(False)
    env.expect.that_str(values.sse).equals("enabled")
    env.expect.that_str(values.avx).equals("disabled")
    env.expect.that_bool(values.no_amx_bf16).equals(True)

def _kernel_test(env, target):
    values = target[_Selections]
    env.expect.that_bool(values.baseline).equals(False)
    env.expect.that_str(values.sse).equals("disabled")

def _v4_test(env, target):
    values = target[_Selections]
    env.expect.that_bool(values.baseline).equals(True)
    env.expect.that_bool(values.v4).equals(True)
    env.expect.that_str(values.sse).equals("enabled")
    env.expect.that_str(values.avx).equals("enabled")

def _arm_test(env, target):
    values = target[_Selections]
    env.expect.that_bool(values.baseline).equals(False)
    env.expect.that_bool(values.v4).equals(False)
    env.expect.that_str(values.sse).equals("unmatched")
    env.expect.that_str(values.avx).equals("unmatched")
    env.expect.that_bool(values.no_amx_bf16).equals(False)

def _feature_state(feature):
    return select({
        "//cpu/x86_64/feature:" + feature + "_enabled": "enabled",
        "//cpu/x86_64/feature:" + feature + "_disabled": "disabled",
        "//conditions:default": "unmatched",
    })

def feature_test_suite(name):
    native.platform(name = name + "_baseline", constraint_values = ["@platforms//cpu:x86_64"])
    native.platform(name = name + "_arm", constraint_values = ["@platforms//cpu:aarch64"])
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
    _selections(
        name = name + "_selections",
        no_amx_bf16 = select({
            "//cpu/x86_64/feature:amx-bf16_disabled": True,
            "//conditions:default": False,
        }),
        baseline = select({"//cpu/x86_64:at_least_v1": True, "//conditions:default": False}),
        v4 = select({"//cpu/x86_64:at_least_v4": True, "//conditions:default": False}),
        sse = _feature_state("sse"),
        avx = _feature_state("avx"),
    )
    for platform, impl in [("baseline", _baseline_test), ("explicit_negatives", _baseline_test), ("kernel", _kernel_test), ("v4", _v4_test), ("arm", _arm_test)]:
        analysis_test(
            name = name + "_" + platform + "_test",
            target = ":" + name + "_selections",
            impl = impl,
            config_settings = {"//command_line_option:platforms": str(Label("//cpu/x86_64/tests:" + name + "_" + platform))},
        )
