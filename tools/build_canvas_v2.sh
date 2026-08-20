#!/bin/sh
# Compile Canvas 2D API v2 extras and pack into one relocatable object.
# Links alongside published libfun_graphics_native.o (native-r1 base ABI).
set -eu

. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/host.sh"

if [ "$#" -lt 3 ]; then
    echo "usage: $0 <skia-src> <out-dir> <output.o>" >&2
    exit 2
fi

skia_src=$1
out_dir=$2
output=$3
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

if [ ! -f "${skia_src}/include/core/SkCanvas.h" ]; then
    echo "fun-graphics: missing Skia headers at ${skia_src}" >&2
    exit 1
fi

obj=${out_dir}/obj/canvas_v2
mkdir -p "${obj}" "$(dirname "${output}")"

cxx=${CXX:-c++}
common_flags="-std=c++20 -O2 -fno-exceptions -fno-rtti -DSK_GRAPHITE"
if fun_is_macos; then
    common_flags="${common_flags} -DSK_BUILD_FOR_MAC"
fi
inc="-I ${root}/include -I ${root}/src -I ${skia_src}"

${cxx} ${common_flags} ${inc} -c "${root}/src/canvas_v2.cpp" -o "${obj}/canvas_v2.o"
${cxx} ${common_flags} ${inc} -c "${root}/src/path.cpp" -o "${obj}/path.o"
${cxx} ${common_flags} ${inc} -c "${root}/src/text.cpp" -o "${obj}/text.o"
${cxx} ${common_flags} ${inc} -c "${root}/src/image.cpp" -o "${obj}/image.o"

if fun_is_macos; then
    ld -r -arch "$(fun_ld_arch)" -keep_private_externs \
        "${obj}/canvas_v2.o" "${obj}/path.o" "${obj}/text.o" "${obj}/image.o" \
        -o "${output}"
else
    ld -r -o "${output}" \
        "${obj}/canvas_v2.o" "${obj}/path.o" "${obj}/text.o" "${obj}/image.o"
fi

printf '%s\n' "${output}"







