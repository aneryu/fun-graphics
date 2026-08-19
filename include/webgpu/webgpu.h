#ifndef WEBGPU_H_
#define WEBGPU_H_

//! Stub WebGPU C types for the fun-graphics C ABI when Dawn generated
//! headers are not present. Native builds replace this include tree with
//! Dawn's generated `webgpu/webgpu.h`.

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WGPUInstanceImpl* WGPUInstance;
typedef struct WGPUAdapterImpl* WGPUAdapter;
typedef struct WGPUDeviceImpl* WGPUDevice;
typedef struct WGPUQueueImpl* WGPUQueue;
typedef struct WGPUTextureImpl* WGPUTexture;

typedef enum WGPUTextureFormat {
    WGPUTextureFormat_Undefined = 0,
} WGPUTextureFormat;

#ifdef __cplusplus
} // extern "C"
#endif

#endif
