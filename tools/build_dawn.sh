#!/bin/sh
# Configure and build Dawn as a monolithic static library for the host GPU API.
set -eu

. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/host.sh"

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <dawn-src> <out-dir>" >&2
  exit 2
fi

src=$1
out=$2
build=${out}/build
jobs=$(fun_nproc)

mkdir -p "${out}/include" "${out}/lib"

if [ -f "${out}/lib/libdawn_monolithic.a" ] && [ "${FUN_GRAPHICS_FORCE:-0}" != 1 ]; then
  echo "fun-graphics: reusing ${out}/lib/libdawn_monolithic.a" >&2
  printf '%s\n' "${out}/lib/libdawn_monolithic.a"
  exit 0
fi

# Drop a failed CMake cache so new generator flags actually apply.
rm -rf "${build}"
mkdir -p "${build}"

patch_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/patches
tint_cc="${src}/src/tint/lang/core/ir/transform/multiplanar_external_texture.cc"
if [ -f "${patch_dir}/dawn-overloaded-ctad.patch" ] && [ -f "${tint_cc}" ] && ! grep -q 'overloaded(Ts...)' "${tint_cc}"; then
  git -C "${src}" apply "${patch_dir}/dawn-overloaded-ctad.patch"
fi
srm_cc="${src}/src/dawn/native/SharedResourceMemory.cpp"
if [ -f "${patch_dir}/dawn-structured-binding-capture.patch" ] && [ -f "${srm_cc}" ] && ! grep -q 'fencePtr' "${srm_cc}"; then
  git -C "${src}" apply "${patch_dir}/dawn-structured-binding-capture.patch"
fi

home=${HOME:-/tmp}
sysroot="${home}/.cache/fun-graphics/sysroot"
cmake_extra=
dawn_enable_vulkan=OFF
dawn_enable_metal=OFF
dawn_use_x11=OFF

if fun_is_macos; then
  dawn_enable_metal=ON
  cmake_extra="-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"
else
  dawn_enable_vulkan=ON
  x11_inc=
  if [ -f "${sysroot}/usr/include/X11/Xlib.h" ] && [ -f "${sysroot}/usr/include/X11/Xlib-xcb.h" ]; then
    dawn_use_x11=ON
    libdir=/usr/lib/$(uname -m)-linux-gnu
    mkdir -p "${sysroot}${libdir}"
    [ -e "${sysroot}${libdir}/libX11.so" ] || \
      ln -sfn "${libdir}/libX11.so.6" "${sysroot}${libdir}/libX11.so"
    [ -e "${sysroot}${libdir}/libX11-xcb.so" ] || \
      ln -sfn "${libdir}/libX11-xcb.so.1" "${sysroot}${libdir}/libX11-xcb.so"
    [ -e "${sysroot}${libdir}/libxcb.so" ] || \
      ln -sfn "${libdir}/libxcb.so.1" "${sysroot}${libdir}/libxcb.so"
    x11_inc="-I${sysroot}/usr/include"
    cmake_extra="${cmake_extra} \
      -DCMAKE_C_FLAGS=${x11_inc} \
      -DCMAKE_CXX_FLAGS=${x11_inc} \
      -DCMAKE_PREFIX_PATH=${sysroot}/usr \
      -DCMAKE_INCLUDE_PATH=${sysroot}/usr/include \
      -DCMAKE_LIBRARY_PATH=${sysroot}${libdir} \
      -DX11_INCLUDE_DIR=${sysroot}/usr/include \
      -DX11_X11_INCLUDE_PATH=${sysroot}/usr/include \
      -DX11_X11_LIB=${sysroot}${libdir}/libX11.so"
  elif [ -f /usr/include/X11/Xlib.h ] && [ -f /usr/include/X11/Xlib-xcb.h ]; then
    dawn_use_x11=ON
  fi
fi

generator=
if command -v ninja >/dev/null 2>&1; then
  generator="-G Ninja"
fi

# CMake 3.28+ on Ubuntu 24.04 scans C++ modules for dawncpp_module and
# errors because GCC has no import-graph discovery.
# shellcheck disable=SC2086
cmake -S "${src}" -B "${build}" ${generator} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_SCAN_FOR_MODULES=OFF \
  ${cmake_extra} \
  -DBUILD_SHARED_LIBS=OFF \
  -DDAWN_BUILD_MONOLITHIC_LIBRARY=STATIC \
  -DDAWN_ENABLE_INSTALL=OFF \
  -DDAWN_BUILD_SAMPLES=OFF \
  -DDAWN_BUILD_TESTS=OFF \
  -DDAWN_FETCH_DEPENDENCIES=ON \
  -DDAWN_ENABLE_VULKAN="${dawn_enable_vulkan}" \
  -DDAWN_ENABLE_DESKTOP_GL=OFF \
  -DDAWN_ENABLE_OPENGLES=OFF \
  -DDAWN_ENABLE_METAL="${dawn_enable_metal}" \
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
