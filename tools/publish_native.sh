#!/bin/sh
# Upload a packed native tarball onto the rolling `nightly` GitHub Release.
# Creates the release on first use; later runs replace the same asset in place.
set -eu

if [ "$#" -lt 1 ]; then
    echo "usage: $0 <asset-tarball> [repo]" >&2
    exit 2
fi

asset=$1
repo=${2:-${GITHUB_REPOSITORY:-aneryu/fun-graphics}}
tag=nightly

if [ ! -f "${asset}" ]; then
    echo "fun-graphics: missing ${asset}" >&2
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "fun-graphics: gh is required to publish ${asset}" >&2
    exit 1
fi

if ! gh release view "${tag}" -R "${repo}" >/dev/null 2>&1; then
    gh release create "${tag}" -R "${repo}" \
        --title "Nightly native archives" \
        --notes "Rolling prebuilt relocatable objects for fun \`-Dgraphics-native=true\`. Assets are overwritten in place; there is no versioned native-rN channel."
fi

gh release upload "${tag}" "${asset}" --clobber -R "${repo}"
