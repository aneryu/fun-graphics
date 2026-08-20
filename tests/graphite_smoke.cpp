// Native smoke: create a Dawn instance and attempt a Graphite Dawn context.
#include "include/gpu/graphite/Context.h"
#include "include/gpu/graphite/ContextOptions.h"
#include "include/gpu/graphite/dawn/DawnBackendContext.h"
#include "webgpu/webgpu_cpp.h"

#include <cstdio>

int main() {
    wgpu::Instance instance = wgpu::CreateInstance();
    if (!instance) {
        std::fprintf(stderr, "graphite_smoke: wgpu::CreateInstance returned null\n");
        return 1;
    }

    skgpu::graphite::DawnBackendContext backend;
    backend.fInstance = instance;
    // Device/Queue stay empty: this binary must link Graphite+Dawn. A real
    // adapter is optional (CI machines may have no Vulkan ICD).
    auto ctx = skgpu::graphite::ContextFactory::MakeDawn(
        backend,
        skgpu::graphite::ContextOptions());
    if (ctx) {
        std::printf("graphite_smoke ok (context created)\n");
        return 0;
    }
    std::printf("graphite_smoke ok (linked; no GPU context without device)\n");
    return 0;
}
