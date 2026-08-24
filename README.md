# fun-graphics

Glue and native-build repository for fun's graphics stack.

Canonical repo: https://github.com/aneryu/fun-graphics  
Consumed by [aneryu/fun](https://github.com/aneryu/fun) as a git submodule at
`third_party/fun-graphics`.

fun consumes **one** Zig module (`fun_graphics`) that statically links:

- the Graphite C ABI bridge
- Skia Graphite (when native archives are present)
- Dawn WebGPU (when native archives are present)

Without pinned Dawn/Skia sources, `zig build` links a stub C ABI. GPU entry
points fail with `native graphics not built`. After a native object is present
(from a GitHub Release or `zig build native`), `zig build test -Dnative=true`
links the real Graphite C ABI.

This package does not contain zjs, JS bindings, native windows, or SDL3.
See `docs/graphics.md` in fun.

## Prebuilt native archives (GitHub Releases)

Compiling Dawn + Skia from source is the expensive path (multi-GB cache,
CMake/GN). The relocatable object fun actually links is ~40MB, packed to ~11MB
(DWARF is stripped after `ld -r`; Android otherwise ships ~300MB of
debug info and packs to ~116MB).

`-Dnative=true` looks in `~/.cache/fun-graphics/native/skia-<commit>/lib/`
first. On a cache miss it downloads the matching tarball from this repo's
rolling `nightly` GitHub Release and unpacks. There is no versioned native-rN
channel; `nightly` is the only published artifact set.

Current published triples:

| triple | asset | backend |
|---|---|---|
| aarch64-linux | `fun-graphics-native-aarch64-linux.tar.gz` | Vulkan + X11 + Wayland |
| x86_64-linux | `fun-graphics-native-x86_64-linux.tar.gz` | Vulkan + X11 + Wayland |
| aarch64-macos | `fun-graphics-native-aarch64-macos.tar.gz` | Metal |
| aarch64-android | `fun-graphics-native-aarch64-android.tar.gz` | Vulkan + ANativeWindow |

Linux x86_64 is produced by `.github/workflows/native-linux.yml` (`ubuntu-24.04`).
macOS aarch64 is produced by `.github/workflows/native-macos.yml` (`macos-14`).
Android aarch64 is produced by `.github/workflows/native-android.yml` (`ubuntu-24.04` + NDK r27c).
All overwrite the same `nightly` release.

The repo is private; `gh auth login` or `GH_TOKEN` is required to download.
Windows / Intel Mac still need `zig build native` on that host, then
`zig build pack-native` + `sh tools/publish_native.sh`.

```bash
# cheap path: download prebuilt, then link
zig build test -Dnative=true

# from-source fallback
zig build native
zig build pack-native
```

Dawn and Skia commits are locked in `deps/versions.zig`. `zig build native`
fetches them into `~/.cache/fun-graphics/` and builds:

- Dawn Vulkan-only monolithic `libdawn_monolithic.a`
- Skia Graphite `libskia.a` linked against that Dawn archive (`fun_external_dawn`)
- Graphite C ABI + `ld -r --whole-archive` → `libfun_graphics_native.o`

`zig build dawn-smoke` runs `wgpuCreateInstance`.
`zig build graphite-smoke` links Graphite+Dawn.
`zig build bridge-smoke` compiles the real Graphite C ABI and runs wrap/flush.
Default `zig build test` still links the stub ABI.

Linux window surfaces need X11 and/or Wayland. `zig build native` enables
`DAWN_USE_X11=ON` when `/usr/include/X11/Xlib.h` is present (or when
`~/.cache/fun-graphics/sysroot` contains those headers, extracted from
`libx11-dev` without root) and `DAWN_USE_WAYLAND=ON` when
`/usr/include/wayland-client.h` is present (`libwayland-dev`).

## Android (NDK cross-compile)

Android is Vulkan-only. fun-graphics does not create Activities or JNI;
it builds Dawn/Skia/bridge for the NDK and links `-landroid -llog -lvulkan`.
Windows still belong to fun, which wraps an `ANativeWindow*` for Dawn's
`WGPUSurfaceSourceAndroidNativeWindow`.

Default ABI is `arm64-v8a`, API 26 (Vulkan floor). Requires NDK r26+ and a
host `protoc` (`protobuf-compiler`) so Dawn can generate protobuf sources
while the NDK clang targets Android.

```bash
export ANDROID_NDK_HOME=/path/to/android-ndk-r27c
zig build native -Dandroid
zig build pack-native -Dandroid
# asset: fun-graphics-native-aarch64-android.tar.gz
```

Other ABIs (not published on `nightly` by default):

```bash
zig build native -Dandroid -Dandroid-abi=x86_64
# or: FUN_GRAPHICS_ANDROID_ABI=armeabi-v7a zig build native -Dandroid
```

Cache paths are triple-suffixed (`dawn-<commit>-aarch64-android`) so an
Android build does not overwrite a host Linux archive. Smoke binaries are
linked with the NDK but not executed on the build host.

Consume from fun:

```bash
zig build -Dgraphics-native=true -Dtarget=aarch64-linux-android.26 \
  --sysroot "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
```
