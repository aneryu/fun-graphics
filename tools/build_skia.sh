#!/bin/sh
# Configure and build Skia Graphite against a prebuilt Dawn archive.
set -eu

. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/host.sh"

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <skia-src> <dawn-native-out> <out-dir>" >&2
  exit 2
fi

src=$1
dawn_out=$2
out=$3
jobs=$(fun_nproc)
build=${out}/gn

mkdir -p "${build}" "${out}/include" "${out}/lib"

if [ -f "${out}/lib/libskia.a" ] && [ "${FUN_GRAPHICS_FORCE:-0}" != 1 ]; then
  echo "fun-graphics: reusing ${out}/lib/libskia.a" >&2
  printf '%s\n' "${out}/lib/libskia.a"
  exit 0
fi

dawn_src_inc="${dawn_out}/include"
dawn_gen_inc="${dawn_out}/include"
dawn_lib="${dawn_out}/lib/libdawn_monolithic.a"

if [ ! -f "${dawn_lib}" ]; then
  echo "fun-graphics: missing Dawn archive ${dawn_lib}" >&2
  exit 1
fi

gn_bin=${src}/bin/gn
if [ ! -x "${gn_bin}" ] || ! "${gn_bin}" --version >/dev/null 2>&1; then
  python3 "${src}/bin/fetch-gn"
fi
ninja_bin=${src}/bin/ninja
if [ ! -x "${ninja_bin}" ] || ! "${ninja_bin}" --version >/dev/null 2>&1; then
  ninja_bin=$(command -v ninja || true)
fi
if [ -z "${ninja_bin}" ]; then
  python3 "${src}/bin/fetch-ninja"
  ninja_bin=${src}/bin/ninja
fi

patch_file=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/patches/skia-external-dawn.patch
if [ -f "${patch_file}" ] && ! grep -q fun_external_dawn "${src}/third_party/dawn/args.gni"; then
  git -C "${src}" apply "${patch_file}"
fi

# AndroidVulkanMemoryAllocator.cpp needs AMD VMA (`vk_mem_alloc.h`). Skia
# normally pulls it via DEPS into third_party/externals/; we fetch the same pin.
if fun_is_android; then
  vma_dst="${src}/third_party/externals/vulkanmemoryallocator"
  if [ ! -f "${vma_dst}/include/vk_mem_alloc.h" ]; then
    vma_src=$(sh "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/fetch_source.sh" \
      vulkanmemoryallocator \
      "https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git" \
      eb744ea7a2b17040121b4bbb4d6f9e8a77e3cae7)
    mkdir -p "$(dirname "${vma_dst}")"
    rm -rf "${vma_dst}"
    ln -sfn "${vma_src}" "${vma_dst}"
  fi
fi

dawn_enable_vulkan=true
dawn_enable_metal=false
skia_use_vulkan=false
target_cpu_arg=
target_os_arg=
ios_extra=
ndk_arg=
ndk_api_arg=
extra_cflags_arg=
if fun_is_ios; then
  dawn_enable_vulkan=false
  dawn_enable_metal=true
  target_os_arg="target_os=\"ios\""
  target_cpu_arg="target_cpu=\"arm64\""
  ios_extra="ios_min_target=\"$(fun_ios_min)\" skia_ios_use_signing=false skia_use_fonthost_mac=true"
  if [ "$(fun_target)" = "ios-simulator" ]; then
    case "$(fun_arch)" in
      aarch64) target_cpu_arg="target_cpu=\"arm64\"" ;;
      x86_64) target_cpu_arg="target_cpu=\"x64\"" ;;
    esac
    ios_extra="${ios_extra} ios_use_simulator=true"
  fi
elif fun_is_android; then
  ndk_arg="ndk=\"$(fun_require_ndk)\""
  ndk_api_arg="ndk_api=$(fun_android_api)"
  target_os_arg="target_os=\"android\""
  target_cpu_arg="target_cpu=\"$(fun_android_gn_cpu)\""
  # gpu_shared always compiles AndroidVulkanMemoryAllocator.cpp on Android;
  # that needs VulkanMemoryAllocators::Make from skia_use_vulkan/vma.
  skia_use_vulkan=true
  # NDK clang still emits DWARF in official/release GN builds.
  extra_cflags_arg="extra_cflags=[\"-g0\"]"
elif fun_is_macos; then
  dawn_enable_vulkan=false
  dawn_enable_metal=true
  target_os_arg="target_os=\"mac\""
  case "$(fun_arch)" in
    aarch64) target_cpu_arg="target_cpu=\"arm64\"" ;;
    x86_64) target_cpu_arg="target_cpu=\"x64\"" ;;
  esac
fi

cd "${src}"
"${gn_bin}" gen "${build}" --args="
  is_official_build=true
  is_debug=false
  is_component_build=false
  ${extra_cflags_arg}
  ${target_os_arg}
  ${target_cpu_arg}
  ${ios_extra}
  ${ndk_arg}
  ${ndk_api_arg}
  skia_enable_graphite=true
  skia_use_dawn=true
  skia_enable_ganesh=false
  skia_enable_tools=false
  skia_compile_sksl_tests=false
  skia_compile_modules=false
  skia_use_gl=false
  skia_use_vulkan=${skia_use_vulkan}
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
  dawn_enable_vulkan=${dawn_enable_vulkan}
  dawn_enable_d3d11=false
  dawn_enable_d3d12=false
  dawn_enable_metal=${dawn_enable_metal}
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
