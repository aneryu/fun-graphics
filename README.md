# fun-graphics

Glue and native-build repository for fun's graphics stack.

fun consumes **one** Zig module (`fun_graphics`) that statically links:

- the Graphite C ABI bridge
- Skia Graphite (when native archives are present)
- Dawn WebGPU (when native archives are present)

Without pinned Dawn/Skia sources, `zig build` links a stub C ABI. GPU entry
points fail with `native graphics not built`. `zig build native` fails closed
until `deps/versions.zig` pins exact commits.

This package does not contain zjs, JS bindings, native windows, or SDL3.

See `docs/graphics.md` in [aneryu/fun](https://github.com/aneryu/fun).
