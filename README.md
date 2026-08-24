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
CMake/GN). The relocatable object fun actually links is ~40MB, packed to ~11MB.

`-Dnative=true` looks in `~/.cache/fun-graphics/native/skia-<commit>/lib/`
first (iOS uses a `skia-<commit>-aarch64-ios` suffix so it does not collide
with a macOS object on the same machine). On a cache miss it downloads the
matching tarball from this repo's rolling `nightly` GitHub Release and unpacks.

Current published triples:

| triple | asset | backend |
|---|---|---|
| aarch64-linux | `fun-graphics-native-aarch64-linux.tar.gz` | Vulkan + X11 + Wayland |
| x86_64-linux | `fun-graphics-native-x86_64-linux.tar.gz` | Vulkan + X11 + Wayland |
| aarch64-macos | `fun-graphics-native-aarch64-macos.tar.gz` | Metal |
| aarch64-ios | `fun-graphics-native-aarch64-ios.tar.gz` | Metal (iphoneos) |

Linux x86_64 is produced by `.github/workflows/native-linux.yml` (`ubuntu-24.04`).
macOS aarch64 is produced by `.github/workflows/native-macos.yml` (`macos-14`).
iOS aarch64 is produced by `.github/workflows/native-ios.yml` (`macos-14` + iPhoneOS SDK).
All overwrite the same `nightly` release.

iOS is a cross-compile from macOS:

```bash
# on a Mac with Xcode
zig build native -Dnative-os=ios
zig build pack-native -Dnative-os=ios
```

Device (`iphoneos`) smoke binaries are linked but not executed. Simulator
(`-Dnative-os=ios-simulator`) is supported as a from-source target; there is
no published simulator tarball yet.

Windows / Intel Mac still need `zig build native` on that host, then
`zig build pack-native` + `sh tools/publish_native.sh`.

The repo is private; `gh auth login` or `GH_TOKEN` is required to download.

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

On macOS the Dawn backend is Metal. On iOS (`-Dnative-os=ios`) Dawn/Skia/bridge
are cross-compiled for `iphoneos` / arm64 with the same Metal backend, then
packed as `fun-graphics-native-aarch64-ios.tar.gz`.

`zig build dawn-smoke` runs `wgpuCreateInstance`.
`zig build graphite-smoke` links Graphite+Dawn.
`zig build bridge-smoke` compiles the real Graphite C ABI and runs wrap/flush.
Default `zig build test` still links the stub ABI.

Linux window surfaces need X11 and/or Wayland. `zig build native` enables
`DAWN_USE_X11=ON` when `/usr/include/X11/Xlib.h` is present (or when
`~/.cache/fun-graphics/sysroot` contains those headers, extracted from
`libx11-dev` without root) and `DAWN_USE_WAYLAND=ON` when
`/usr/include/wayland-client.h` is present (`libwayland-dev`).
