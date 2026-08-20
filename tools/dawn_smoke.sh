#!/bin/sh
set -eu
if [ "$#" -lt 2 ]; then
  echo "usage: $0 <native-out-dir> <smoke.cpp>" >&2
  exit 2
fi
out=$1
src=$2
bin=${out}/bin/dawn_smoke
mkdir -p "${out}/bin"
c++ -std=c++20 -O2 \
  -I "${out}/include" \
  "${src}" \
  -Wl,--whole-archive "${out}/lib/libdawn_monolithic.a" -Wl,--no-whole-archive \
  -lpthread -ldl \
  -o "${bin}"
"${bin}"
