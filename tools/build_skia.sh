#!/bin/sh
# Configure and build Skia Graphite against a prebuilt Dawn archive.
set -eu

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <skia-src> <dawn-native-out> <out-dir>" >&2
  exit 2
fi

src=$1
dawn_out=$2
out=$3
jobs=${FUN_GRAPHICS_JOBS:-$(nproc)}
build=${out}/gn

mkdir -p "${build}" "${out}/include" "${out}/lib"

dawn_src_inc="${dawn_out}/include"
dawn_gen_inc="${dawn_out}/include"
dawn_lib="${dawn_out}/lib/libdawn_monolithic.a"

if [ ! -f "${dawn_lib}" ]; then
  echo "fun-graphics: missing Dawn archive ${dawn_lib}" >&2
  exit 1
fi

gn_bin=${src}/bin/gn
ninja_bin=${src}/bin/ninja
if [ ! -x "${ninja_bin}" ]; then
  ninja_bin=$(command -v ninja)
fi

patch_file=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/patches/skia-external-dawn.patch
if [ -f "${patch_file}" ] && ! grep -q fun_external_dawn "${src}/third_party/dawn/args.gni"; then
  git -C "${src}" apply "${patch_file}"
fi

cd "${src}"
"${gn_bin}" gen "${build}" --args="
  is_official_build=true
  is_debug=false
  is_component_build=false
  skia_enable_graphite=true
  skia_use_dawn=true
  skia_enable_ganesh=false
  skia_enable_tools=false
  skia_compile_sksl_tests=false
  skia_compile_modules=false
  skia_use_gl=false
  skia_use_vulkan=false
  skia_use_metal=false
  skia_use_direct3d=false
  skia_enable_pdf=false
  skia_enable_skottie=false
  skia_enable_svg=false
  skia_use_perfetto=false
  skia_use_partition_alloc=false
  skia_use_x11=false
  skia_use_fontconfig=false
  skia_use_icu=false
  skia_use_harfbuzz=false
  skia_use_freetype=false
  skia_use_expat=false
  skia_use_libjpeg_turbo_decode=false
  skia_use_libjpeg_turbo_encode=false
  skia_use_libpng_decode=false
  skia_use_libpng_encode=false
  skia_use_libwebp_decode=false
  skia_use_libwebp_encode=false
  skia_use_wuffs=false
  skia_use_piex=false
  skia_enable_spirv_validation=false
  dawn_enable_vulkan=true
  dawn_enable_d3d11=false
  dawn_enable_d3d12=false
  dawn_enable_metal=false
  dawn_enable_opengles=false
  fun_external_dawn=true
  fun_dawn_source_include_dir=\"${dawn_src_inc}\"
  fun_dawn_generated_include_dir=\"${dawn_gen_inc}\"
  fun_dawn_library=\"${dawn_lib}\"
"

"${ninja_bin}" -C "${build}" skia -j "${jobs}"

if [ -f "${build}/libskia.a" ]; then
  cp -a "${build}/libskia.a" "${out}/lib/libskia.a"
else
  echo "fun-graphics: libskia.a not found in ${build}" >&2
  find "${build}" -name 'libskia*' >&2
  exit 1
fi

printf '%s\n' "${out}/lib/libskia.a"
