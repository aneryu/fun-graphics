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

mkdir -p "${skia_out}/bin"
c++ -std=c++20 -O2 \
  -DSK_GRAPHITE -DSK_DAWN \
  -I "${dawn_out}/include" \
  -I "${root}/include" \
  -I "${skia_src}" \
  "${src}" \
  -Wl,--start-group \
  -Wl,--whole-archive \
  "${bridge_lib}" \
  "${skia_out}/lib/libskia.a" \
  "${dawn_out}/lib/libdawn_monolithic.a" \
  -Wl,--no-whole-archive \
  -Wl,--end-group \
  -lpthread -ldl -lz \
  -o "${bin}"
"${bin}"
