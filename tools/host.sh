#!/bin/sh
# POSIX helpers shared by fun-graphics native scripts.
#
# FUN_GRAPHICS_TARGET overrides the host OS for from-source native builds:
#   linux | macos | windows | ios | ios-simulator
# iOS device builds always pack as aarch64-ios (iphoneos / arm64).

fun_nproc() {
    if [ -n "${FUN_GRAPHICS_JOBS:-}" ]; then
        printf '%s\n' "${FUN_GRAPHICS_JOBS}"
        return
    fi
    nproc 2>/dev/null && return
    sysctl -n hw.ncpu 2>/dev/null && return
    printf '%s\n' 4
}

fun_is_macos() {
    [ "$(uname -s)" = Darwin ]
}

fun_arch() {
    arch=$(uname -m)
    case "${arch}" in
        aarch64|arm64) printf '%s\n' aarch64 ;;
        x86_64|amd64) printf '%s\n' x86_64 ;;
        *) printf '%s\n' "${arch}" ;;
    esac
}

fun_os() {
    os=$(uname -s)
    case "${os}" in
        Darwin) printf '%s\n' macos ;;
        Linux) printf '%s\n' linux ;;
        MINGW*|MSYS*|CYGWIN*) printf '%s\n' windows ;;
        *) printf '%s\n' "$(printf '%s' "${os}" | tr '[:upper:]' '[:lower:]')" ;;
    esac
}

fun_target() {
    if [ -n "${FUN_GRAPHICS_TARGET:-}" ]; then
        printf '%s\n' "${FUN_GRAPHICS_TARGET}"
        return
    fi
    fun_os
}

fun_is_ios() {
    case "$(fun_target)" in
        ios|ios-simulator) return 0 ;;
        *) return 1 ;;
    esac
}

fun_triple() {
    case "$(fun_target)" in
        ios)
            printf '%s\n' aarch64-ios
            ;;
        ios-simulator)
            printf '%s-ios-simulator\n' "$(fun_arch)"
            ;;
        *)
            printf '%s-%s\n' "$(fun_arch)" "$(fun_os)"
            ;;
    esac
}

fun_ld_arch() {
    case "$(uname -m)" in
        aarch64|arm64) printf '%s\n' arm64 ;;
        x86_64|amd64) printf '%s\n' x86_64 ;;
        *) uname -m ;;
    esac
}

fun_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
        return
    fi
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
        return
    fi
    echo "fun-graphics: need sha256sum or shasum" >&2
    return 1
}

fun_macos_frameworks() {
    printf '%s\n' \
        "-framework Foundation" \
        "-framework IOSurface" \
        "-framework IOKit" \
        "-framework Metal" \
        "-framework QuartzCore" \
        "-framework Cocoa"
}

fun_ios_sdk_name() {
    if [ "$(fun_target)" = "ios-simulator" ]; then
        printf '%s\n' iphonesimulator
        return
    fi
    printf '%s\n' iphoneos
}

fun_ios_min() {
    printf '%s\n' "${FUN_GRAPHICS_IOS_MIN:-16.0}"
}

fun_ios_arch() {
    if [ "$(fun_target)" = "ios-simulator" ]; then
        fun_ld_arch
        return
    fi
    printf '%s\n' arm64
}

fun_ios_min_flag() {
    min=$(fun_ios_min)
    if [ "$(fun_target)" = "ios-simulator" ]; then
        printf '%s\n' "-mios-simulator-version-min=${min}"
        return
    fi
    printf '%s\n' "-miphoneos-version-min=${min}"
}

fun_require_ios_sdk() {
    if ! command -v xcrun >/dev/null 2>&1; then
        echo "fun-graphics: iOS native build requires Xcode (xcrun) on macOS" >&2
        echo "  zig build native -Dnative-os=ios" >&2
        exit 1
    fi
    sdk=$(fun_ios_sdk_name)
    if ! xcrun --sdk "${sdk}" --show-sdk-path >/dev/null 2>&1; then
        echo "fun-graphics: missing iOS SDK '${sdk}'" >&2
        exit 1
    fi
}

fun_ios_sysroot() {
    fun_require_ios_sdk
    xcrun --sdk "$(fun_ios_sdk_name)" --show-sdk-path
}

fun_ios_clangxx() {
    fun_require_ios_sdk
    xcrun --sdk "$(fun_ios_sdk_name)" --find clang++
}

fun_ios_frameworks() {
    printf '%s\n' \
        "-framework Foundation" \
        "-framework UIKit" \
        "-framework Metal" \
        "-framework QuartzCore" \
        "-framework CoreGraphics" \
        "-framework CoreText" \
        "-framework CoreFoundation" \
        "-framework IOSurface" \
        "-framework ImageIO"
}

fun_can_run_native() {
    # iphoneos binaries cannot execute on macOS. Simulator binaries can, but
    # Graphite/Dawn still need a Metal-capable sim runtime — skip for now.
    if fun_is_ios; then
        return 1
    fi
    return 0
}

fun_run_hosted() {
    bin=$1
    shift
    if fun_can_run_native; then
        "${bin}" "$@"
        return
    fi
    echo "fun-graphics: not running ${bin} (target $(fun_triple) is cross-compiled)" >&2
    if command -v file >/dev/null 2>&1; then
        file "${bin}"
    fi
    if command -v otool >/dev/null 2>&1; then
        otool -hv "${bin}" | head -n 20
    fi
}
