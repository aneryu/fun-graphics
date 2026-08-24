#!/bin/sh
# POSIX helpers shared by fun-graphics native scripts.
#
# Cross-compile to Android by exporting:
#   FUN_GRAPHICS_TARGET=android
#   FUN_GRAPHICS_ANDROID_ABI=arm64-v8a   (default)
#   FUN_GRAPHICS_ANDROID_API=26          (default; Vulkan floor)
#   ANDROID_NDK_HOME=/path/to/ndk        (or ANDROID_NDK / NDK_ROOT)

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

fun_is_android() {
    target=${FUN_GRAPHICS_TARGET:-}
    case "${target}" in
        android|aarch64-android|arm-android|x86_64-android|x86-android) return 0 ;;
        *) return 1 ;;
    esac
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

fun_android_abi() {
    printf '%s\n' "${FUN_GRAPHICS_ANDROID_ABI:-arm64-v8a}"
}

fun_android_api() {
    printf '%s\n' "${FUN_GRAPHICS_ANDROID_API:-26}"
}

fun_android_gn_cpu() {
    case "$(fun_android_abi)" in
        arm64-v8a) printf '%s\n' arm64 ;;
        armeabi-v7a) printf '%s\n' arm ;;
        x86_64) printf '%s\n' x64 ;;
        x86) printf '%s\n' x86 ;;
        *)
            echo "fun-graphics: unsupported Android ABI $(fun_android_abi)" >&2
            return 1
            ;;
    esac
}

fun_triple() {
    if fun_is_android; then
        case "$(fun_android_abi)" in
            arm64-v8a) printf '%s\n' aarch64-android ;;
            armeabi-v7a) printf '%s\n' arm-android ;;
            x86_64) printf '%s\n' x86_64-android ;;
            x86) printf '%s\n' x86-android ;;
            *)
                echo "fun-graphics: unsupported Android ABI $(fun_android_abi)" >&2
                return 1
                ;;
        esac
        return
    fi
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

fun_ndk_home() {
    for cand in "${ANDROID_NDK_HOME:-}" "${ANDROID_NDK:-}" "${NDK_ROOT:-}"; do
        if [ -n "${cand}" ] && [ -d "${cand}/toolchains/llvm/prebuilt" ]; then
            printf '%s\n' "${cand}"
            return 0
        fi
    done
    return 1
}

fun_require_ndk() {
    ndk=$(fun_ndk_home) || {
        echo "fun-graphics: Android NDK not found." >&2
        echo "set ANDROID_NDK_HOME (or ANDROID_NDK / NDK_ROOT) to an NDK r26+ path." >&2
        echo "example: zig build native -Dandroid" >&2
        exit 1
    }
    printf '%s\n' "${ndk}"
}

# Dawn's bundled protobuf cannot build protoc for the Android target.
# Cross-compiles must feed a host protoc via -DPROTOC_EXECUTABLE.
fun_host_protoc() {
    if [ -n "${PROTOC_EXECUTABLE:-}" ] && [ -x "${PROTOC_EXECUTABLE}" ]; then
        printf '%s\n' "${PROTOC_EXECUTABLE}"
        return 0
    fi
    if command -v protoc >/dev/null 2>&1; then
        command -v protoc
        return 0
    fi
    echo "fun-graphics: Android Dawn cross-compile needs a host protoc." >&2
    echo "install protobuf-compiler or set PROTOC_EXECUTABLE to a host binary." >&2
    return 1
}

fun_ndk_prebuilt_tag() {
    case "$(uname -s)-$(uname -m)" in
        Linux-x86_64) printf '%s\n' linux-x86_64 ;;
        Linux-aarch64)
            ndk=$(fun_ndk_home) || ndk=
            if [ -n "${ndk}" ] && [ -d "${ndk}/toolchains/llvm/prebuilt/linux-aarch64" ]; then
                printf '%s\n' linux-aarch64
            else
                printf '%s\n' linux-x86_64
            fi
            ;;
        Darwin-arm64|Darwin-aarch64)
            ndk=$(fun_ndk_home) || ndk=
            if [ -n "${ndk}" ] && [ -d "${ndk}/toolchains/llvm/prebuilt/darwin-aarch64" ]; then
                printf '%s\n' darwin-aarch64
            else
                printf '%s\n' darwin-x86_64
            fi
            ;;
        Darwin-x86_64) printf '%s\n' darwin-x86_64 ;;
        *) printf '%s\n' linux-x86_64 ;;
    esac
}

fun_android_toolchain() {
    ndk=$(fun_require_ndk)
    tag=$(fun_ndk_prebuilt_tag)
    toolchain="${ndk}/toolchains/llvm/prebuilt/${tag}"
    if [ ! -d "${toolchain}" ]; then
        echo "fun-graphics: NDK prebuilt toolchain missing: ${toolchain}" >&2
        exit 1
    fi
    printf '%s\n' "${toolchain}"
}

fun_android_llvm_triple() {
    api=$(fun_android_api)
    case "$(fun_android_abi)" in
        arm64-v8a) printf 'aarch64-linux-android%s\n' "${api}" ;;
        armeabi-v7a) printf 'armv7a-linux-androideabi%s\n' "${api}" ;;
        x86_64) printf 'x86_64-linux-android%s\n' "${api}" ;;
        x86) printf 'i686-linux-android%s\n' "${api}" ;;
        *)
            echo "fun-graphics: unsupported Android ABI $(fun_android_abi)" >&2
            return 1
            ;;
    esac
}

fun_android_clang() {
    toolchain=$(fun_android_toolchain)
    triple=$(fun_android_llvm_triple)
    clang="${toolchain}/bin/${triple}-clang"
    if [ ! -x "${clang}" ]; then
        clang="${toolchain}/bin/clang"
    fi
    if [ ! -x "${clang}" ]; then
        echo "fun-graphics: NDK clang not found under ${toolchain}/bin" >&2
        exit 1
    fi
    printf '%s\n' "${clang}"
}

fun_android_cxx() {
    toolchain=$(fun_android_toolchain)
    triple=$(fun_android_llvm_triple)
    cxx="${toolchain}/bin/${triple}-clang++"
    if [ -x "${cxx}" ]; then
        printf '%s\n' "${cxx}"
        return
    fi
    if [ -x "${toolchain}/bin/clang++" ]; then
        printf '%s\n' "${toolchain}/bin/clang++"
        return
    fi
    echo "fun-graphics: NDK clang++ not found under ${toolchain}/bin" >&2
    exit 1
}

fun_android_ar() {
    printf '%s/bin/llvm-ar\n' "$(fun_android_toolchain)"
}

fun_android_ld() {
    toolchain=$(fun_android_toolchain)
    if [ -x "${toolchain}/bin/ld.lld" ]; then
        printf '%s\n' "${toolchain}/bin/ld.lld"
        return
    fi
    printf '%s\n' "${toolchain}/bin/ld"
}

# Drop DWARF from a relocatable .o. NDK clang / Skia GN still emit full
# debug info in Release; ld -r --whole-archive then copies it into the
# packed object (Android was ~620MB uncompressed / ~116MB gzip, almost
# all .debug_* plus .rela.debug_*). llvm-strip --strip-debug brings that
# in line with Linux (~40MB / ~11MB gzip) without changing ABI symbols.
fun_strip_debug() {
    obj=$1
    if [ ! -f "${obj}" ]; then
        echo "fun-graphics: missing ${obj}" >&2
        return 1
    fi
    before=$(wc -c < "${obj}" | tr -d ' ')
    if fun_is_android; then
        strip_bin="$(fun_android_toolchain)/bin/llvm-strip"
        "${strip_bin}" --strip-debug "${obj}"
    elif command -v llvm-strip >/dev/null 2>&1; then
        llvm-strip --strip-debug "${obj}"
    elif fun_is_macos; then
        strip -S "${obj}"
    else
        strip --strip-debug "${obj}"
    fi
    after=$(wc -c < "${obj}" | tr -d ' ')
    echo "fun-graphics: stripped debug ${before} -> ${after} bytes (${obj})" >&2
}

fun_android_sysroot() {
    printf '%s/sysroot\n' "$(fun_android_toolchain)"
}
