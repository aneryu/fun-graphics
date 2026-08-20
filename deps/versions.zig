//! Compile-time lock for the Skia + Dawn pair consumed by fun-graphics.
//! The compatible combination's only source of truth is this file (and the
//! fun-graphics commit that contains it). See fun docs/graphics.md §2.

pub const recipe_version: u32 = 1;

pub const skia = .{
    .repository = "https://github.com/google/skia.git",
    .commit = "25531e4cb95761278f0a563072b07f1024fe3f60",
};

pub const dawn = .{
    .repository = "https://github.com/google/dawn.git",
    .commit = "e5958a4fe03fac5c8fec7479a46aa7e4e188a0f8",
};

/// Prebuilt native relocatable objects live on GitHub Releases of this repo.
/// Cache miss at `-Dnative=true` downloads the matching tarball instead of
/// compiling Dawn/Skia. `zig build native` remains the from-source fallback.
pub const native_release = .{
    .repository = "aneryu/fun-graphics",
    .tag = "native-r1",
};

pub const NativeAsset = struct {
    file: []const u8,
    sha256: []const u8,
};

pub const native_linux_aarch64 = NativeAsset{
    .file = "fun-graphics-native-aarch64-linux.tar.gz",
    .sha256 = "ba3ea1ef33d83a1367e198757d1c101a114dcba9048b99931ce6ecda5c151e15",
};

pub const native_macos_aarch64 = NativeAsset{
    .file = "fun-graphics-native-aarch64-macos.tar.gz",
    .sha256 = "054c2621aeb052f35f6f2eb097f55d162f33b2ec98f14f810190f78b991ad172",
};

pub fn isDawnPinned() bool {
    return !isUnpinned(dawn.commit);
}

pub fn isSkiaPinned() bool {
    return !isUnpinned(skia.commit);
}

pub fn isPinned() bool {
    return isDawnPinned() and isSkiaPinned();
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
    try std.testing.expectEqualStrings("https://github.com/google/skia.git", skia.repository);
    try std.testing.expectEqualStrings("https://github.com/google/dawn.git", dawn.repository);
    try std.testing.expectEqual(@as(usize, 40), dawn.commit.len);
    try std.testing.expectEqual(@as(usize, 40), skia.commit.len);
    try std.testing.expectEqualStrings("aneryu/fun-graphics", native_release.repository);
    try std.testing.expectEqualStrings("native-r1", native_release.tag);
    try std.testing.expectEqual(@as(usize, 64), native_linux_aarch64.sha256.len);
    try std.testing.expectEqualStrings("fun-graphics-native-aarch64-macos.tar.gz", native_macos_aarch64.file);
    try std.testing.expectEqual(@as(usize, 64), native_macos_aarch64.sha256.len);
}
