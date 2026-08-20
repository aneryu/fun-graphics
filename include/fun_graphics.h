#ifndef FUN_GRAPHICS_H
#define FUN_GRAPHICS_H

//! Skia Graphite C ABI. Zig and fun must not see Skia C++ types.
//! See docs/graphics.md §6 in the fun repository.

#include <stdint.h>
#include <webgpu/webgpu.h>

#ifdef __cplusplus
extern "C" {
#endif

#define FG_API_VERSION 1

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

FGStatus fg_canvas_fill_rect(
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

#ifdef __cplusplus
} // extern "C"
#endif

#endif
