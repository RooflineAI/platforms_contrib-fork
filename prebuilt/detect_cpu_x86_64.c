// Prints each cpu_features name with "+" if available, "-" otherwise.
// Constraint mappings are in //private:feature_mapping.bzl.

#include <stdio.h>

#include "cpuinfo_x86.h"

int main(void) {
  const X86Info info = GetX86Info();
  for (int i = 0; i < X86_LAST_; ++i) {
    printf("%c%s\n",
           GetX86FeaturesEnumValue(&info.features, (X86FeaturesEnum)i) ? '+' : '-',
           GetX86FeaturesEnumName((X86FeaturesEnum)i));
  }
  return 0;
}
