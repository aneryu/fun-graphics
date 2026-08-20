# fun-graphics

Glue and native-build repository for fun's graphics stack.

fun consumes **one** Zig module (`fun_graphics`) that statically links:

- the Graphite C ABI bridge
- Skia Graphite (when native archives are present)
- Dawn WebGPU (when native archives are present)

Without pinned Dawn/Skia sources, `zig build` links a stub C ABI. GPU entry
points fail with `native graphics not built`.

Dawn and Skia are pinned in `deps/versions.zig`. `zig build native` fetches
them into `~/.cache/fun-graphics/` and builds:

- Dawn Vulkan-only monolithic `libdawn_monolithic.a`
- Skia Graphite `libskia.a` linked against that Dawn archive (`fun_external_dawn`)

`zig build dawn-smoke` runs `wgpuCreateInstance`.
`zig build graphite-smoke` links Graphite+Dawn.

Linux window surfaces need libX11; the first Dawn archive is built with
`DAWN_USE_X11=OFF` so instance creation works without X11 headers. Enable X11
when `libx11-dev` is available.

This package does not contain zjs, JS bindings, native windows, or SDL3.

See `docs/graphics.md` in [aneryu/fun](https://github.com/aneryu/fun).
