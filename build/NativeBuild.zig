//! Native Dawn + Skia + bridge builder.
//!
//! Without pinned checkouts this step fails closed. Local overrides:
//! `zig build native -Dskia-src=../skia -Ddawn-src=../dawn`.

const std = @import("std");
const versions = @import("versions");

pub fn failReason() []const u8 {
    if (!versions.isPinned()) {
        return "fun-graphics native build: Skia/Dawn commits are unpinned in deps/versions.zig";
    }
    return "fun-graphics native build: Dawn/Skia sources are not checked out";
}
