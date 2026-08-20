#!/bin/sh
# Compile the Graphite C ABI into libfun_graphics_bridge.a against prebuilt
# Skia Graphite and Dawn archives. Does not compile the stub src/api.cpp.
set -eu

. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/host.sh"

if [ "$#" -lt 3 ]; then
    echo "usage: $0 <skia-src> <dawn-native-out> <skia-out> [skia-commit] [dawn-commit]" >&2
    exit 2
fi

skia_src=$1
dawn_out=$2
skia_out=$3
skia_commit=${4:-unpinned}
dawn_commit=${5:-unpinned}

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
obj=${skia_out}/obj/bridge
lib=${skia_out}/lib/libfun_graphics_bridge.a
native_o=${skia_out}/lib/libfun_graphics_native.o

dawn_lib=${dawn_out}/lib/libdawn_monolithic.a
skia_lib=${skia_out}/lib/libskia.a

if [ ! -f "${dawn_lib}" ]; then
    echo "fun-graphics: missing Dawn archive ${dawn_lib}" >&2
    exit 1
fi
if [ ! -f "${skia_lib}" ]; then
    echo "fun-graphics: missing Skia archive ${skia_lib}" >&2
    exit 1
fi

mkdir -p "${obj}" "${skia_out}/lib"

cxx=${CXX:-c++}
common_flags="-std=c++20 -O2 -fno-exceptions -fno-rtti -DSK_GRAPHITE -DSK_DAWN"
# Dawn headers must precede fun-graphics/include so stub webgpu.h cannot win.
inc="-I ${dawn_out}/include -I ${root}/include -I ${skia_src}"
defs="-DFUN_GRAPHICS_BUILD_ID=\"native\" -DFUN_GRAPHICS_SKIA_COMMIT=\"${skia_commit}\" -DFUN_GRAPHICS_DAWN_COMMIT=\"${dawn_commit}\""

${cxx} ${common_flags} ${inc} ${defs} \
    -c "${root}/src/build_info.cpp" -o "${obj}/build_info.o"
${cxx} ${common_flags} ${inc} ${defs} \
    -c "${root}/src/graphite_context.cpp" -o "${obj}/graphite_context.o"
${cxx} ${common_flags} ${inc} ${defs} \
    -c "${root}/src/surface.cpp" -o "${obj}/surface.o"
${cxx} ${common_flags} ${inc} ${defs} \
    -c "${root}/src/canvas.cpp" -o "${obj}/canvas.o"

rm -f "${lib}"
ar rcs "${lib}" \
    "${obj}/build_info.o" \
    "${obj}/graphite_context.o" \
    "${obj}/surface.o" \
    "${obj}/canvas.o"

# One relocatable object so Zig `addObjectFile` keeps Dawn static constructors
# (backend registration) instead of archive GC.
if fun_is_macos; then
    # Apple ld rejects -r together with -force_load. `ar x` also overwrites
    # duplicate member basenames (Dawn/Tint has ~80 of them), so extract with
    # unique names then ld -r -filelist.
    stage=$(mktemp -d)
    trap 'rm -rf "${stage}"' EXIT
    python3 "$(dirname "$0")/extract_ar.py" "${lib}" "${stage}/bridge"
    python3 "$(dirname "$0")/extract_ar.py" "${skia_lib}" "${stage}/skia"
    python3 "$(dirname "$0")/extract_ar.py" "${dawn_lib}" "${stage}/dawn"
    list=${stage}/objects.list
    find "${stage}/bridge" "${stage}/skia" "${stage}/dawn" -name '*.o' > "${list}"
    if [ ! -s "${list}" ]; then
        echo "fun-graphics: no object members to pack into ${native_o}" >&2
        exit 1
    fi
    ld -r -arch "$(fun_ld_arch)" -filelist "${list}" -o "${native_o}"
else
    ld -r -o "${native_o}" \
        --whole-archive \
        "${lib}" \
        "${skia_lib}" \
        "${dawn_lib}" \
        --no-whole-archive
fi

printf '%s\n' "${lib}"
printf '%s\n' "${native_o}"
