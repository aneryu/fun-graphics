//! Shared native Graphite types. Compiled only into the native bridge archive.
//! Zig / fun must not include this header. See fun docs/graphics.md §6 / §18.

#pragma once

#include "canvas_runtime.h"

#include "include/gpu/graphite/Context.h"
#include "include/gpu/graphite/Recorder.h"
#include "webgpu/webgpu_cpp.h"

#include <memory>

struct FGContext {
    wgpu::Instance instance;
    wgpu::Device device;
    wgpu::Queue queue;
    std::unique_ptr<skgpu::graphite::Context> graphite;
    std::unique_ptr<skgpu::graphite::Recorder> recorder;
};
