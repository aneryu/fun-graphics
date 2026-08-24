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
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "${root}/tools/host.sh"
bin=${skia_out}/bin/graphite_smoke
FUN_GRAPHICS_CXX_DEFS="-DSK_GRAPHITE -DSK_DAWN" \
  sh "${root}/tools/cxx_link_archives.sh" \
  "${bin}" "${src}" \
  "${skia_src}" \
  "${dawn_out}/include" \
  -- \
  "${skia_out}/lib/libskia.a" \
  "${dawn_out}/lib/libdawn_monolithic.a"
if fun_is_android; then
  echo "fun-graphics: android graphite smoke linked (not executed on host)" >&2
  exit 0
fi
"${bin}"
