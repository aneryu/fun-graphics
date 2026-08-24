#!/bin/sh
# Probe Android host helpers without requiring an NDK or Dawn/Skia sources.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "${root}/tools/host.sh"

if fun_is_android; then
    echo "fun-graphics: default env must not be android" >&2
    exit 1
fi

host_triple=$(fun_triple)
case "${host_triple}" in
    *-linux|*-macos|*-windows) ;;
    *)
        echo "fun-graphics: unexpected host triple ${host_triple}" >&2
        exit 1
        ;;
esac

export FUN_GRAPHICS_TARGET=android
if ! fun_is_android; then
    echo "fun-graphics: FUN_GRAPHICS_TARGET=android did not select android" >&2
    exit 1
fi

# Host protoc is required only for Dawn's Android CMake, not this probe.
if command -v protoc >/dev/null 2>&1; then
    proto=$(fun_host_protoc)
    [ -n "${proto}" ]
    [ -x "${proto}" ]
fi

[ "$(fun_android_abi)" = arm64-v8a ]
[ "$(fun_android_api)" = 26 ]
[ "$(fun_triple)" = aarch64-android ]
[ "$(fun_android_gn_cpu)" = arm64 ]
[ "$(fun_android_llvm_triple)" = aarch64-linux-android26 ]

export FUN_GRAPHICS_ANDROID_ABI=x86_64
export FUN_GRAPHICS_ANDROID_API=28
[ "$(fun_triple)" = x86_64-android ]
[ "$(fun_android_gn_cpu)" = x64 ]
[ "$(fun_android_llvm_triple)" = x86_64-linux-android28 ]

export FUN_GRAPHICS_ANDROID_ABI=armeabi-v7a
[ "$(fun_triple)" = arm-android ]
[ "$(fun_android_gn_cpu)" = arm ]

if fun_ndk_home >/dev/null 2>&1; then
    echo "fun-graphics: NDK present at $(fun_ndk_home)"
else
    echo "fun-graphics: android host helpers ok (NDK not required for this probe)"
fi
