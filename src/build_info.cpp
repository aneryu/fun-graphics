#include "fun_graphics.h"
#include <cstddef>

#ifndef FUN_GRAPHICS_BUILD_ID
#define FUN_GRAPHICS_BUILD_ID "stub"
#endif
#ifndef FUN_GRAPHICS_SKIA_COMMIT
#define FUN_GRAPHICS_SKIA_COMMIT "unpinned"
#endif
#ifndef FUN_GRAPHICS_DAWN_COMMIT
#define FUN_GRAPHICS_DAWN_COMMIT "unpinned"
#endif

namespace {

constexpr char kBuildId[] = FUN_GRAPHICS_BUILD_ID;
constexpr char kSkiaCommit[] = FUN_GRAPHICS_SKIA_COMMIT;
constexpr char kDawnCommit[] = FUN_GRAPHICS_DAWN_COMMIT;

const FGBuildInfo kBuildInfo = {
    FG_API_VERSION,
    kBuildId,
    kSkiaCommit,
    kDawnCommit,
};

} // namespace

extern "C" const FGBuildInfo* fg_get_build_info(void) {
    return &kBuildInfo;
}
