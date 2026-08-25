#!/bin/sh
# POSIX helpers shared by fun-graphics native scripts.

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

fun_triple() {
    printf '%s-%s\n' "$(fun_arch)" "$(fun_os)"
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

fun_is_android() {
    [ -n "${FUN_GRAPHICS_ANDROID_NDK:-}" ]
}

fun_android_ndk() {
    printf '%s\n' "${FUN_GRAPHICS_ANDROID_NDK}"
}

fun_android_api() {
    printf '%s\n' "${FUN_GRAPHICS_ANDROID_API:-29}"
}

fun_android_abi() {
    printf '%s\n' "${FUN_GRAPHICS_ANDROID_ABI:-arm64-v8a}"
}

fun_android_prebuilt() {
    ndk=$(fun_android_ndk)
    host=$(uname -s | tr '[:upper:]' '[:lower:]')
    machine=$(uname -m)
    tag=
    case "${host}-${machine}" in
        darwin-arm64|darwin-aarch64) tag=darwin-x86_64 ;;
        darwin-x86_64) tag=darwin-x86_64 ;;
        linux-x86_64) tag=linux-x86_64 ;;
        linux-aarch64|linux-arm64) tag=linux-aarch64 ;;
        *) tag=darwin-x86_64 ;;
    esac
    if [ ! -d "${ndk}/toolchains/llvm/prebuilt/${tag}" ]; then
        for cand in "${ndk}/toolchains/llvm/prebuilt"/*; do
            if [ -d "${cand}" ]; then
                printf '%s\n' "${cand}"
                return
            fi
        done
    fi
    printf '%s\n' "${ndk}/toolchains/llvm/prebuilt/${tag}"
}

fun_android_triple() {
    api=$(fun_android_api)
    case "$(fun_android_abi)" in
        arm64-v8a) printf 'aarch64-linux-android%s\n' "${api}" ;;
        armeabi-v7a) printf 'armv7a-linux-androideabi%s\n' "${api}" ;;
        x86_64) printf 'x86_64-linux-android%s\n' "${api}" ;;
        x86) printf 'i686-linux-android%s\n' "${api}" ;;
        *) printf 'aarch64-linux-android%s\n' "${api}" ;;
    esac
}

fun_android_cxx() {
    printf '%s/bin/%s-clang++\n' "$(fun_android_prebuilt)" "$(fun_android_triple)"
}

fun_android_ld() {
    printf '%s/bin/ld.lld\n' "$(fun_android_prebuilt)"
}
