#include "cpu_features.h"

#include "llvm/Config/llvm-config.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TargetParser/Host.h"

#include <cpuid.h>
#include <utility>

static platforms_contrib::CpuidRegisters cpuid(unsigned leaf,
                                               unsigned subleaf) {
  platforms_contrib::CpuidRegisters r;
  __cpuid_count(leaf, subleaf, r.eax, r.ebx, r.ecx, r.edx);
  return r;
}

static llvm::json::Object toJson(const llvm::StringMap<bool> &features) {
  llvm::json::Object result;
  for (const auto &feature : features)
    result[feature.getKey()] = feature.getValue();
  return result;
}

int main() {
  const auto host = llvm::sys::getHostCPUFeatures();
  if (host.empty()) {
    llvm::errs() << "LLVM could not detect the host CPU features\n";
    return 1;
  }
  llvm::outs()
      << llvm::json::Value(llvm::json::Object{
             {"schema", 1},
             {"llvm_version", LLVM_VERSION_STRING},
             {"cpu", llvm::sys::getHostCPUName()},
             {"features", toJson(platforms_contrib::resolveFeatures(host))},
             {"extras", toJson(platforms_contrib::extraFeatures(cpuid))},
         })
      << '\n';
}
