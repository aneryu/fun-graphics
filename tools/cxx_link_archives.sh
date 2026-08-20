#!/bin/sh
# Link a C++ smoke binary against static archives with whole-archive semantics.
set -eu

. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/host.sh"

if [ "$#" -lt 4 ]; then
    echo "usage: $0 <bin> <src.cpp> <incdir> ... -- <archive> ..." >&2
    exit 2
fi

bin=$1
shift
src=$1
shift

inc_flags=
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    inc_flags="${inc_flags} -I${1}"
    shift
done
if [ "$#" -eq 0 ] || [ "$1" != "--" ]; then
    echo "fun-graphics: missing -- before archives" >&2
    exit 2
fi
shift

mkdir -p "$(dirname "${bin}")"

if fun_is_macos; then
    force=
    for archive in "$@"; do
        force="${force} -Wl,-force_load,${archive}"
    done
    # shellcheck disable=SC2086
    c++ -std=c++20 -O2 ${FUN_GRAPHICS_CXX_DEFS:-} ${inc_flags} "${src}" ${force} \
        -framework Foundation -framework IOSurface -framework IOKit \
        -framework Metal -framework QuartzCore -framework Cocoa \
        -lz -o "${bin}"
else
    group=
    for archive in "$@"; do
        group="${group} ${archive}"
    done
    # shellcheck disable=SC2086
    c++ -std=c++20 -O2 ${FUN_GRAPHICS_CXX_DEFS:-} ${inc_flags} "${src}" \
        -Wl,--start-group -Wl,--whole-archive ${group} -Wl,--no-whole-archive -Wl,--end-group \
        -lpthread -ldl -lz -o "${bin}"
fi
