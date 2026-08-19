#include "fun_graphics.h"
#include <cstddef>

namespace {

constexpr char kBuildId[] = "stub";
constexpr char kSkiaCommit[] = "unpinned";
constexpr char kDawnCommit[] = "unpinned";

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
