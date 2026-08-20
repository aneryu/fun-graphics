#!/bin/sh
set -eu
if [ "$#" -lt 4 ]; then
  echo "usage: $0 <skia-src> <dawn-out> <skia-out> <smoke.cpp>" >&2
  exit 2
fi
skia_src=$1
dawn_out=$2
skia_out=$3
src=$4
bin=${skia_out}/bin/graphite_smoke
mkdir -p "${skia_out}/bin"
c++ -std=c++20 -O2 \
  -DSK_GRAPHITE -DSK_DAWN \
  -I "${skia_src}" \
  -I "${dawn_out}/include" \
  "${src}" \
  -Wl,--start-group \
  -Wl,--whole-archive \
  "${skia_out}/lib/libskia.a" \
  "${dawn_out}/lib/libdawn_monolithic.a" \
  -Wl,--no-whole-archive \
  -Wl,--end-group \
  -lpthread -ldl -lz \
  -o "${bin}"
"${bin}"
