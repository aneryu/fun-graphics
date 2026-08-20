//! Shared native Graphite types. Compiled only into the native bridge archive.
//! Zig / fun must not include this header. See fun docs/graphics.md §6.

#pragma once

#include "fun_graphics.h"

#include "include/core/SkCanvas.h"
#include "include/core/SkPaint.h"
#include "include/core/SkSurface.h"
#include "include/gpu/graphite/Context.h"
#include "include/gpu/graphite/Recorder.h"
#include "webgpu/webgpu_cpp.h"

#include <cstdint>
#include <cstring>
#include <memory>

struct FGContext {
    wgpu::Instance instance;
    wgpu::Device device;
    wgpu::Queue queue;
    std::unique_ptr<skgpu::graphite::Context> graphite;
    std::unique_ptr<skgpu::graphite::Recorder> recorder;
};

struct FGCanvas {
    SkCanvas* sk = nullptr;
    SkPaint fill;
};

struct FGSurface {
    FGContext* context = nullptr;
    sk_sp<SkSurface> surface;
    FGCanvas canvas;
};

inline void fgSetError(FGError* out_error, FGStatus code, const char* message) {
    if (out_error == nullptr) return;
    out_error->code = code;
    out_error->message = message;
    out_error->message_length = message == nullptr
        ? 0
        : static_cast<uint32_t>(std::strlen(message));
}
