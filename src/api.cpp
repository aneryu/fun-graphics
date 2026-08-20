//! Stub Graphite C ABI used by the default Zig module (no Dawn/Skia).
//! Native implementations live in graphite_context.cpp / surface.cpp / canvas*.cpp.

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

extern "C" void fg_canvas_set_fill_style_rgba(FGCanvas* canvas, float r, float g, float b, float a) {
    (void)canvas; (void)r; (void)g; (void)b; (void)a;
}
extern "C" void fg_canvas_set_stroke_style_rgba(FGCanvas* canvas, float r, float g, float b, float a) {
    (void)canvas; (void)r; (void)g; (void)b; (void)a;
}
extern "C" void fg_canvas_set_line_width(FGCanvas* canvas, float width) { (void)canvas; (void)width; }
extern "C" void fg_canvas_set_line_cap(FGCanvas* canvas, uint32_t cap) { (void)canvas; (void)cap; }
extern "C" void fg_canvas_set_line_join(FGCanvas* canvas, uint32_t join) { (void)canvas; (void)join; }
extern "C" void fg_canvas_set_miter_limit(FGCanvas* canvas, float limit) { (void)canvas; (void)limit; }
extern "C" void fg_canvas_set_global_alpha(FGCanvas* canvas, float alpha) { (void)canvas; (void)alpha; }
extern "C" void fg_canvas_set_line_dash(FGCanvas* canvas, const float* dashes, uint32_t dash_count, float offset) {
    (void)canvas; (void)dashes; (void)dash_count; (void)offset;
}

extern "C" FGStatus fg_canvas_fill_rect(FGCanvas* canvas, float x, float y, float w, float h, FGError* out_error) {
    (void)canvas; (void)x; (void)y; (void)w; (void)h;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}
extern "C" FGStatus fg_canvas_stroke_rect(FGCanvas* canvas, float x, float y, float w, float h, FGError* out_error) {
    (void)canvas; (void)x; (void)y; (void)w; (void)h;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}
extern "C" FGStatus fg_canvas_clear(FGCanvas* canvas, float r, float g, float b, float a, FGError* out_error) {
    (void)canvas; (void)r; (void)g; (void)b; (void)a;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}
extern "C" FGStatus fg_canvas_clear_rect(FGCanvas* canvas, float x, float y, float w, float h, FGError* out_error) {
    (void)canvas; (void)x; (void)y; (void)w; (void)h;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" void fg_canvas_save(FGCanvas* canvas) { (void)canvas; }
extern "C" void fg_canvas_restore(FGCanvas* canvas) { (void)canvas; }
extern "C" void fg_canvas_set_transform(FGCanvas* canvas, float a, float b, float c, float d, float e, float f) {
    (void)canvas; (void)a; (void)b; (void)c; (void)d; (void)e; (void)f;
}
extern "C" void fg_canvas_transform(FGCanvas* canvas, float a, float b, float c, float d, float e, float f) {
    (void)canvas; (void)a; (void)b; (void)c; (void)d; (void)e; (void)f;
}
extern "C" void fg_canvas_translate(FGCanvas* canvas, float x, float y) { (void)canvas; (void)x; (void)y; }
extern "C" void fg_canvas_rotate(FGCanvas* canvas, float radians) { (void)canvas; (void)radians; }
extern "C" void fg_canvas_scale(FGCanvas* canvas, float x, float y) { (void)canvas; (void)x; (void)y; }

extern "C" void fg_canvas_begin_path(FGCanvas* canvas) { (void)canvas; }
extern "C" void fg_canvas_close_path(FGCanvas* canvas) { (void)canvas; }
extern "C" void fg_canvas_move_to(FGCanvas* canvas, float x, float y) { (void)canvas; (void)x; (void)y; }
extern "C" void fg_canvas_line_to(FGCanvas* canvas, float x, float y) { (void)canvas; (void)x; (void)y; }
extern "C" void fg_canvas_quadratic_curve_to(FGCanvas* canvas, float cpx, float cpy, float x, float y) {
    (void)canvas; (void)cpx; (void)cpy; (void)x; (void)y;
}
extern "C" void fg_canvas_bezier_curve_to(
    FGCanvas* canvas, float cp1x, float cp1y, float cp2x, float cp2y, float x, float y
) {
    (void)canvas; (void)cp1x; (void)cp1y; (void)cp2x; (void)cp2y; (void)x; (void)y;
}
extern "C" void fg_canvas_arc(
    FGCanvas* canvas, float x, float y, float radius, float start_angle, float end_angle, uint32_t counterclockwise
) {
    (void)canvas; (void)x; (void)y; (void)radius; (void)start_angle; (void)end_angle; (void)counterclockwise;
}
extern "C" void fg_canvas_rect(FGCanvas* canvas, float x, float y, float w, float h) {
    (void)canvas; (void)x; (void)y; (void)w; (void)h;
}
extern "C" FGStatus fg_canvas_fill(FGCanvas* canvas, FGError* out_error) {
    (void)canvas;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}
extern "C" FGStatus fg_canvas_stroke(FGCanvas* canvas, FGError* out_error) {
    (void)canvas;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}
extern "C" FGStatus fg_canvas_clip(FGCanvas* canvas, FGError* out_error) {
    (void)canvas;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" void fg_canvas_set_font(
    FGCanvas* canvas, float size_px, uint32_t weight, uint32_t italic, const char* family, uint32_t family_len
) {
    (void)canvas; (void)size_px; (void)weight; (void)italic; (void)family; (void)family_len;
}
extern "C" void fg_canvas_set_text_align(FGCanvas* canvas, uint32_t align) { (void)canvas; (void)align; }
extern "C" void fg_canvas_set_text_baseline(FGCanvas* canvas, uint32_t baseline) { (void)canvas; (void)baseline; }
extern "C" FGStatus fg_canvas_fill_text(
    FGCanvas* canvas, const char* utf8, uint32_t utf8_len, float x, float y, float max_width, FGError* out_error
) {
    (void)canvas; (void)utf8; (void)utf8_len; (void)x; (void)y; (void)max_width;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}
extern "C" FGStatus fg_canvas_measure_text(
    FGCanvas* canvas, const char* utf8, uint32_t utf8_len, FGTextMetrics* out_metrics, FGError* out_error
) {
    (void)canvas; (void)utf8; (void)utf8_len;
    if (out_metrics != nullptr) *out_metrics = {};
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" FGStatus fg_canvas_draw_image_rgba8(
    FGCanvas* canvas,
    const uint8_t* pixels,
    uint32_t src_w,
    uint32_t src_h,
    float sx,
    float sy,
    float sw,
    float sh,
    float dx,
    float dy,
    float dw,
    float dh,
    FGError* out_error
) {
    (void)canvas; (void)pixels; (void)src_w; (void)src_h;
    (void)sx; (void)sy; (void)sw; (void)sh; (void)dx; (void)dy; (void)dw; (void)dh;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" FGStatus fg_surface_draw_surface(
    FGSurface* dst,
    FGSurface* src,
    float alpha,
    FGError* out_error
) {
    (void)dst; (void)src; (void)alpha;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" FGStatus fg_canvas_draw_surface_image(
    FGCanvas* dst,
    FGSurface* src,
    float sx,
    float sy,
    float sw,
    float sh,
    float dx,
    float dy,
    float dw,
    float dh,
    FGError* out_error
) {
    (void)dst; (void)src;
    (void)sx; (void)sy; (void)sw; (void)sh; (void)dx; (void)dy; (void)dw; (void)dh;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" FGStatus fg_image_decode_rgba8(
    const uint8_t* encoded,
    uint32_t encoded_len,
    uint8_t** out_pixels,
    uint32_t* out_width,
    uint32_t* out_height,
    FGError* out_error
) {
    (void)encoded; (void)encoded_len;
    if (out_pixels != nullptr) *out_pixels = nullptr;
    if (out_width != nullptr) *out_width = 0;
    if (out_height != nullptr) *out_height = 0;
    setError(out_error, FG_STATUS_INTERNAL_ERROR, kNativeNotBuilt);
    return FG_STATUS_INTERNAL_ERROR;
}

extern "C" void fg_image_pixels_free(uint8_t* pixels) {
    (void)pixels;
}
