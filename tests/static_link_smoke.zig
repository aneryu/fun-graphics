//! Native-level smoke: the Zig module links the C ABI and the stub strategy
//! fails clearly when Dawn/Skia archives are not present.

const std = @import("std");
const fun_graphics = @import("fun_graphics");

test "build info reports API version 1" {
    const info = fun_graphics.getBuildInfo();
    try std.testing.expectEqual(@as(u32, 1), info.api_version);
    try std.testing.expectEqual(@as(u32, 1), fun_graphics.versions.recipe_version);
}

test "context create fails clearly without native archives" {
    const result = fun_graphics.contextCreate(null, null, null);
    try std.testing.expectError(error.InternalError, result);
}

test "direct C ABI context create reports internal error" {
    var descriptor = fun_graphics.c.FGContextDescriptor{
        .struct_size = @sizeOf(fun_graphics.c.FGContextDescriptor),
        .instance = null,
        .device = null,
        .queue = null,
    };
    var out_context: ?*fun_graphics.c.FGContext = @ptrFromInt(1);
    var err = fun_graphics.c.FGError{
        .code = fun_graphics.c.FG_STATUS_OK,
        .message = null,
        .message_length = 0,
    };
    const status = fun_graphics.c.fg_context_create(&descriptor, &out_context, &err);
    try std.testing.expectEqual(@as(@TypeOf(status), fun_graphics.c.FG_STATUS_INTERNAL_ERROR), status);
    try std.testing.expect(out_context == null);
    try std.testing.expect(err.message != null);
    try std.testing.expect(err.message_length > 0);
    const message = std.mem.span(err.message);
    try std.testing.expect(std.mem.indexOf(u8, message, "native graphics not built") != null);
}
