#!/bin/sh
# Ensure libfun_graphics_native.o exists, then copy it to the Zig output path.
# Prefers the local cache; otherwise downloads a GitHub Release asset.
set -eu

. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/host.sh"

if [ "$#" -lt 6 ]; then
    echo "usage: $0 <cache_o> <repo> <tag> <asset> <sha256> <output>" >&2
    exit 2
fi

cache_o=$1
repo=$2
tag=$3
asset=$4
sha256=$5
output=$6

cache_dir=$(dirname "${cache_o}")
release_dir="${HOME}/.cache/fun-graphics/releases"
mkdir -p "${cache_dir}" "${release_dir}" "$(dirname "${output}")"

copy_cache() {
    cp -a "${cache_o}" "${output}"
}

if [ -f "${cache_o}" ]; then
    copy_cache
    exit 0
fi

if [ "${asset}" = "-" ] || [ -z "${asset}" ]; then
    echo "fun-graphics: no native object at ${cache_o}" >&2
    echo "no GitHub Release asset for this target. Build from source:" >&2
    echo "  zig build native" >&2
    exit 1
fi

tarball="${release_dir}/${asset}"
if [ ! -f "${tarball}" ]; then
    if command -v gh >/dev/null 2>&1; then
        gh release download "${tag}" -R "${repo}" -p "${asset}" -D "${release_dir}" --clobber
    elif [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
        token=${GH_TOKEN:-${GITHUB_TOKEN}}
        api="https://api.github.com/repos/${repo}/releases/tags/${tag}"
        url=$(curl -fsSL -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.github+json" "${api}" \
            | sed -n "s/.*\"browser_download_url\": \"\\([^\"]*${asset}\\)\".*/\\1/p" | head -n 1)
        if [ -z "${url}" ]; then
            echo "fun-graphics: release ${tag} has no asset ${asset}" >&2
            exit 1
        fi
        curl -fsSL -H "Authorization: Bearer ${token}" -H "Accept: application/octet-stream" -o "${tarball}" "${url}"
    else
        echo "fun-graphics: missing ${cache_o} and cannot download ${asset}" >&2
        echo "install GitHub CLI (\`gh auth login\`) or set GH_TOKEN, or build from source:" >&2
        echo "  zig build native" >&2
        exit 1
    fi
fi

if [ "${sha256}" != "-" ] && [ -n "${sha256}" ] && [ "${#sha256}" -eq 64 ]; then
    actual=$(fun_sha256 "${tarball}")
    if [ "${actual}" != "${sha256}" ]; then
        echo "fun-graphics: sha256 mismatch for ${asset}" >&2
        echo "  expected ${sha256}" >&2
        echo "  actual   ${actual}" >&2
        rm -f "${tarball}"
        exit 1
    fi
fi

stage=$(mktemp -d)
trap 'rm -rf "${stage}"' EXIT
tar -C "${stage}" -xzf "${tarball}"
if [ ! -f "${stage}/libfun_graphics_native.o" ]; then
    echo "fun-graphics: tarball ${asset} missing libfun_graphics_native.o" >&2
    exit 1
fi
cp -a "${stage}/libfun_graphics_native.o" "${cache_o}"
copy_cache
