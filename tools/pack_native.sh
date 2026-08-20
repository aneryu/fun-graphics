#!/bin/sh
# Pack the host native relocatable object into a GitHub Release tarball.
# Does not upload; run `sh tools/publish_native.sh <tarball>` afterwards.
set -eu

. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/host.sh"

if [ "$#" -lt 3 ]; then
    echo "usage: $0 <skia-out> <dawn-commit> <skia-commit> [outdir]" >&2
    exit 2
fi

skia_out=$1
dawn_commit=$2
skia_commit=$3
outdir=${4:-}

native_o=${skia_out}/lib/libfun_graphics_native.o
if [ ! -f "${native_o}" ]; then
    echo "fun-graphics: missing ${native_o}" >&2
    echo "run: zig build native" >&2
    exit 1
fi

triple=$(fun_triple)
asset="fun-graphics-native-${triple}.tar.gz"

if [ -z "${outdir}" ]; then
    outdir="${HOME}/.cache/fun-graphics/releases"
fi
mkdir -p "${outdir}"

object_sha=$(fun_sha256 "${native_o}")
stage=$(mktemp -d)
trap 'rm -rf "${stage}"' EXIT

cp -a "${native_o}" "${stage}/libfun_graphics_native.o"
cat > "${stage}/manifest.json" <<EOF
{
  "recipe_version": 1,
  "triple": "${triple}",
  "dawn": "${dawn_commit}",
  "skia": "${skia_commit}",
  "object": "libfun_graphics_native.o",
  "object_sha256": "${object_sha}"
}
EOF

tar -C "${stage}" -czf "${outdir}/${asset}" manifest.json libfun_graphics_native.o
fun_sha256 "${outdir}/${asset}"
printf '%s\n' "${outdir}/${asset}"
