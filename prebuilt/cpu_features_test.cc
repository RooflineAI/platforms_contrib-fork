#include "cpu_features.h"

#include "clang/Basic/Diagnostic.h"
#include "clang/Basic/TargetInfo.h"
#include "clang/Basic/TargetOptions.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TargetParser/Host.h"
#include "llvm/TargetParser/X86TargetParser.h"

#include <cstdlib>
#include <map>
#include <memory>
#include <string>
#include <vector>

static void check(bool ok, const std::string &message) {
  if (!ok) {
    llvm::errs() << message << '\n';
    std::exit(1);
  }
}

using platforms_contrib::CpuidRegisters;
static std::map<std::pair<unsigned, unsigned>, CpuidRegisters> leaves;

static CpuidRegisters cpuid(unsigned leaf, unsigned subleaf) {
  auto it = leaves.find({leaf, subleaf});
  check(it != leaves.end(), "queried an unsupported CPUID leaf or subleaf");
  return it->second;
}

static void testExtras() {
  leaves = {{{0, 0}, {}}, {{0x80000000, 0}, {}}};
  for (const auto &feature : platforms_contrib::extraFeatures(cpuid))
    check(!feature.getValue(), "unsupported CPUID leaves must report false");

  leaves[{0, 0}].eax = 7;
  leaves[{7, 0}] = {0, 1U << 9, 0, 1U << 4};
  auto extras = platforms_contrib::extraFeatures(cpuid);
  check(extras.lookup("ermsb") && extras.lookup("fsrm"), "leaf 7.0 flags");
  check(!extras.lookup("fzrm"), "leaf 7.1 must be guarded by leaf 7.0 EAX");

  leaves[{7, 0}].eax = 1;
  leaves[{7, 1}].eax = (1U << 10) | (1U << 11) | (1U << 12);
  leaves[{0x80000000, 0}].eax = 0x80000001;
  leaves[{0x80000001, 0}].edx = 1U << 27;
  for (const auto &feature : platforms_contrib::extraFeatures(cpuid))
    check(feature.getValue(),
          "missing CPUID feature: " + feature.getKey().str());
}

int main(int argc, char **argv) {
  testExtras();
  llvm::StringMap<bool> inventory;
  for (int i = 1; i < argc; ++i)
    inventory[argv[i]] = false;
  check(inventory.size() > 100,
        "pass the Starlark feature inventory as arguments");
  inventory["cx8"] = true;
  inventory["cmov"] = true;
  inventory["64bit"] = true;

#if defined(__x86_64__) || defined(_M_X64)
  auto host = llvm::sys::getHostCPUFeatures();
  auto resolved = platforms_contrib::resolveFeatures(host);
  for (const auto &feature : inventory)
    check(resolved.contains(feature.getKey()),
          "LLVM omitted " + feature.getKey().str());
  for (const auto &feature : resolved)
    check(inventory.contains(feature.getKey()),
          "undeclared LLVM feature: " + feature.getKey().str());
#endif

  clang::DiagnosticOptions diagnosticOptions;
  clang::DiagnosticsEngine diagnostics(new clang::DiagnosticIDs,
                                       diagnosticOptions);
  llvm::SmallVector<llvm::StringRef> cpus;
  llvm::X86::fillValidCPUArchList(cpus, true);
  for (auto triple : {"x86_64-unknown-linux-gnu", "x86_64-pc-windows-msvc",
                      "x86_64-apple-darwin"}) {
    for (auto cpu : cpus) {
      llvm::SmallVector<llvm::StringRef> defaults;
      llvm::X86::getFeaturesForCPU(cpu, defaults);
      auto raw = inventory;
      raw.erase("x87");
      for (auto feature : defaults) {
        check(inventory.contains(feature),
              "CPU default missing from inventory: " + feature.str());
        if (feature != "x87")
          raw[feature] = true;
      }
      clang::TargetOptions options;
      options.Triple = triple;
      options.CPU = cpu.str();
      std::unique_ptr<clang::TargetInfo> target(
          clang::TargetInfo::CreateTargetInfo(diagnostics, options));
      check(bool(target), "create target for " + cpu.str());
      for (int scenario = 0; scenario < 4; ++scenario) {
        if (scenario == 1) {
          raw["avx"] = false;
          raw["avx512f"] = false;
          raw["xsave"] = false;
        } else if (scenario == 2) {
          raw["avx10.1"] = true;
          raw["avx10.2"] = true;
          raw["sha512"] = true;
        } else if (scenario == 3) {
          raw["mmx"] = false;
          raw["sse"] = false;
          raw["sse2"] = false;
        }
        std::vector<std::string> flags;
        for (const auto &feature : raw)
          flags.push_back((feature.getValue() ? "+" : "-") +
                          feature.getKey().str());
        llvm::StringMap<bool> native;
        check(target->initFeatureMap(native, diagnostics, cpu, flags),
              "native feature map");
        auto effective = platforms_contrib::resolveFeatures(raw);
        for (const auto &feature : inventory) {
          auto name = feature.getKey();
          if (name == "64bit")
            continue;
          check(native.lookup(name) == effective.lookup(name),
                cpu.str() + ": " + name.str() + " differs from Clang");
        }

        flags.clear();
        for (bool enabled : {true, false})
          for (int i = 1; i < argc; ++i)
            if (effective.lookup(argv[i]) == enabled)
              flags.push_back((enabled ? "+" : "-") + std::string(argv[i]));
        llvm::StringMap<bool> replay;
        check(target->initFeatureMap(replay, diagnostics, "x86-64", flags),
              "replayed feature map");
        for (const auto &feature : inventory) {
          if (feature.getKey() == "64bit")
            continue;
          check(replay.lookup(feature.getKey()) ==
                    effective.lookup(feature.getKey()),
                cpu.str() + ": replay changed " + feature.getKey().str());
        }
      }
    }
  }
  return 0;
}
