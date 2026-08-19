//! Zig package facade for fun-graphics.
//!
//! This module is the only thing fun imports. It re-exports the C ABI
//! (`fun_graphics.h` + stub or Dawn `webgpu.h`) and the compile-time recipe
//! lock. Native Skia/Dawn archives are linked by `build.zig` when present.

const std = @import("std");

pub const versions = @import("versions");

pub const c = @cImport({
    @cInclude("webgpu/webgpu.h");
    @cInclude("fun_graphics.h");
});

pub const Status = enum(c_uint) {
    ok = 0,
    invalid_argument = 1,
    out_of_memory = 2,
    device_lost = 3,
    internal_error = 4,
};

pub const BuildInfo = struct {
    api_version: u32,
    build_id: []const u8,
    skia_commit: []const u8,
    dawn_commit: []const u8,
};

pub fn getBuildInfo() BuildInfo {
    const info = c.fg_get_build_info();
    return .{
        .api_version = info.*.api_version,
        .build_id = cstr(info.*.build_id),
        .skia_commit = cstr(info.*.skia_commit),
        .dawn_commit = cstr(info.*.dawn_commit),
    };
}

pub const ContextCreateError = error{
    InvalidArgument,
    OutOfMemory,
    DeviceLost,
    InternalError,
};

pub fn contextCreate(
    instance: c.WGPUInstance,
    device: c.WGPUDevice,
    queue: c.WGPUQueue,
) ContextCreateError!?*c.FGContext {
    var descriptor = c.FGContextDescriptor{
        .struct_size = @sizeOf(c.FGContextDescriptor),
        .instance = instance,
        .device = device,
        .queue = queue,
    };
    var out_context: ?*c.FGContext = null;
    var err = c.FGError{
        .code = c.FG_STATUS_OK,
        .message = null,
        .message_length = 0,
    };
    const status = c.fg_context_create(&descriptor, &out_context, &err);
    return switch (status) {
        c.FG_STATUS_OK => out_context,
        c.FG_STATUS_INVALID_ARGUMENT => error.InvalidArgument,
        c.FG_STATUS_OUT_OF_MEMORY => error.OutOfMemory,
        c.FG_STATUS_DEVICE_LOST => error.DeviceLost,
        else => error.InternalError,
    };
}

fn cstr(ptr: [*c]const u8) []const u8 {
    if (ptr == null) return "";
    return std.mem.span(ptr);
}
