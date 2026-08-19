//! Compile-time lock for the Skia + Dawn pair consumed by fun-graphics.
//! The compatible combination's only source of truth is this file (and the
//! fun-graphics commit that contains it). See fun docs/graphics.md §2.

pub const recipe_version: u32 = 1;

pub const skia = .{
    .repository = "git@github.com:aneryu/skia.git",
    .commit = "unpinned",
};

pub const dawn = .{
    .repository = "git@github.com:aneryu/dawn.git",
    .commit = "unpinned",
};

pub fn isPinned() bool {
    return !isUnpinned(skia.commit) and !isUnpinned(dawn.commit);
}

fn isUnpinned(commit: []const u8) bool {
    return commit.len == 0 or std_eql(commit, "unpinned");
}

fn std_eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (x != y) return false;
    }
    return true;
}

test "recipe lock is version 1" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 1), recipe_version);
    try std.testing.expectEqualStrings("git@github.com:aneryu/skia.git", skia.repository);
    try std.testing.expectEqualStrings("git@github.com:aneryu/dawn.git", dawn.repository);
}
