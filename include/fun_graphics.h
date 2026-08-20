#ifndef FUN_GRAPHICS_H
#define FUN_GRAPHICS_H

//! Skia Graphite C ABI. Zig and fun must not see Skia C++ types.
//! See docs/graphics.md §6 / §18 in the fun repository.

#include <stdint.h>
#include <webgpu/webgpu.h>

#ifdef __cplusplus
extern "C" {
#endif

#define FG_API_VERSION 2

typedef struct FGContext FGContext;
typedef struct FGSurface FGSurface;
typedef struct FGCanvas FGCanvas;
typedef struct FGPath FGPath;
typedef struct FGImage FGImage;
typedef struct FGGradient FGGradient;
typedef struct FGPattern FGPattern;

typedef enum FGStatus {
    FG_STATUS_OK = 0,
    FG_STATUS_INVALID_ARGUMENT,
    FG_STATUS_OUT_OF_MEMORY,
    FG_STATUS_DEVICE_LOST,
    FG_STATUS_INTERNAL_ERROR
} FGStatus;

typedef struct FGError {
    FGStatus code;
    const char* message;
    uint32_t message_length;
} FGError;

typedef struct FGBuildInfo {
    uint32_t api_version;
    const char* build_id;
    const char* skia_commit;
    const char* dawn_commit;
} FGBuildInfo;

const FGBuildInfo* fg_get_build_info(void);

typedef struct FGContextDescriptor {
    uint32_t struct_size;
    WGPUInstance instance;
    WGPUDevice device;
    WGPUQueue queue;
} FGContextDescriptor;

FGStatus fg_context_create(
    const FGContextDescriptor* descriptor,
    FGContext** out_context,
    FGError* out_error
);

void fg_context_destroy(FGContext* context);

typedef struct FGSurfaceDescriptor {
    uint32_t struct_size;
    WGPUTexture texture;
    WGPUTextureFormat format;
    uint32_t width;
    uint32_t height;
    uint32_t sample_count;
} FGSurfaceDescriptor;

FGStatus fg_surface_wrap_texture(
    FGContext* context,
    const FGSurfaceDescriptor* descriptor,
    FGSurface** out_surface,
    FGError* out_error
);

FGCanvas* fg_surface_get_canvas(FGSurface* surface);

FGStatus fg_surface_flush(
    FGSurface* surface,
    FGError* out_error
);

void fg_surface_destroy(FGSurface* surface);

void fg_canvas_set_fill_style_rgba(
    FGCanvas* canvas,
    float r,
    float g,
    float b,
    float a
);

void fg_canvas_set_stroke_style_rgba(
    FGCanvas* canvas,
    float r,
    float g,
    float b,
    float a
);

void fg_canvas_set_line_width(FGCanvas* canvas, float width);

void fg_canvas_set_line_cap(FGCanvas* canvas, uint32_t cap);
void fg_canvas_set_line_join(FGCanvas* canvas, uint32_t join);
void fg_canvas_set_miter_limit(FGCanvas* canvas, float limit);
void fg_canvas_set_global_alpha(FGCanvas* canvas, float alpha);

void fg_canvas_set_line_dash(
    FGCanvas* canvas,
    const float* dashes,
    uint32_t dash_count,
    float offset
);

FGStatus fg_canvas_fill_rect(
    FGCanvas* canvas,
    float x,
    float y,
    float w,
    float h,
    FGError* out_error
);

FGStatus fg_canvas_stroke_rect(
    FGCanvas* canvas,
    float x,
    float y,
    float w,
    float h,
    FGError* out_error
);

FGStatus fg_canvas_clear(
    FGCanvas* canvas,
    float r,
    float g,
    float b,
    float a,
    FGError* out_error
);

FGStatus fg_canvas_clear_rect(
    FGCanvas* canvas,
    float x,
    float y,
    float w,
    float h,
    FGError* out_error
);

void fg_canvas_save(FGCanvas* canvas);
void fg_canvas_restore(FGCanvas* canvas);

void fg_canvas_set_transform(
    FGCanvas* canvas,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
);

void fg_canvas_transform(
    FGCanvas* canvas,
    float a,
    float b,
    float c,
    float d,
    float e,
    float f
);

void fg_canvas_translate(FGCanvas* canvas, float x, float y);
void fg_canvas_rotate(FGCanvas* canvas, float radians);
void fg_canvas_scale(FGCanvas* canvas, float x, float y);

void fg_canvas_begin_path(FGCanvas* canvas);
void fg_canvas_close_path(FGCanvas* canvas);
void fg_canvas_move_to(FGCanvas* canvas, float x, float y);
void fg_canvas_line_to(FGCanvas* canvas, float x, float y);
void fg_canvas_quadratic_curve_to(
    FGCanvas* canvas,
    float cpx,
    float cpy,
    float x,
    float y
);
void fg_canvas_bezier_curve_to(
    FGCanvas* canvas,
    float cp1x,
    float cp1y,
    float cp2x,
    float cp2y,
    float x,
    float y
);
void fg_canvas_arc(
    FGCanvas* canvas,
    float x,
    float y,
    float radius,
    float start_angle,
    float end_angle,
    uint32_t counterclockwise
);
void fg_canvas_rect(FGCanvas* canvas, float x, float y, float w, float h);

FGStatus fg_canvas_fill(FGCanvas* canvas, FGError* out_error);
FGStatus fg_canvas_stroke(FGCanvas* canvas, FGError* out_error);
FGStatus fg_canvas_clip(FGCanvas* canvas, FGError* out_error);

void fg_canvas_set_font(
    FGCanvas* canvas,
    float size_px,
    uint32_t weight,
    uint32_t italic,
    const char* family,
    uint32_t family_len
);

void fg_canvas_set_text_align(FGCanvas* canvas, uint32_t align);
void fg_canvas_set_text_baseline(FGCanvas* canvas, uint32_t baseline);

FGStatus fg_canvas_fill_text(
    FGCanvas* canvas,
    const char* utf8,
    uint32_t utf8_len,
    float x,
    float y,
    float max_width,
    FGError* out_error
);

typedef struct FGTextMetrics {
    float width;
    float actual_bounding_box_left;
    float actual_bounding_box_right;
    float actual_bounding_box_ascent;
    float actual_bounding_box_descent;
} FGTextMetrics;

FGStatus fg_canvas_measure_text(
    FGCanvas* canvas,
    const char* utf8,
    uint32_t utf8_len,
    FGTextMetrics* out_metrics,
    FGError* out_error
);

FGStatus fg_canvas_draw_image_rgba8(
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
);

FGStatus fg_surface_draw_surface(
    FGSurface* dst,
    FGSurface* src,
    float alpha,
    FGError* out_error
);

/** Draw a rectangle of `src` onto `dst`'s canvas (respects dst CTM). */
FGStatus fg_canvas_draw_surface_image(
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
);

FGStatus fg_image_decode_rgba8(
    const uint8_t* encoded,
    uint32_t encoded_len,
    uint8_t** out_pixels,
    uint32_t* out_width,
    uint32_t* out_height,
    FGError* out_error
);

void fg_image_pixels_free(uint8_t* pixels);

#ifdef __cplusplus
} // extern "C"
#endif

#endif
