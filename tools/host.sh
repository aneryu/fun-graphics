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
