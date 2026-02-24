#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>

#include "cJSON.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  char* buf = (char*)malloc(size + 1);
  if (!buf) return 0;

  memcpy(buf, data, size);
  buf[size] = '\0';

  cJSON* root = cJSON_ParseWithLength(buf, size);
  if (root) {
    cJSON_Delete(root);
  }

  free(buf);
  return 0;
}