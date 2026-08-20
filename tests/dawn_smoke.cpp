// Native smoke: create a Dawn instance through the WebGPU C API.
#include <webgpu/webgpu.h>

#include <cstdio>

int main() {
    WGPUInstance instance = wgpuCreateInstance(nullptr);
    if (instance == nullptr) {
        std::fprintf(stderr, "dawn_smoke: wgpuCreateInstance returned null\n");
        return 1;
    }
    wgpuInstanceRelease(instance);
    std::printf("dawn_smoke ok\n");
    return 0;
}
