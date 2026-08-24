#!/bin/sh
set -eu
if [ "$#" -lt 2 ]; then
  echo "usage: $0 <native-out-dir> <smoke.cpp>" >&2
  exit 2
fi
out=$1
src=$2
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "${root}/tools/host.sh"
bin=${out}/bin/dawn_smoke
sh "${root}/tools/cxx_link_archives.sh" \
  "${bin}" "${src}" \
  "${out}/include" \
  -- \
  "${out}/lib/libdawn_monolithic.a"
if fun_is_android; then
  echo "fun-graphics: android dawn smoke linked (not executed on host)" >&2
  exit 0
fi
"${bin}"
