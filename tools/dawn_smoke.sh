#!/bin/sh
set -eu
if [ "$#" -lt 2 ]; then
  echo "usage: $0 <native-out-dir> <smoke.cpp>" >&2
  exit 2
fi
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/host.sh"
out=$1
src=$2
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
bin=${out}/bin/dawn_smoke
sh "${root}/tools/cxx_link_archives.sh" \
  "${bin}" "${src}" \
  "${out}/include" \
  -- \
  "${out}/lib/libdawn_monolithic.a"
fun_run_hosted "${bin}"
