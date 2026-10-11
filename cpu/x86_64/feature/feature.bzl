load("//private:compat_constraint_setting.bzl", "compat_constraint_setting")

visibility(["//cpu/x86_64/..."])

def x86_64_feature(name, available_by_default = False, refines = None):
    """Defines feature constraints and the config settings to select() on them.

    Args:
        name: LLVM feature name, or a supplemental CPUID capability.
        available_by_default: Whether an unspecified feature is available.
        refines: Prerequisite feature; defaults to the x86-64 CPU constraint.
    """
    available = name + "_available"
    unavailable = name + "_unavailable"
    compat_constraint_setting(
        name = name + "_setting",
        default_constraint_value = available if available_by_default else unavailable,
        refines_constraint_value = ":{}_available".format(refines) if refines else "@platforms//cpu:x86_64",
    )
    for config_setting_name, value in [(name, available), ("no_" + name, unavailable)]:
        native.constraint_value(
            name = value,
            constraint_setting = ":" + name + "_setting",
            visibility = ["//visibility:public"],
        )
        native.config_setting(
            name = config_setting_name,
            constraint_values = ["@platforms//cpu:x86_64", ":" + value],
            visibility = ["//visibility:public"],
        )
