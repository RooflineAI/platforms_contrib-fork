load("@rules_testing//lib:test_suite.bzl", "test_suite")
load("//cpu/x86_64:x86_64_private.bzl", "X86_64_CLANG_FEATURES", "X86_64_EXTRA_FEATURES")
load(":feature_mapping.bzl", "validation_for_tests", "x86_64_feature_constraint_names")

visibility("private")

def _report():
    return {
        "schema": 1,
        "llvm_version": "22.1.8",
        "cpu": "generic",
        "features": {name: False for name in X86_64_CLANG_FEATURES + ["cmov", "64bit", "cx8"]},
        "extras": {name: False for name in X86_64_EXTRA_FEATURES},
    }

def _explicit_negatives_test(env):
    report = _report()
    report["features"]["x87"] = True
    report["features"]["avx512f"] = True
    report["features"]["avx512bf16"] = True
    report["extras"]["rdtscp"] = True
    names = x86_64_feature_constraint_names(report)
    env.expect.that_int(len(names)).equals(len(X86_64_CLANG_FEATURES) + len(X86_64_EXTRA_FEATURES))
    for name in ["x87", "avx512bf16", "rdtscp", "no_sse", "no_crc32", "no_push2pop2", "no_ppx", "no_ermsb"]:
        env.expect.that_bool(name in names).equals(True)
    for name in ["cmov", "64bit", "no_cmov", "no_64bit", "avx512_bf16", "fpu"]:
        env.expect.that_bool(name in names).equals(False)

def _missing_feature_test(env):
    report = _report()
    report["features"].pop("crc32")
    env.expect.that_str(validation_for_tests.report_error(report)).contains("missing [crc32]")

def _unknown_feature_test(env):
    report = _report()
    report["features"]["sse4_2"] = True
    env.expect.that_str(validation_for_tests.report_error(report)).contains("unknown [sse4_2]")

def _malformed_report_test(env):
    for report in [None, [], {}, {"schema": 2}]:
        env.expect.that_str(validation_for_tests.report_error(report)).contains("schema")
    report = _report()
    report["features"]["avx"] = 1
    env.expect.that_str(validation_for_tests.report_error(report)).contains("must be a boolean")
    report = _report()
    report["extras"] = []
    env.expect.that_str(validation_for_tests.report_error(report)).contains("must be a dictionary")
    report = _report()
    report["cpu"] = ""
    env.expect.that_str(validation_for_tests.report_error(report)).contains("nonempty cpu")

def _missing_prerequisite_test(env):
    report = _report()
    report["features"]["avx10.2"] = True
    env.expect.that_str(validation_for_tests.report_error(report)).contains("requires avx10.1")

def feature_mapping_test_suite(name):
    test_suite(
        name = name,
        basic_tests = [
            _explicit_negatives_test,
            _missing_feature_test,
            _unknown_feature_test,
            _malformed_report_test,
            _missing_prerequisite_test,
        ],
    )
