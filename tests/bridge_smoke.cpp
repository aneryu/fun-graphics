// Native smoke for the Graphite C ABI (not the Zig stub).
// Always asserts the real ABI is linked. GPU context creation is best-effort:
// CI machines may have no Vulkan ICD.
#include "fun_graphics.h"

#include <cstdio>
#include <cstring>

namespace {

bool contains(const char* hay, const char* needle) {
    return hay != nullptr && std::strstr(hay, needle) != nullptr;
}

void fail(const char* msg) {
    std::fprintf(stderr, "bridge_smoke: %s\n", msg);
}

struct AdapterSlot {
    WGPUAdapter adapter = nullptr;
    bool done = false;
};

void onAdapter(
    WGPURequestAdapterStatus status,
    WGPUAdapter adapter,
    WGPUStringView message,
    void* userdata1,
    void* userdata2
) {
    (void)message;
    (void)userdata2;
    auto* slot = static_cast<AdapterSlot*>(userdata1);
    slot->done = true;
    if (status == WGPURequestAdapterStatus_Success) {
        slot->adapter = adapter;
    } else if (adapter != nullptr) {
        wgpuAdapterRelease(adapter);
    }
}

WGPUAdapter requestAdapter(WGPUInstance instance, WGPUBackendType backend) {
    AdapterSlot slot;
    WGPURequestAdapterOptions options = WGPU_REQUEST_ADAPTER_OPTIONS_INIT;
    options.backendType = backend;

    WGPURequestAdapterCallbackInfo cb = WGPU_REQUEST_ADAPTER_CALLBACK_INFO_INIT;
    cb.mode = WGPUCallbackMode_AllowProcessEvents;
    cb.callback = onAdapter;
    cb.userdata1 = &slot;

    wgpuInstanceRequestAdapter(instance, &options, cb);
    for (int i = 0; i < 256 && !slot.done; ++i) {
        wgpuInstanceProcessEvents(instance);
    }
    return slot.adapter;
}

int checkAbiWithoutGpu() {
    const FGBuildInfo* info = fg_get_build_info();
    if (info == nullptr || info->api_version != FG_API_VERSION) {
        fail("fg_get_build_info missing or wrong api_version");
        return 1;
    }
    if (info->build_id == nullptr || std::strcmp(info->build_id, "stub") == 0) {
        fail("native bridge still reports stub build_id");
        return 1;
    }

    FGError err{};
    FGContext* ctx = reinterpret_cast<FGContext*>(1);
    FGStatus status = fg_context_create(nullptr, &ctx, &err);
    if (status != FG_STATUS_INVALID_ARGUMENT || ctx != nullptr) {
        fail("null descriptor should be INVALID_ARGUMENT");
        return 1;
    }

    FGContextDescriptor desc{};
    desc.struct_size = sizeof(desc);
    desc.instance = nullptr;
    desc.device = nullptr;
    desc.queue = nullptr;
    ctx = reinterpret_cast<FGContext*>(1);
    err = {};
    status = fg_context_create(&desc, &ctx, &err);
    if (status != FG_STATUS_INVALID_ARGUMENT || ctx != nullptr) {
        fail("null instance/device/queue should be INVALID_ARGUMENT, not stub");
        return 1;
    }
    if (contains(err.message, "native graphics not built")) {
        fail("real ABI still returning stub message");
        return 1;
    }
    return 0;
}

int tryGpuPath() {
    WGPUInstance instance = wgpuCreateInstance(nullptr);
    if (instance == nullptr) {
        std::printf("bridge_smoke ok (linked; wgpuCreateInstance returned null)\n");
        return 0;
    }

    WGPUAdapter adapter = requestAdapter(instance, WGPUBackendType_Vulkan);
    if (adapter == nullptr) {
        adapter = requestAdapter(instance, WGPUBackendType_Null);
    }
    if (adapter == nullptr) {
        wgpuInstanceRelease(instance);
        std::printf("bridge_smoke ok (linked; no GPU adapter)\n");
        return 0;
    }

    WGPUDevice device = wgpuAdapterCreateDevice(adapter, nullptr);
    if (device == nullptr) {
        wgpuAdapterRelease(adapter);
        wgpuInstanceRelease(instance);
        std::printf("bridge_smoke ok (linked; no GPU device)\n");
        return 0;
    }

    WGPUQueue queue = wgpuDeviceGetQueue(device);
    FGContextDescriptor desc{};
    desc.struct_size = sizeof(desc);
    desc.instance = instance;
    desc.device = device;
    desc.queue = queue;

    FGError err{};
    FGContext* ctx = nullptr;
    FGStatus status = fg_context_create(&desc, &ctx, &err);
    if (status != FG_STATUS_OK || ctx == nullptr) {
        const char* msg = err.message != nullptr ? err.message : "MakeDawn failed";
        std::printf("bridge_smoke ok (linked; no Graphite context: %s)\n", msg);
        if (queue != nullptr) wgpuQueueRelease(queue);
        wgpuDeviceRelease(device);
        wgpuAdapterRelease(adapter);
        wgpuInstanceRelease(instance);
        return 0;
    }

    WGPUTextureDescriptor tex{};
    tex = WGPU_TEXTURE_DESCRIPTOR_INIT;
    tex.usage = WGPUTextureUsage_RenderAttachment | WGPUTextureUsage_CopySrc |
                WGPUTextureUsage_CopyDst | WGPUTextureUsage_TextureBinding;
    tex.dimension = WGPUTextureDimension_2D;
    tex.size.width = 16;
    tex.size.height = 16;
    tex.size.depthOrArrayLayers = 1;
    tex.format = WGPUTextureFormat_BGRA8Unorm;
    tex.mipLevelCount = 1;
    tex.sampleCount = 1;
    WGPUTexture texture = wgpuDeviceCreateTexture(device, &tex);

    int rc = 0;
    if (texture == nullptr) {
        fail("device created but wgpuDeviceCreateTexture returned null");
        rc = 1;
    } else {
        FGSurfaceDescriptor sdesc{};
        sdesc.struct_size = sizeof(sdesc);
        sdesc.texture = texture;
        sdesc.format = WGPUTextureFormat_BGRA8Unorm;
        sdesc.width = 16;
        sdesc.height = 16;
        sdesc.sample_count = 1;

        FGSurface* surface = nullptr;
        err = {};
        status = fg_surface_wrap_texture(ctx, &sdesc, &surface, &err);
        if (status != FG_STATUS_OK || surface == nullptr) {
            fail(err.message != nullptr ? err.message : "fg_surface_wrap_texture failed");
            rc = 1;
        } else {
            if (fg_surface_get_canvas(surface) == nullptr) {
                fail("fg_surface_get_canvas returned null");
                rc = 1;
            }
            err = {};
            status = fg_surface_flush(surface, &err);
            if (status != FG_STATUS_OK) {
                fail(err.message != nullptr ? err.message : "fg_surface_flush failed");
                rc = 1;
            }
            fg_surface_destroy(surface);
        }
        wgpuTextureRelease(texture);
    }

    fg_context_destroy(ctx);
    if (queue != nullptr) wgpuQueueRelease(queue);
    wgpuDeviceRelease(device);
    wgpuAdapterRelease(adapter);
    wgpuInstanceRelease(instance);

    if (rc == 0) {
        std::printf("bridge_smoke ok (context + wrap + flush)\n");
    }
    return rc;
}

} // namespace

int main() {
    if (checkAbiWithoutGpu() != 0) return 1;
    return tryGpuPath();
}
