//! Stub Graphite C ABI used by the default Zig module (no Dawn/Skia).
//! Native implementations live in graphite_context.cpp / surface.cpp.

#include "fun_graphics.h"

#include <cstddef>
#include <cstring>

namespace {

void setError(FGError* out_error, FGStatus code, const char* message) {
    if (out_error == nullptr) return;
    out_error->code = code;
    out_error->message = message;
    out_error->message_length = message == nullptr
        ? 0
        : static_cast<uint32_t>(std::strlen(message));
}

const char kNativeNotBuilt[] =
    "native graphics not built: Dawn/Skia archives are not present; "
    "run `zig build native` in fun-graphics after pinning deps/versions.zig";

} // namespace

extern "C" FGStatus fg_context_create(
    const FGContextDescriptor* descriptor,
    FGContext** out_context,
    FGError* out_error
) {
    if (out_context != nullptr) *out_context = nullptr;
    if (descriptor == nullptr || descriptor->struct_size < sizeof(FGContextDescriptor)) {
        setError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGContextDescriptor is missing or too small");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" void fg_context_destroy(FGContext* context) {
    (void)context;
}

extern "C" FGStatus fg_surface_wrap_texture(
    FGContext* context,
    const FGSurfaceDescriptor* descriptor,
    FGSurface** out_surface,
    FGError* out_error
) {
    if (out_surface != nullptr) *out_surface = nullptr;
    (void)context;
    (void)descriptor;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" FGCanvas* fg_surface_get_canvas(FGSurface* surface) {
    (void)surface;
    return nullptr;
}

extern "C" FGStatus fg_surface_flush(FGSurface* surface, FGError* out_error) {
    (void)surface;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" void fg_surface_destroy(FGSurface* surface) {
    (void)surface;
}

extern "C" void fg_canvas_set_fill_style_rgba(
    FGCanvas* canvas,
    float r,
    float g,
    float b,
    float a
) {
    (void)canvas;
    (void)r;
    (void)g;
    (void)b;
    (void)a;
}

extern "C" FGStatus fg_canvas_fill_rect(
    FGCanvas* canvas,
    float x,
    float y,
    float w,
    float h,
    FGError* out_error
) {
    (void)canvas;
    (void)x;
    (void)y;
    (void)w;
    (void)h;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" FGStatus fg_canvas_clear(
    FGCanvas* canvas,
    float r,
    float g,
    float b,
    float a,
    FGError* out_error
) {
    (void)canvas;
    (void)r;
    (void)g;
    (void)b;
    (void)a;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}
