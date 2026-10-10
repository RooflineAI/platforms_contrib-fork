"""Validates the LLVM detector report and maps features to constraint values."""

load(
    "//cpu/x86_64:x86_64_private.bzl",
    "X86_64_EXTRA_FEATURES",
    "X86_64_FEATURE_REFINEMENTS",
    "X86_64_LLVM_FEATURES",
)

visibility("private")

# Fixed x86-64 capabilities without useful driver-level disable controls.
_X86_64_FIXED_FEATURES = ["64bit", "cmov", "cx8"]
_X86_64_REPORTED_FEATURES = X86_64_LLVM_FEATURES + _X86_64_FIXED_FEATURES

def _feature_map_error(features, expected, kind):
    if type(features) != "dict":
        return "The CPU feature detector's {} must be a dictionary".format(kind)
    missing = sorted([name for name in expected if name not in features])
    unknown = sorted([name for name in features if name not in expected])
    if missing or unknown:
        return "CPU detector {} mismatch: missing [{}], unknown [{}]".format(
            kind,
            ", ".join(missing),
            ", ".join(unknown),
        )
    for name, value in features.items():
        if type(value) != "bool":
            return "CPU detector feature {} must be a boolean".format(name)
    return None

def _report_error(report):
    if type(report) != "dict":
        return "The CPU feature detector must report a JSON object"
    for field in ["cpu", "llvm_version"]:
        if type(report.get(field)) != "string" or not report[field]:
            return "The CPU feature detector must report a nonempty " + field
    for field, expected in [("features", _X86_64_REPORTED_FEATURES), ("extras", X86_64_EXTRA_FEATURES)]:
        error = _feature_map_error(report.get(field), expected, field)
        if error:
            return error
    for name, parent in X86_64_FEATURE_REFINEMENTS.items():
        if report["features"][name] and not report["features"][parent]:
            return "CPU detector feature {} requires {}".format(name, parent)
    return None

def x86_64_feature_constraint_names(report):
    """Returns a positive or negative constraint name for every declared feature."""
    error = _report_error(report)
    if error:
        fail(error)
    features = report["features"] | report["extras"]
    return sorted([
        name if features[name] else "no_" + name
        for name in X86_64_LLVM_FEATURES + X86_64_EXTRA_FEATURES
    ])

validation_for_tests = struct(report_error = _report_error)
