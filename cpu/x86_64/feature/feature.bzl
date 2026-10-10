load("//private:compat_constraint_setting.bzl", "compat_constraint_setting")

visibility(["//cpu/x86_64/..."])

def x86_64_feature(name, available_by_default = False, refines = None):
    """Defines feature constraints and their enabled/disabled config settings.

    Args:
        name: LLVM feature name, or a supplemental CPUID capability.
        available_by_default: Whether an unspecified feature is enabled.
        refines: Prerequisite feature; defaults to the x86-64 CPU constraint.
    """
    compat_constraint_setting(
        name = name + "_setting",
        default_constraint_value = name if available_by_default else "no_" + name,
        refines_constraint_value = refines or "@platforms//cpu:x86_64",
    )
    native.constraint_value(
        name = name,
        constraint_setting = ":" + name + "_setting",
        visibility = ["//visibility:public"],
    )
    native.constraint_value(
        name = "no_" + name,
        constraint_setting = ":" + name + "_setting",
        visibility = ["//visibility:public"],
    )
    for suffix, value in [("enabled", name), ("disabled", "no_" + name)]:
        native.config_setting(
            name = name + "_" + suffix,
            constraint_values = ["@platforms//cpu:x86_64", ":" + value],
            visibility = ["//visibility:public"],
        )
