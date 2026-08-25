const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const native = b.option(bool, "native", "Link prebuilt Dawn/Skia/bridge archives") orelse false;

    const versions_mod = b.createModule(.{
        .root_source_file = b.path("deps/versions.zig"),
        .target = target,
        .optimize = optimize,
    });

    const versions = @import("deps/versions.zig");
    const home = b.graph.environ_map.get("HOME") orelse "/tmp";
    const android_ndk_opt = b.option([]const u8, "android-ndk", "Android NDK root (llvm-strip for Android native objects)");
    const is_android = target.result.abi.isAndroid();
    const is_ios = target.result.os.tag == .ios;
    const dawn_out = b.fmt("{s}/.cache/fun-graphics/native/dawn-{s}", .{ home, versions.dawn.commit });
    const skia_src = b.fmt("{s}/.cache/fun-graphics/worktrees/skia/{s}", .{ home, versions.skia.commit });
    const skia_out = if (is_android)
        b.fmt("{s}/.cache/fun-graphics/native/android-aarch64/skia-{s}", .{ home, versions.skia.commit })
    else if (is_ios)
        b.fmt("{s}/.cache/fun-graphics/native/ios-aarch64/skia-{s}", .{ home, versions.skia.commit })
    else
        b.fmt("{s}/.cache/fun-graphics/native/skia-{s}", .{ home, versions.skia.commit });
    const native_o = b.fmt("{s}/lib/libfun_graphics_native.o", .{skia_out});

    const mod = b.addModule("fun_graphics", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        // Linux native archives are g++/libstdc++; Zig's -lc++ is LLVM libc++.
        // macOS native uses Apple libc++, which matches Zig's -lc++.
        // Android Bionic uses NDK libc++.
        // iOS native is linked by Apple clang (`-lc++`), not Zig.
        .link_libcpp = !(native and ((target.result.os.tag == .linux and !target.result.abi.isAndroid()) or is_ios)),
    });
    mod.addIncludePath(b.path("include"));
    mod.addImport("versions", versions_mod);
    if (native) {
        const asset = nativeAsset(target.result);
        const fetch = b.addSystemCommand(&.{"sh"});
        fetch.setName("fetch-native");
        fetch.addFileArg(b.path("tools/fetch_native.sh"));
        fetch.addArg(native_o);
        fetch.addArg(versions.native_release.repository);
        fetch.addArg(versions.native_release.tag);
        if (asset) |item| {
            fetch.addArg(item.file);
            fetch.addArg(item.sha256);
        } else {
            fetch.addArg("-");
            fetch.addArg("-");
        }
        const fetched_o = fetch.addOutputFileArg("libfun_graphics_native.o");
        const linked_o = if (is_android and optimize != .Debug) blk: {
            const strip = b.addSystemCommand(&.{"sh"});
            strip.setName("strip-native-debug");
            strip.addFileArg(b.path("tools/strip_debug.sh"));
            strip.addFileArg(fetched_o);
            if (resolveAndroidNdk(b, android_ndk_opt)) |ndk| {
                strip.setEnvironmentVariable("FUN_GRAPHICS_ANDROID_NDK", ndk);
            }
            break :blk strip.addOutputFileArg("libfun_graphics_native.o");
        } else fetched_o;
        b.addNamedLazyPath("native_o", linked_o);
        // iOS final-links this .o with Apple clang; Zig's relocatable object
        // does not absorb it. Other platforms let Zig's linker take it.
        if (!is_ios) {
            mod.addObjectFile(linked_o);
        }
        // Nightly native already contains Canvas 2D v2 (path/text/image). Do not
        // also link tools/build_canvas_v2.sh — that overlay duplicates symbols.

        linkNativeSystem(b, mod, target.result);
        if (target.result.os.tag == .macos) {
            mod.linkFramework("CoreText", .{});
            mod.linkFramework("CoreGraphics", .{});
            mod.linkFramework("CoreFoundation", .{});
            // Image decode uses ImageIO; Skia is built without PNG/JPEG codecs.
            mod.linkFramework("ImageIO", .{});
        }
    } else {
        mod.addCSourceFiles(.{
            .files = &.{
                "src/api.cpp",
                "src/build_info.cpp",
            },
            .flags = &.{
                "-std=c++20",
                "-fno-exceptions",
                "-fno-rtti",
            },
        });
    }

    const lib = b.addLibrary(.{
        .name = "fun_graphics",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    const test_root = if (native)
        b.path("tests/native_link_smoke.zig")
    else
        b.path("tests/static_link_smoke.zig");
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = test_root,
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = !(native and target.result.os.tag == .linux and !target.result.abi.isAndroid()),
            .imports = &.{
                .{ .name = "fun_graphics", .module = mod },
            },
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", if (native)
        "Run fun-graphics native ABI tests"
    else
        "Run fun-graphics stub ABI tests");
    test_step.dependOn(&run_tests.step);

    const versions_tests = b.addTest(.{
        .root_module = versions_mod,
    });
    const run_versions_tests = b.addRunArtifact(versions_tests);
    test_step.dependOn(&run_versions_tests.step);

    const native_step = b.step("native", "Build Dawn (and Skia when pinned) static archives");
    if (!versions.isDawnPinned()) {
        const native_fail = b.addSystemCommand(&.{
            "sh",
            "-c",
            "printf '%s\\n' 'fun-graphics native build: Dawn commit is unpinned in deps/versions.zig' >&2; exit 1",
        });
        native_step.dependOn(&native_fail.step);
    } else {
        const dawn_src = b.fmt("{s}/.cache/fun-graphics/worktrees/dawn/{s}", .{ home, versions.dawn.commit });

        const fetch_dawn = b.addSystemCommand(&.{"sh"});
        fetch_dawn.addFileArg(b.path("tools/fetch_source.sh"));
        fetch_dawn.addArg("dawn");
        fetch_dawn.addArg(versions.dawn.repository);
        fetch_dawn.addArg(versions.dawn.commit);

        const build_dawn = b.addSystemCommand(&.{"sh"});
        build_dawn.addFileArg(b.path("tools/build_dawn.sh"));
        build_dawn.addArg(dawn_src);
        build_dawn.addArg(dawn_out);
        build_dawn.step.dependOn(&fetch_dawn.step);

        native_step.dependOn(&build_dawn.step);

        const dawn_smoke = b.addSystemCommand(&.{"sh"});
        dawn_smoke.addFileArg(b.path("tools/dawn_smoke.sh"));
        dawn_smoke.addArg(dawn_out);
        dawn_smoke.addFileArg(b.path("tests/dawn_smoke.cpp"));
        dawn_smoke.step.dependOn(&build_dawn.step);

        const dawn_smoke_step = b.step("dawn-smoke", "Link and run wgpuCreateInstance against native Dawn");
        dawn_smoke_step.dependOn(&dawn_smoke.step);
        native_step.dependOn(&dawn_smoke.step);

        if (versions.isSkiaPinned()) {
            const fetch_skia = b.addSystemCommand(&.{"sh"});
            fetch_skia.addFileArg(b.path("tools/fetch_source.sh"));
            fetch_skia.addArg("skia");
            fetch_skia.addArg(versions.skia.repository);
            fetch_skia.addArg(versions.skia.commit);

            const build_skia = b.addSystemCommand(&.{"sh"});
            build_skia.addFileArg(b.path("tools/build_skia.sh"));
            build_skia.addArg(skia_src);
            build_skia.addArg(dawn_out);
            build_skia.addArg(skia_out);
            build_skia.step.dependOn(&fetch_skia.step);
            build_skia.step.dependOn(&build_dawn.step);

            const graphite_smoke = b.addSystemCommand(&.{"sh"});
            graphite_smoke.addFileArg(b.path("tools/graphite_smoke.sh"));
            graphite_smoke.addArg(skia_src);
            graphite_smoke.addArg(dawn_out);
            graphite_smoke.addArg(skia_out);
            graphite_smoke.addFileArg(b.path("tests/graphite_smoke.cpp"));
            graphite_smoke.step.dependOn(&build_skia.step);

            const graphite_smoke_step = b.step("graphite-smoke", "Link Graphite+Dawn and run ContextFactory::MakeDawn");
            graphite_smoke_step.dependOn(&graphite_smoke.step);
            native_step.dependOn(&graphite_smoke.step);

            const build_bridge = b.addSystemCommand(&.{"sh"});
            build_bridge.addFileArg(b.path("tools/build_bridge.sh"));
            build_bridge.addArg(skia_src);
            build_bridge.addArg(dawn_out);
            build_bridge.addArg(skia_out);
            build_bridge.addArg(versions.skia.commit);
            build_bridge.addArg(versions.dawn.commit);
            build_bridge.step.dependOn(&build_skia.step);

            const bridge_smoke = b.addSystemCommand(&.{"sh"});
            bridge_smoke.addFileArg(b.path("tools/bridge_smoke.sh"));
            bridge_smoke.addArg(skia_src);
            bridge_smoke.addArg(dawn_out);
            bridge_smoke.addArg(skia_out);
            bridge_smoke.addFileArg(b.path("tests/bridge_smoke.cpp"));
            bridge_smoke.step.dependOn(&build_bridge.step);

            const bridge_smoke_step = b.step("bridge-smoke", "Build Graphite C ABI and run wrap/flush smoke");
            bridge_smoke_step.dependOn(&bridge_smoke.step);
            native_step.dependOn(&bridge_smoke.step);

            const pack_native = b.addSystemCommand(&.{"sh"});
            pack_native.addFileArg(b.path("tools/pack_native.sh"));
            pack_native.addArg(skia_out);
            pack_native.addArg(versions.dawn.commit);
            pack_native.addArg(versions.skia.commit);
            pack_native.step.dependOn(&build_bridge.step);
            const pack_step = b.step("pack-native", "Pack libfun_graphics_native.o into a GitHub Release tarball");
            pack_step.dependOn(&pack_native.step);
        }
    }
}

fn resolveAndroidNdk(b: *std.Build, ndk_opt: ?[]const u8) ?[]const u8 {
    if (ndk_opt) |p| {
        if (p.len > 0) return p;
    }
    if (b.graph.environ_map.get("ANDROID_NDK_HOME")) |p| {
        if (p.len > 0) return p;
    }
    const home = b.graph.environ_map.get("HOME") orelse return null;
    const sdk = b.graph.environ_map.get("ANDROID_HOME") orelse
        b.graph.environ_map.get("ANDROID_SDK_ROOT") orelse
        b.fmt("{s}/Library/Android/sdk", .{home});
    const io = b.graph.io;
    const ndk_root = b.fmt("{s}/ndk", .{sdk});
    var dir = std.Io.Dir.cwd().openDir(io, ndk_root, .{ .iterate = true }) catch return null;
    defer dir.close(io);
    var best: ?[]const u8 = null;
    var it = dir.iterate();
    while (it.next(io) catch return best) |entry| {
        if (entry.kind != .directory and entry.kind != .sym_link) continue;
        if (entry.name.len == 0 or entry.name[0] == '.') continue;
        if (best == null or std.mem.order(u8, entry.name, best.?) == .gt) {
            best = b.dupe(entry.name);
        }
    }
    return if (best) |name| b.fmt("{s}/{s}", .{ ndk_root, name }) else null;
}

fn nativeAsset(result: std.Target) ?@import("deps/versions.zig").NativeAsset {
    const versions = @import("deps/versions.zig");
    if (result.abi.isAndroid()) {
        return switch (result.cpu.arch) {
            .aarch64 => versions.native_android_aarch64,
            else => null,
        };
    }
    return switch (result.os.tag) {
        .linux => switch (result.cpu.arch) {
            .aarch64 => versions.native_linux_aarch64,
            .x86_64 => versions.native_linux_x86_64,
            else => null,
        },
        .macos => switch (result.cpu.arch) {
            .aarch64 => versions.native_macos_aarch64,
            else => null,
        },
        .ios => switch (result.cpu.arch) {
            .aarch64 => versions.native_ios_aarch64,
            else => null,
        },
        else => null,
    };
}

fn linkNativeSystem(b: *std.Build, mod: *std.Build.Module, result: std.Target) void {
    if (result.abi.isAndroid()) {
        mod.linkSystemLibrary("android", .{});
        mod.linkSystemLibrary("log", .{});
        mod.linkSystemLibrary("vulkan", .{});
        mod.linkSystemLibrary("z", .{});
        return;
    }
    switch (result.os.tag) {
        .linux => {
            // Zig maps linkSystemLibrary("stdc++") to LLVM libc++. Dawn/Skia need
            // GNU libstdc++, so pass the host shared objects as linker inputs.
            const gnu_libdir = switch (result.cpu.arch) {
                .aarch64 => "/usr/lib/aarch64-linux-gnu",
                .x86_64 => "/usr/lib/x86_64-linux-gnu",
                else => "/usr/lib",
            };
            mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libstdc++.so.6", .{gnu_libdir}) });
            mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libgcc_s.so.1", .{gnu_libdir}) });
            mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libm.so.6", .{gnu_libdir}) });
            mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libX11.so.6", .{gnu_libdir}) });
            mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libX11-xcb.so.1", .{gnu_libdir}) });
            mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libxcb.so.1", .{gnu_libdir}) });
            mod.addObjectFile(.{ .cwd_relative = b.fmt("{s}/libwayland-client.so.0", .{gnu_libdir}) });
            mod.linkSystemLibrary("z", .{});
        },
        .macos => {
            for ([_][]const u8{
                "Foundation",
                "IOSurface",
                "IOKit",
                "Metal",
                "QuartzCore",
                "Cocoa",
            }) |name| {
                mod.linkFramework(name, .{});
            }
            mod.linkSystemLibrary("z", .{});
        },
        else => {},
    }
}
