#!/bin/sh
# Drop DWARF from a relocatable object. Zig objcopy cannot copy ET_REL.
set -eu

if [ "$#" -lt 2 ]; then
    echo "usage: $0 <input.o> <output.o>" >&2
    exit 2
fi

input=$1
output=$2

strip_bin=
if [ -n "${FUN_GRAPHICS_ANDROID_NDK:-}" ]; then
    for tag in darwin-arm64 darwin-x86_64 linux-x86_64 linux-aarch64; do
        cand="${FUN_GRAPHICS_ANDROID_NDK}/toolchains/llvm/prebuilt/${tag}/bin/llvm-strip"
        if [ -x "${cand}" ]; then
            strip_bin=${cand}
            break
        fi
    done
    if [ -z "${strip_bin}" ]; then
        for cand in "${FUN_GRAPHICS_ANDROID_NDK}"/toolchains/llvm/prebuilt/*/bin/llvm-strip; do
            if [ -x "${cand}" ]; then
                strip_bin=${cand}
                break
            fi
        done
    fi
fi
if [ -z "${strip_bin}" ] && command -v llvm-strip >/dev/null 2>&1; then
    strip_bin=$(command -v llvm-strip)
fi
if [ -z "${strip_bin}" ]; then
    echo "fun-graphics: llvm-strip not found; keeping debug in ${input}" >&2
    cp -a "${input}" "${output}"
    exit 0
fi

mkdir -p "$(dirname "${output}")"
"${strip_bin}" --strip-debug -o "${output}" "${input}"
