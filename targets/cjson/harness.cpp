#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>

#include "cJSON.h"

static bool env_enabled(const char* name) {
  const char* v = std::getenv(name);
  return v &&
         (std::strcmp(v, "1") == 0 ||
          std::strcmp(v, "true") == 0 ||
          std::strcmp(v, "TRUE") == 0);
}

static bool contains_demo_trigger(const char* buf) {
  return std::strstr(buf, "CRASHME") != nullptr;
}


static void trigger_demo_asan_use_after_free() {
  char* p = static_cast<char*>(std::malloc(8));
  if (!p) {
    return;
  }

  std::memset(p, 'A', 8);
  std::free(p);

  // Intentional use-after-free for demo/portfolio purposes.
  // Use a volatile pointer so the access is not optimized away.
  volatile char* vp = p;
  *vp = 'X';
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  // cJSON expects a null-terminated string, so keep the input deterministic.
  char* buf = static_cast<char*>(std::malloc(size + 1));
  if (!buf) {
    return 0;
  }

  if (size > 0) {
    std::memcpy(buf, data, size);
  }
  buf[size] = '\0';

  // Demo-only controlled crash path.
  // Enabled only when FUZZPIPE_DEMO_CRASH is set and the trigger token is present.
  if (env_enabled("FUZZPIPE_DEMO_CRASH") && contains_demo_trigger(buf)) {
    trigger_demo_asan_use_after_free();
    std::free(buf);
    return 0;
  }

  cJSON* root = cJSON_ParseWithLength(buf, size);
  if (root) {
    cJSON_Delete(root);
  }

  std::free(buf);
  return 0;
}