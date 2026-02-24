#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>

#include "cJSON.h"

static bool env_enabled(const char* name) {
  const char* v = std::getenv(name);
  return v && (std::strcmp(v, "1") == 0 || std::strcmp(v, "true") == 0 || std::strcmp(v, "TRUE") == 0);
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  // cJSON expects a null-terminated string (we keep it deterministic)
  char* buf = (char*)std::malloc(size + 1);
  if (!buf) return 0;

  if (size > 0) std::memcpy(buf, data, size);
  buf[size] = '\0';

  // DEMO CRASH (controlled): only if explicitly enabled via env var
  if (env_enabled("FUZZPIPE_DEMO_CRASH")) {
    const char* needle = "CRASHME";
    if (std::strstr(buf, needle) != nullptr) {
      std::abort();
    }
  }

  cJSON* root = cJSON_ParseWithLength(buf, size);
  if (root) cJSON_Delete(root);

  std::free(buf);
  return 0;
}