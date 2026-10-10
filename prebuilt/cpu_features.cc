#include "cpu_features.h"

#include "llvm/TargetParser/X86TargetParser.h"

namespace platforms_contrib {

llvm::StringMap<bool> resolveFeatures(const llvm::StringMap<bool> &host) {
  llvm::StringMap<bool> resolved;
  // Preserve Clang's native flag order when resolving implications.
  for (const auto &feature : host) {
    resolved[feature.getKey()] = feature.getValue();
    llvm::X86::updateImpliedFeatures(feature.getKey(), feature.getValue(),
                                     resolved);
  }

  // LLVM omits x87 from its host map.
  resolved["x87"] = true;
  return resolved;
}

llvm::StringMap<bool> extraFeatures(Cpuid cpuid) {
  CpuidRegisters leaf7, subleaf1, extended;
  if (cpuid(0, 0).eax >= 7) {
    leaf7 = cpuid(7, 0);
    if (leaf7.eax >= 1)
      subleaf1 = cpuid(7, 1);
  }
  if (cpuid(0x80000000, 0).eax >= 0x80000001)
    extended = cpuid(0x80000001, 0);

  return {
      {"ermsb", bool(leaf7.ebx & (1U << 9))},
      {"fsrm", bool(leaf7.edx & (1U << 4))},
      {"fzrm", bool(subleaf1.eax & (1U << 10))},
      {"fsrs", bool(subleaf1.eax & (1U << 11))},
      {"fsrc", bool(subleaf1.eax & (1U << 12))},
      {"rdtscp", bool(extended.edx & (1U << 27))},
  };
}

} // namespace platforms_contrib
