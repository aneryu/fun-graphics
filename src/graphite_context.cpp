//! Native Graphite context: wrap fun-owned Dawn Instance/Device/Queue.
//! Compiled by tools/build_bridge.sh, not the default Zig stub module.

#include "internal.h"

#include "include/gpu/graphite/ContextOptions.h"
#include "include/gpu/graphite/dawn/DawnBackendContext.h"

#include <new>

namespace {

bool descriptorTooSmall(const FGContextDescriptor* descriptor) {
    return descriptor == nullptr ||
           descriptor->struct_size < sizeof(FGContextDescriptor);
}

} // namespace

extern "C" FGStatus fg_context_create(
    const FGContextDescriptor* descriptor,
    FGContext** out_context,
    FGError* out_error
) {
    if (out_context != nullptr) *out_context = nullptr;
    if (descriptorTooSmall(descriptor)) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT,
                   "FGContextDescriptor is missing or too small");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    if (out_context == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT, "out_context is null");
        return FG_STATUS_INVALID_ARGUMENT;
    }
    if (descriptor->instance == nullptr ||
        descriptor->device == nullptr ||
        descriptor->queue == nullptr) {
        fgSetError(out_error, FG_STATUS_INVALID_ARGUMENT,
                   "FGContextDescriptor requires instance, device, and queue");
        return FG_STATUS_INVALID_ARGUMENT;
    }

    auto* ctx = new (std::nothrow) FGContext();
    if (ctx == nullptr) {
        fgSetError(out_error, FG_STATUS_OUT_OF_MEMORY, "FGContext allocation failed");
        return FG_STATUS_OUT_OF_MEMORY;
    }

    // wgpu::ObjectBase AddRefs; destructor Releases. Graphite copies the same
    // handles into DawnBackendContext and retains them independently.
    ctx->instance = wgpu::Instance(descriptor->instance);
    ctx->device = wgpu::Device(descriptor->device);
    ctx->queue = wgpu::Queue(descriptor->queue);

    skgpu::graphite::DawnBackendContext backend;
    backend.fInstance = ctx->instance;
    backend.fDevice = ctx->device;
    backend.fQueue = ctx->queue;

    ctx->graphite = skgpu::graphite::ContextFactory::MakeDawn(
        backend,
        skgpu::graphite::ContextOptions());
    if (!ctx->graphite) {
        delete ctx;
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR,
                   "ContextFactory::MakeDawn failed");
        return FG_STATUS_INTERNAL_ERROR;
    }

    ctx->recorder = ctx->graphite->makeRecorder();
    if (!ctx->recorder) {
        delete ctx;
        fgSetError(out_error, FG_STATUS_INTERNAL_ERROR, "graphite makeRecorder failed");
        return FG_STATUS_INTERNAL_ERROR;
    }

    *out_context = ctx;
    fgSetError(out_error, FG_STATUS_OK, nullptr);
    return FG_STATUS_OK;
}

extern "C" void fg_context_destroy(FGContext* context) {
    delete context;
}
