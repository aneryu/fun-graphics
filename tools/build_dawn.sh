#!/bin/sh
# Configure and build Dawn as a Vulkan-only monolithic static library.
set -eu

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <dawn-src> <out-dir>" >&2
  exit 2
fi

src=$1
out=$2
build=${out}/build
jobs=${FUN_GRAPHICS_JOBS:-$(nproc)}

mkdir -p "${build}" "${out}/include" "${out}/lib"

home=${HOME:-/tmp}
sysroot="${home}/.cache/fun-graphics/sysroot"
dawn_use_x11=OFF
x11_inc=
if [ -f "${sysroot}/usr/include/X11/Xlib.h" ] && [ -f "${sysroot}/usr/include/X11/Xlib-xcb.h" ]; then
  dawn_use_x11=ON
  mkdir -p "${sysroot}/usr/lib/aarch64-linux-gnu"
  [ -e "${sysroot}/usr/lib/aarch64-linux-gnu/libX11.so" ] || \
    ln -sfn /usr/lib/aarch64-linux-gnu/libX11.so.6 "${sysroot}/usr/lib/aarch64-linux-gnu/libX11.so"
  [ -e "${sysroot}/usr/lib/aarch64-linux-gnu/libX11-xcb.so" ] || \
    ln -sfn /usr/lib/aarch64-linux-gnu/libX11-xcb.so.1 "${sysroot}/usr/lib/aarch64-linux-gnu/libX11-xcb.so"
  [ -e "${sysroot}/usr/lib/aarch64-linux-gnu/libxcb.so" ] || \
    ln -sfn /usr/lib/aarch64-linux-gnu/libxcb.so.1 "${sysroot}/usr/lib/aarch64-linux-gnu/libxcb.so"
  x11_inc="-I${sysroot}/usr/include"
fi

cmake -S "${src}" -B "${build}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="${x11_inc}" \
  -DCMAKE_CXX_FLAGS="${x11_inc}" \
  -DCMAKE_PREFIX_PATH="${sysroot}/usr" \
  -DCMAKE_INCLUDE_PATH="${sysroot}/usr/include" \
  -DCMAKE_LIBRARY_PATH="${sysroot}/usr/lib/aarch64-linux-gnu" \
  -DX11_INCLUDE_DIR="${sysroot}/usr/include" \
  -DX11_X11_INCLUDE_PATH="${sysroot}/usr/include" \
  -DX11_X11_LIB="${sysroot}/usr/lib/aarch64-linux-gnu/libX11.so" \
  -DBUILD_SHARED_LIBS=OFF \
  -DDAWN_BUILD_MONOLITHIC_LIBRARY=STATIC \
  -DDAWN_ENABLE_INSTALL=OFF \
  -DDAWN_BUILD_SAMPLES=OFF \
  -DDAWN_BUILD_TESTS=OFF \
  -DDAWN_FETCH_DEPENDENCIES=ON \
  -DDAWN_ENABLE_VULKAN=ON \
  -DDAWN_ENABLE_DESKTOP_GL=OFF \
  -DDAWN_ENABLE_OPENGLES=OFF \
  -DDAWN_ENABLE_METAL=OFF \
  -DDAWN_ENABLE_D3D11=OFF \
  -DDAWN_ENABLE_D3D12=OFF \
  -DDAWN_ENABLE_NULL=ON \
  -DDAWN_USE_WAYLAND=OFF \
  -DDAWN_USE_X11="${dawn_use_x11}" \
  -DDAWN_USE_GLFW=OFF \
  -DTINT_BUILD_CMD_TOOLS=OFF \
  -DTINT_BUILD_TESTS=OFF \
  -DTINT_BUILD_GLSL_VALIDATOR=OFF

cmake --build "${build}" --target webgpu_dawn -j "${jobs}"

# Headers: public Dawn tree, then generated webgpu.h on top.
if [ -d "${src}/include" ]; then
  cp -a "${src}/include/." "${out}/include/"
fi
if [ -d "${build}/gen/include" ]; then
  cp -a "${build}/gen/include/." "${out}/include/"
fi

# Locate the monolithic archive without guessing a single filename.
found=
for cand in \
  "${build}/src/dawn/native/libwebgpu_dawn.a" \
  "${build}/src/dawn/native/libdawn_native.a" \
  "${build}/libwebgpu_dawn.a" \
  "${build}/lib/libwebgpu_dawn.a"
do
  if [ -f "${cand}" ]; then
    found=${cand}
    break
  fi
done
if [ -z "${found}" ]; then
  found=$(find "${build}" -name 'libwebgpu_dawn.a' -o -name 'libdawn.a' | head -n 1 || true)
fi
if [ -z "${found}" ]; then
  echo "fun-graphics: could not find Dawn monolithic static library under ${build}" >&2
  find "${build}" -name '*.a' | head -n 40 >&2
  exit 1
fi
cp -a "${found}" "${out}/lib/libdawn_monolithic.a"

printf '%s\n' "${out}/lib/libdawn_monolithic.a"
