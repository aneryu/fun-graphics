#!/bin/sh
# Link the native Graphite C ABI against Skia+Dawn and run tests/bridge_smoke.cpp.
set -eu
if [ "$#" -lt 4 ]; then
  echo "usage: $0 <skia-src> <dawn-out> <skia-out> <smoke.cpp>" >&2
  exit 2
fi
skia_src=$1
dawn_out=$2
skia_out=$3
src=$4
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
bin=${skia_out}/bin/bridge_smoke
bridge_lib=${skia_out}/lib/libfun_graphics_bridge.a

if [ ! -f "${bridge_lib}" ]; then
  echo "fun-graphics: missing bridge archive ${bridge_lib}" >&2
  exit 1
fi

FUN_GRAPHICS_CXX_DEFS="-DSK_GRAPHITE -DSK_DAWN" \
  sh "${root}/tools/cxx_link_archives.sh" \
  "${bin}" "${src}" \
  "${dawn_out}/include" \
  "${root}/include" \
  "${skia_src}" \
  -- \
  "${bridge_lib}" \
  "${skia_out}/lib/libskia.a" \
  "${dawn_out}/lib/libdawn_monolithic.a"
"${bin}"
