#!/usr/bin/env python3
"""Generates aarch64_features.bzl from LLVM's AArch64Features.td.

Usage, from the repository root:

    python3 cpu/aarch64/generate.py [path/to/AArch64Features.td]

Without an argument, the file is fetched with the authenticated `gh` CLI from the LLVM tag pinned
below. Only the Python standard library is used.

What is extracted:

  * Every `ExtensionWithMArch<"TargetFeatureName", ...>` record. The public token is the `-march`
    spelling: `TargetFeatureName`, unless a `let ... UserVisibleName = "X" in` line directly
    precedes the `def` of that record, in which case it is `X`. The meta-alias `crypto` is dropped
    because it is a version-dependent bundle.
  * Every `Architecture64<MAJOR, MINOR, "a", ...>` record, parsed to validate the file; the
    versions are not emitted yet.
"""

import os
import re
import subprocess
import sys

LLVM_TAG = "llvmorg-23.1.2"
TD_PATH = "llvm/lib/Target/AArch64/AArch64Features.td"
HOST_PATH = "llvm/lib/TargetParser/Host.cpp"

# Meta-aliases that are not a single feature.
DROPPED_FEATURES = frozenset(["crypto"])

# Only the A-profile is in scope.
SUPPORTED_PROFILES = frozenset(["a"])

REGENERATE_COMMAND = "python3 cpu/aarch64/generate.py"

_HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.join(_HERE, "aarch64_features.bzl")
# The MIDR -> -mcpu table is a C include consumed by prebuilt/detect_cpu_aarch64.cc.
CPU_MODELS_OUTPUT = os.path.join(os.path.dirname(os.path.dirname(_HERE)), "prebuilt", "aarch64_cpu_models.inc")

# MIDR implementer blocks and the per-part -mcpu names inside them, in getHostCPUNameForARM.
_IMPLEMENTER = re.compile(r'Implementer == "(0x[0-9a-fA-F]+)"')
_CASE = re.compile(r'\.Case\("(0x[0-9a-fA-F]+)",\s*"([^"]+)"\)')

# A `let` line applies to the `def` that immediately follows it. Only whitespace may separate them.
_RECORD = re.compile(
    r"""
    (?:^let[ \t]+(?P<let>[^\n]*?)[ \t]+in[ \t]*\n\s*)?   # optional `let ... in`
    ^def[ \t]+\w+[ \t]*:[ \t]*(?P<cls>ExtensionWithMArch|Architecture64)
    <[ \t]*(?P<args>.*?)>                                 # template arguments, up to the closing >
    """,
    re.MULTILINE | re.VERBOSE | re.DOTALL,
)
_ASSIGNMENT = re.compile(r'(\w+)\s*=\s*"([^"]*)"')

# Longest one-line gloss kept next to a feature; longer LLVM descriptions are truncated at a word.
_DESCRIPTION_CAP = 66


def normalize_desc(text):
    """Reduces an LLVM feature description to a one-line gloss: drop a leading "Enable", then cap."""
    text = " ".join(text.split())
    text = re.sub(r"^Enables?\s+", "", text)
    if len(text) > _DESCRIPTION_CAP:
        text = text[:_DESCRIPTION_CAP].rsplit(" ", 1)[0] + "..."
    return text


def fetch(path):
    """Returns a file from llvm-project at the pinned tag using the gh CLI."""
    url = "/repos/llvm/llvm-project/contents/{}?ref={}".format(path, LLVM_TAG)
    result = subprocess.run(
        ["gh", "api", "-H", "Accept: application/vnd.github.raw", url],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def resolve_commit():
    """Returns the commit SHA that LLVM_TAG points to, or "unresolved" on failure."""
    try:
        result = subprocess.run(
            ["gh", "api", "/repos/llvm/llvm-project/commits/{}".format(LLVM_TAG), "--jq", ".sha"],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unresolved"


def strip_comments(text):
    return re.sub(r"//[^\n]*", "", text)


def parse(text):
    """Returns (sorted feature tokens, ordered base versions, {token: gloss}, {token: -mattr name})."""
    features = set()
    versions = {}
    descriptions = {}
    mattr_overrides = {}
    for match in _RECORD.finditer(strip_comments(text)):
        overrides = dict(_ASSIGNMENT.findall(match.group("let") or ""))
        args = match.group("args")
        if match.group("cls") == "ExtensionWithMArch":
            name = re.match(r'"([^"]+)"', args)
            if not name:
                raise SystemExit("Cannot parse ExtensionWithMArch arguments: " + args)
            target_feature_name = name.group(1)
            if target_feature_name in DROPPED_FEATURES:
                continue
            token = overrides.get("UserVisibleName", target_feature_name)
            if token in features:
                raise SystemExit("Duplicate -march token: " + token)
            features.add(token)
            # The -march token (UserVisibleName) differs from the -mattr/-target-feature name
            # (TargetFeatureName) for a few extensions, e.g. simd -> neon. Record those.
            if token != target_feature_name:
                mattr_overrides[token] = target_feature_name
            # Positional args are "TargetFeatureName", "Spelling", "ArchitectureFeatureName", "Desc".
            quoted = re.findall(r'"([^"]*)"', args)
            desc = normalize_desc(quoted[3]) if len(quoted) >= 4 else ""
            if desc:
                descriptions[token] = desc
        else:
            parsed = re.match(r'(\d+)\s*,\s*(\d+)\s*,\s*"([a-z])"', args)
            if not parsed:
                raise SystemExit("Cannot parse Architecture64 arguments: " + args)
            major, minor, profile = int(parsed.group(1)), int(parsed.group(2)), parsed.group(3)
            if profile not in SUPPORTED_PROFILES:
                continue
            versions[(major, minor)] = "armv{}{}-{}".format(
                major,
                "" if minor == 0 else ".{}".format(minor),
                profile,
            )
    if not features or not versions:
        raise SystemExit("Parsed no features or versions; has the .td format changed?")
    return sorted(features), [versions[key] for key in sorted(versions)], descriptions, mattr_overrides


def parse_cpu_models(host_text):
    """Returns [(implementer, part, -mcpu name)] from getHostCPUNameForARM's per-vendor tables.

    Each `.Case("0xPPP", "name")` is attributed to the implementer(s) of the enclosing
    `if (Implementer == "0xNN")` block. Variant-disambiguated parts (Samsung Exynos, which use a
    C `switch` rather than `.Case`) and the big.LITTLE/SoC-name special cases are not `.Case`s, so
    they are skipped; an unlisted (implementer, part) later yields an empty model.
    """
    start = host_text.index("getHostCPUNameForARMFromComponents")
    end = host_text.index("getHostCPUNameForARM(StringRef", start)
    models = []
    seen = set()
    implementers = []
    for line in host_text[start:end].splitlines():
        found = _IMPLEMENTER.findall(line)
        if found:
            implementers = [int(value, 16) for value in found]
        for part, name in _CASE.findall(line):
            for implementer in implementers:
                key = (implementer, int(part, 16))
                if key not in seen:
                    seen.add(key)
                    models.append((key[0], key[1], name))
    if not models:
        raise SystemExit("Parsed no CPU models; has Host.cpp changed?")
    return models


def render_cpu_models(models, commit):
    lines = [
        "// GENERATED FILE, DO NOT EDIT BY HAND.",
        "//",
        "// Source: llvm/llvm-project {} (commit {}), {}".format(LLVM_TAG, commit, HOST_PATH),
        "// getHostCPUNameForARMFromComponents(). Regenerate: {}".format(REGENERATE_COMMAND),
        "//",
        "// (MIDR implementer, part) -> LLVM -mcpu name. Parts are matched numerically (the source",
        "// spells some with and some without leading zeros). Variant-disambiguated parts (Samsung",
        "// Exynos) and big.LITTLE/SoC-name special cases are omitted; an unlisted pair gives \"\".",
        "static const struct {",
        "  unsigned implementer;",
        "  unsigned part;",
        "  const char *mcpu;",
        "} kAarch64CpuModels[] = {",
    ]
    lines += ['    {{0x{:02x}, 0x{:03x}, "{}"}},'.format(impl, part, name) for impl, part, name in models]
    lines.append("};")
    return "\n".join(lines) + "\n"


def render_list(name, values, descriptions=None):
    lines = ["{} = [".format(name)]
    for value in values:
        entry = '    "{}",'.format(value)
        desc = (descriptions or {}).get(value)
        if desc:
            entry += "  # {}".format(desc)
        lines.append(entry)
    lines.append("]")
    return "\n".join(lines)


def render_mattr_map(overrides):
    lines = ["AARCH64_MARCH_TO_MATTR = {"]
    lines += ['    "{}": "{}",'.format(token, overrides[token]) for token in sorted(overrides)]
    lines.append("}")
    return "\n".join(lines)


def render(features, versions, commit, descriptions, mattr_overrides):
    return "\n".join([
        "# GENERATED FILE, DO NOT EDIT BY HAND.",
        "#",
        "# Source: llvm/llvm-project {} (commit {}), {}".format(LLVM_TAG, commit, TD_PATH),
        "# Regenerate: {}".format(REGENERATE_COMMAND),
        "#",
        "# Update LLVM_TAG in cpu/aarch64/generate.py to move to a newer LLVM release.",
        "",
        'visibility(["//cpu/aarch64/...", "//private", "//tests"])',
        "",
        "# Public -march tokens of the architecture extensions (`UserVisibleName` where LLVM",
        "# overrides the target feature name), excluding the meta-alias `crypto`. The comment on each",
        '# is LLVM\'s description for the feature, with a leading "Enable" dropped.',
        render_list("AARCH64_FEATURES", features, descriptions),
        "",
        "# The LLVM target-feature (-mattr) name for each -march token where the two differ (the token",
        "# is LLVM's UserVisibleName; this is the TargetFeatureName). A consumer turning the feature",
        "# constraints into an -mattr / --target-feature string maps through this; a token not listed",
        "# here is already its own -mattr name.",
        render_mattr_map(mattr_overrides),
        "",
    ])


def main(argv):
    if len(argv) > 3:
        raise SystemExit("usage: generate.py [AArch64Features.td [Host.cpp]]")
    if len(argv) >= 2:
        with open(argv[1], encoding="utf-8") as f:
            text = f.read()
    else:
        text = fetch(TD_PATH)
    if len(argv) == 3:
        with open(argv[2], encoding="utf-8") as f:
            host_text = f.read()
    else:
        host_text = fetch(HOST_PATH)
    features, versions, descriptions, mattr_overrides = parse(text)
    models = parse_cpu_models(host_text)
    commit = resolve_commit()
    missing = [feature for feature in features if feature not in descriptions]
    if missing:
        print("warning: no description for: " + ", ".join(missing), file=sys.stderr)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write(render(features, versions, commit, descriptions, mattr_overrides))
    with open(CPU_MODELS_OUTPUT, "w", encoding="utf-8") as f:
        f.write(render_cpu_models(models, commit))
    print(
        "Wrote {}: {} features at {} (commit {})".format(OUTPUT, len(features), LLVM_TAG, commit)
    )
    print("Wrote {}: {} CPU models".format(CPU_MODELS_OUTPUT, len(models)))


if __name__ == "__main__":
    main(sys.argv)
