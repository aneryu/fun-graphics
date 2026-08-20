//! Native-level smoke: the Zig module links the real Graphite C ABI.

const std = @import("std");
const fun_graphics = @import("fun_graphics");

test "build info reports native Graphite recipe" {
    const info = fun_graphics.getBuildInfo();
    try std.testing.expectEqual(@as(u32, 2), info.api_version);
    try std.testing.expectEqualStrings("native", info.build_id);
    try std.testing.expectEqual(@as(usize, 40), info.skia_commit.len);
    try std.testing.expectEqual(@as(usize, 40), info.dawn_commit.len);
    try std.testing.expectEqual(@as(u32, 1), fun_graphics.versions.recipe_version);
}

test "context create rejects null Dawn handles" {
    try std.testing.expectError(error.InvalidArgument, fun_graphics.contextCreate(null, null, null));
}

test "direct C ABI does not return the stub message" {
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
    try std.testing.expectEqual(@as(@TypeOf(status), fun_graphics.c.FG_STATUS_INVALID_ARGUMENT), status);
    try std.testing.expect(out_context == null);
    try std.testing.expect(err.message != null);
    const message = std.mem.span(err.message);
    try std.testing.expect(std.mem.indexOf(u8, message, "native graphics not built") == null);
}
