#!/bin/sh
# Fetch a pinned git commit into ~/.cache/fun-graphics/worktrees/<name>/<commit>.
set -eu

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <name> <git-url> <commit>" >&2
  exit 2
fi

name=$1
url=$2
commit=$3
cache_root=${FUN_GRAPHICS_CACHE:-${HOME}/.cache/fun-graphics}
worktree=${cache_root}/worktrees/${name}/${commit}

if [ -f "${worktree}/CMakeLists.txt" ] || [ -f "${worktree}/BUILD.gn" ]; then
  printf '%s\n' "${worktree}"
  exit 0
fi

mkdir -p "${cache_root}/git" "${cache_root}/worktrees/${name}"
tmp=${worktree}.tmp.$$
rm -rf "${tmp}"
git clone --filter=blob:none --depth 1 "${url}" "${tmp}"
got=$(git -C "${tmp}" rev-parse HEAD)
if [ "${got}" != "${commit}" ]; then
  git -C "${tmp}" fetch --depth 1 origin "${commit}"
  git -C "${tmp}" checkout --detach FETCH_HEAD
  got=$(git -C "${tmp}" rev-parse HEAD)
fi
if [ "${got}" != "${commit}" ]; then
  echo "fun-graphics: expected ${name} commit ${commit}, got ${got}" >&2
  rm -rf "${tmp}"
  exit 1
fi
rm -rf "${worktree}"
mv "${tmp}" "${worktree}"
printf '%s\n' "${worktree}"
