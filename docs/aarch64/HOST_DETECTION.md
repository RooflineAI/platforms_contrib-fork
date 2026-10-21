# aarch64 host CPU detection

Status: **LLVM-free detector implemented; both paths built and run-verified on real hardware (Apple
Silicon and an Armv9 Arm Linux host); the axis is inert.** `prebuilt/detect_cpu_aarch64.cc` and
`//prebuilt:detect_cpu_aarch64` exist, but `//private:prebuilts.bzl`'s `PREBUILT_DETECTORS` has no
aarch64 entry, so `//host:native` does not do aarch64 detection yet. It stays inert until a prebuilts
release is cut from this repo and each binary run on real hardware per OS, because a detector that
reports a feature the hardware lacks makes `//host:native` claim that capability and miscompiles. See
"Remaining to activate".

## Verified on real hardware (the design proof + the testability win)

| Kind | Chip | Mechanism | SVE | SME | Detector status |
|---|---|---|---|---|---|
| Linux | Arm Cortex-A720-class (Armv9) | `cpu_features` (HWCAP) | **`sve` + `sve2` present** | none | **cross-compiled (static musl) and run on real hardware; emitted `sve`/`sve2` + SVE2 crypto, no `sme`** |
| Apple Silicon | Apple M4 Pro | sysctl `hw.optional.arm.FEAT_*` | **absent** | **`sme` + `sme2` present** | **the real file compiled (`clang -Wall -Wextra`) and ran; emitted `sme`/`sme2`, no `sve`** |

The M4 Pro is the textbook case, SME2 with no non-streaming SVE, which is why `sve*`/`sme*` are
independent constraints (no architecture version implies them). The Linux host
is the mirror image (SVE2, no SME), so the two ends together prove the orthogonality.

## Backends (no LLVM)

The detector emits `-march` tokens (`AARCH64_FEATURES`) and links no LLVM, so it builds in seconds on
any aarch64 host:

- **Linux:** Google `cpu_features` `GetAarch64Info()` (reads HWCAP via `getauxval`). This is the same
  kernel-sanitised set LLVM's `getHostCPUFeatures()` reads (both HWCAP-bounded), so no breadth is
  lost, but without linking LLVM. Dependency: `@cpu_features//:cpuinfo` (dev-only `bazel_dep`, BCR
  0.11.0).
- **macOS:** direct `hw.optional.arm.FEAT_*` sysctls. `cpu_features` is **not** used here: its Darwin
  backend (`impl_aarch64_macos_or_iphone.c`) stops at `FEAT_BTI` and never reads SVE/SME/wfxt/cssc/
  mops, so on an M4 Pro it would report `sme = 0`, missing the one feature that matters. This branch
  has no dependencies (sysctl only), which is why it compiles with a stock clang and was verifiable.

Dropping LLVM (over keeping it on Linux) was chosen for testability: the LLVM-linked design is exactly
why the detector had "never been built or run"; a `cpu_features`/sysctl binary builds and runs on the
real hosts with the shipping code.

## Verification status

- **macOS: verified.** The actual `detect_cpu_aarch64.cc` was compiled with `clang -std=c++17 -Wall
  -Wextra` on an Apple M4 Pro and run; output matched the chip (`sme`/`sme2`, no `sve`, plus the
  expected baseline/compute set). This is the shipping code path, not a stand-in.
- **Linux: verified.** The detector was cross-compiled (static musl, `@cpu_features//:cpuinfo`) and run
  on an Armv9 Arm Linux host (Cortex-A720-class); output matched the chip (`sve`/`sve2` + SVE2 crypto,
  no `sme`, plus the baseline/compute set), the mirror image of the M4 Pro. This is the shipping code
  path, not a stand-in.

## Remaining to activate

1. **Feature mapping.** DONE: `private/feature_mapping.bzl` has `aarch64_feature_constraint_names`,
   which validates the report's tokens against `AARCH64_FEATURES` and emits
   `//cpu/aarch64/feature:<token>_available`. (The detector emits tokens, so no name translation is
   needed Bazel-side.)
2. **Repository-rule dispatch.** DONE: `cpu_feature_constraints.bzl` dispatches on the host CPU and,
   for aarch64, uses this detector and the aarch64 mapping.
3. **Cross-compile wiring.** DONE: `cfg_variants.bzl` (`linux_aarch64`/`macos_aarch64`),
   `prebuilt/BUILD.bazel` (`for_*` in `for_all_platforms`), `prebuilts.yaml` (staging loop).
   `@cpu_features//:cpuinfo` is confirmed to cross-compile for `@llvm//platforms:linux_aarch64_musl`,
   and the macOS branch (no deps) for `macos_aarch64`; Windows on Arm is still deferred.
4. **Release (remaining).** Cut a `prebuilts-v*` release from this repo (the workflow builds
   `//prebuilt:for_linux_aarch64` and `//prebuilt:for_macos_aarch64`), run each binary on real
   hardware per OS, then paste the generated `(linux, aarch64)` and `(osx, aarch64)` entries into
   `prebuilts.bzl` and run `bazel mod tidy`. This is the only step left before `//host:native` does
   aarch64 detection. It has been run on real hardware already (`cortex-a720` on Linux, `apple-m4` on
   an M4 Pro); the entries just need a public release to point at.
5. **Model.** DONE: `prebuilt/aarch64_cpu_models.inc` (generated from LLVM's `getHostCPUNameForARM`)
   maps the Linux MIDR `(implementer, part)` to an `-mcpu` name; on macOS the `Apple M<N>` brand
   string maps to `apple-m<N>` (M1..M4). Verified on real hardware: `cortex-a720` on the Linux host,
   `apple-m4` on the M4 Pro. An unknown CPU stays empty.
6. **Test oracle (optional).** On a Linux aarch64 host, diff the detector's token set against
   `clang --print-enabled-extensions -march=native` to guard the `cpu_features`-field -> token map,
   since LLVM (`-march=native`) is the ground truth we stopped shipping.

## macOS coverage note

The sysctl table reads the newer `hw.optional.arm.FEAT_*` keys (macOS 12+). macOS 11 exposes older
`hw.optional.armv8_*` keys; add those as fallbacks if macOS 11 support is needed. Unlisted features are
not reported (conservative). Windows on Arm is unsupported.

## Do not

Do not add an aarch64 entry to `PREBUILT_DETECTORS` pointing at an unbuilt or untested binary. Add an
entry only after a released binary has been run on aarch64 hardware for that OS.
