//! Native Graphite surface: wrap a fun-owned WGPUTexture and flush recordings.
//! Compiled by tools/build_bridge.sh, not the default Zig stub module.

#include "internal.h"

#include "include/core/SkColorSpace.h"
#include "include/gpu/graphite/BackendTexture.h"
#include "include/gpu/graphite/GraphiteTypes.h"
#include "include/gpu/graphite/Recording.h"
#include "include/gpu/graphite/Surface.h"
#include "include/gpu/graphite/dawn/DawnGraphiteTypes.h"

#include <cstdio>
#include <new>
#include <string>

namespace {

thread_local char gInsertError[512];

bool descriptorTooSmall(const FGSurfaceDescriptor* descriptor) {
    return descriptor == nullptr ||
           descriptor->struct_size < sizeof(FGSurfaceDescriptor);
}

void setInsertError(FGError* out_error, const skgpu::graphite::InsertStatus& status) {
    const std::string& msg = status.message();
    if (msg.empty()) {
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "graphite insertRecording failed");
        return;
    }
    std::snprintf(gInsertError, sizeof(gInsertError), "%s", msg.c_str());
    fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, gInsertError);
}

} // namespace

extern "C" FGStatus fg_surface_wrap_texture(
    FGContext* context,
    const FGSurfaceDescriptor* descriptor,
    FGSurface** out_surface,
    FGError* out_error
) {
    if (out_surface != nullptr) *out_surface = nullptr;
    if (context == nullptr || context->recorder == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGContext is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    if (descriptorTooSmall(descriptor)) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT,
                   "FGSurfaceDescriptor is missing or too small");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    if (out_surface == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "out_surface is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    if (descriptor->texture == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "WGPUTexture is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    if (descriptor->width == 0 || descriptor->height == 0) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "surface width/height must be > 0");
        return FG_STATUS_INVALID_ARGUMENT;
    }

    const skgpu::graphite::BackendTexture backend =
        skgpu::graphite::BackendTextures::MakeDawn(descriptor->texture);
    if (!backend.isValid()) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "BackendTextures::MakeDawn failed");
        return FG_STATUS_INVALID_ARGUMENT;
    }

    const SkISize dims = backend.dimensions();
    if (dims.fWidth != static_cast<int32_t>(descriptor->width) ||
        dims.fHeight != static_cast<int32_t>(descriptor->height)) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT,
                   "surface descriptor size does not match WGPUTexture");
        return FG_STATUS_INVALID_ARGUMENT;
    }

    sk_sp<SkSurface> sk_surface = SkSurfaces::WrapBackendTexture(
        context->recorder.get(),
        backend,
        SkColorSpace::MakeSRGB(),
        nullptr,
        nullptr,
        nullptr,
        "fun-graphics-surface");
    if (!sk_surface) {
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "SkSurfaces::WrapBackendTexture failed");
        return FG_STATUS_INTERNAL_ERROR;
    }

    auto* surface = new (std::nothrow) FGSurface();
    if (surface == nullptr) {
        fgSetError(out_error, FG_STATUS_OUT_OF_MEMORY, "FGSurface allocation failed");
        return FG_STATUS_OUT_OF_MEMORY;
    }
    surface->context = context;
    surface->surface = std::move(sk_surface);
    surface->canvas.sk = surface->surface->getCanvas();
    surface->canvas.fill.setAntiAlias(true);
    surface->canvas.fill.setStyle(SkPaint::kFill_Style);
    *out_surface = surface;
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" FGCanvas* fg_surface_get_canvas(FGSurface* surface) {
    if (surface == nullptr || !surface->surface) return nullptr;
    return &surface->canvas;
}

extern "C" FGStatus fg_surface_flush(FGSurface* surface, FGError* out_error) {
    if (surface == nullptr || surface->context == nullptr ||
        surface->context->recorder == nullptr || surface->context->graphite == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "FGSurface is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }

    std::unique_ptr<skgpu::graphite::Recording> recording = surface->context->recorder->snap();
    if (!recording) {
        fgSetError(out_error, FG_STATUS_OK, nullptr);
        return FG_STATUS_OK;
    }

    skgpu::graphite::InsertRecordingInfo info;
    info.fRecording = recording.get();
    const skgpu::graphite::InsertStatus status = surface->context->graphite->insertRecording(info);
    if (!status) {
        setInsertError(out_error, status);
        return FG_STATUS_INTERNAL_ERROR;
    }

    if (!surface->context->graphite->submit()) {
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "graphite submit failed");
        return FG_STATUS_INTERNAL_ERROR;
    }

    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" void fg_surface_destroy(FGSurface* surface) {
    if (surface != nullptr) {
        fgDropExtra(&surface->canvas);
    }
    delete surface;
}
