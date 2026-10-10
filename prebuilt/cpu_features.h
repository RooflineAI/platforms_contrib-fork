#ifndef PLATFORMS_CONTRIB_PREBUILT_CPU_FEATURES_H_
#define PLATFORMS_CONTRIB_PREBUILT_CPU_FEATURES_H_

#include "llvm/ADT/StringMap.h"

namespace platforms_contrib {

llvm::StringMap<bool> resolveFeatures(const llvm::StringMap<bool> &host);

struct CpuidRegisters {
  unsigned eax = 0, ebx = 0, ecx = 0, edx = 0;
};
using Cpuid = CpuidRegisters (*)(unsigned leaf, unsigned subleaf);
llvm::StringMap<bool> extraFeatures(Cpuid cpuid);

} // namespace platforms_contrib

#endif
