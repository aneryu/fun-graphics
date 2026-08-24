const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const native = b.option(bool, "native", "Link prebuilt Dawn/Skia/bridge archives") orelse false;
    const native_os = b.option([]const u8, "native-os", "From-source native OS override: ios | ios-simulator") orelse "";

    const versions_mod = b.createModule(.{
        .root_source_file = b.path("deps/versions.zig"),
        .target = target,
        .optimize = optimize,
    });

    const versions = @import("deps/versions.zig");
    const home = b.graph.environ_map.get("HOME") orelse "/tmp";
    const cache_suffix = nativeCacheSuffix(b, target.result, native_os);
    const dawn_out = b.fmt("{s}/.cache/fun-graphics/native/dawn-{s}{s}", .{ home, versions.dawn.commit, cache_suffix });
    const skia_src = b.fmt("{s}/.cache/fun-graphics/worktrees/skia/{s}", .{ home, versions.skia.commit });
    const skia_out = b.fmt("{s}/.cache/fun-graphics/native/skia-{s}{s}", .{ home, versions.skia.commit, cache_suffix });
    const native_o = b.fmt("{s}/lib/libfun_graphics_native.o", .{skia_out});

    const mod = b.addModule("fun_graphics", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        // Linux native archives are g++/libstdc++; Zig's -lc++ is LLVM libc++.
        // macOS / iOS native uses Apple libc++, which matches Zig's -lc++.
        .link_libcpp = !(native and target.result.os.tag == .linux),
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
        mod.addObjectFile(fetched_o);
        // Nightly native already contains Canvas 2D v2 (path/text/image). Do not
        // also link tools/build_canvas_v2.sh — that overlay duplicates symbols.

        linkNativeSystem(b, mod, target.result);
        switch (target.result.os.tag) {
            .macos => {
                mod.linkFramework("CoreText", .{});
                mod.linkFramework("CoreGraphics", .{});
                mod.linkFramework("CoreFoundation", .{});
                // Image decode uses ImageIO; Skia is built without PNG/JPEG codecs.
                mod.linkFramework("ImageIO", .{});
            },
            .ios => {
                mod.linkFramework("CoreText", .{});
                mod.linkFramework("CoreGraphics", .{});
                mod.linkFramework("CoreFoundation", .{});
                mod.linkFramework("ImageIO", .{});
            },
            else => {},
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
            .link_libcpp = !(native and target.result.os.tag == .linux),
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

    const host_target = b.addSystemCommand(&.{"sh"});
    host_target.setName("host-target");
    host_target.addFileArg(b.path("tests/host_target.sh"));
    test_step.dependOn(&host_target.step);

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
        setNativeOsEnv(fetch_dawn, native_os);

        const build_dawn = b.addSystemCommand(&.{"sh"});
        build_dawn.addFileArg(b.path("tools/build_dawn.sh"));
        build_dawn.addArg(dawn_src);
        build_dawn.addArg(dawn_out);
        build_dawn.step.dependOn(&fetch_dawn.step);
        setNativeOsEnv(build_dawn, native_os);

        native_step.dependOn(&build_dawn.step);

        const dawn_smoke = b.addSystemCommand(&.{"sh"});
        dawn_smoke.addFileArg(b.path("tools/dawn_smoke.sh"));
        dawn_smoke.addArg(dawn_out);
        dawn_smoke.addFileArg(b.path("tests/dawn_smoke.cpp"));
        dawn_smoke.step.dependOn(&build_dawn.step);
        setNativeOsEnv(dawn_smoke, native_os);

        const dawn_smoke_step = b.step("dawn-smoke", "Link and run wgpuCreateInstance against native Dawn");
        dawn_smoke_step.dependOn(&dawn_smoke.step);
        native_step.dependOn(&dawn_smoke.step);

        if (versions.isSkiaPinned()) {
            const fetch_skia = b.addSystemCommand(&.{"sh"});
            fetch_skia.addFileArg(b.path("tools/fetch_source.sh"));
            fetch_skia.addArg("skia");
            fetch_skia.addArg(versions.skia.repository);
            fetch_skia.addArg(versions.skia.commit);
            setNativeOsEnv(fetch_skia, native_os);

            const build_skia = b.addSystemCommand(&.{"sh"});
            build_skia.addFileArg(b.path("tools/build_skia.sh"));
            build_skia.addArg(skia_src);
            build_skia.addArg(dawn_out);
            build_skia.addArg(skia_out);
            build_skia.step.dependOn(&fetch_skia.step);
            build_skia.step.dependOn(&build_dawn.step);
            setNativeOsEnv(build_skia, native_os);

            const graphite_smoke = b.addSystemCommand(&.{"sh"});
            graphite_smoke.addFileArg(b.path("tools/graphite_smoke.sh"));
            graphite_smoke.addArg(skia_src);
            graphite_smoke.addArg(dawn_out);
            graphite_smoke.addArg(skia_out);
            graphite_smoke.addFileArg(b.path("tests/graphite_smoke.cpp"));
            graphite_smoke.step.dependOn(&build_skia.step);
            setNativeOsEnv(graphite_smoke, native_os);

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
            setNativeOsEnv(build_bridge, native_os);

            const bridge_smoke = b.addSystemCommand(&.{"sh"});
            bridge_smoke.addFileArg(b.path("tools/bridge_smoke.sh"));
            bridge_smoke.addArg(skia_src);
            bridge_smoke.addArg(dawn_out);
            bridge_smoke.addArg(skia_out);
            bridge_smoke.addFileArg(b.path("tests/bridge_smoke.cpp"));
            bridge_smoke.step.dependOn(&build_bridge.step);
            setNativeOsEnv(bridge_smoke, native_os);

            const bridge_smoke_step = b.step("bridge-smoke", "Build Graphite C ABI and run wrap/flush smoke");
            bridge_smoke_step.dependOn(&bridge_smoke.step);
            native_step.dependOn(&bridge_smoke.step);

            const pack_native = b.addSystemCommand(&.{"sh"});
            pack_native.addFileArg(b.path("tools/pack_native.sh"));
            pack_native.addArg(skia_out);
            pack_native.addArg(versions.dawn.commit);
            pack_native.addArg(versions.skia.commit);
            pack_native.step.dependOn(&build_bridge.step);
            setNativeOsEnv(pack_native, native_os);
            const pack_step = b.step("pack-native", "Pack libfun_graphics_native.o into a GitHub Release tarball");
            pack_step.dependOn(&pack_native.step);
        }
    }
}

fn nativeCacheSuffix(b: *std.Build, result: std.Target, native_os: []const u8) []const u8 {
    const ios_device = std.mem.eql(u8, native_os, "ios");
    const ios_sim = std.mem.eql(u8, native_os, "ios-simulator");
    const zig_ios = result.os.tag == .ios;
    if (!ios_device and !ios_sim and !zig_ios) return "";
    const simulator = ios_sim or (zig_ios and result.abi == .simulator);
    const arch: []const u8 = switch (result.cpu.arch) {
        .x86_64 => "x86_64",
        else => "aarch64",
    };
    if (simulator) return b.fmt("-{s}-ios-simulator", .{arch});
    return b.fmt("-{s}-ios", .{arch});
}

fn setNativeOsEnv(run: *std.Build.Step.Run, native_os: []const u8) void {
    if (native_os.len != 0) {
        run.setEnvironmentVariable("FUN_GRAPHICS_TARGET", native_os);
    }
}

fn nativeAsset(result: std.Target) ?@import("deps/versions.zig").NativeAsset {
    const versions = @import("deps/versions.zig");
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
        .ios => switch (result.abi) {
            .simulator => null,
            else => switch (result.cpu.arch) {
                .aarch64 => versions.native_ios_aarch64,
                else => null,
            },
        },
        else => null,
    };
}

fn linkNativeSystem(b: *std.Build, mod: *std.Build.Module, result: std.Target) void {
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
        .ios => {
            for ([_][]const u8{
                "Foundation",
                "UIKit",
                "Metal",
                "QuartzCore",
                "CoreGraphics",
                "CoreText",
                "CoreFoundation",
                "IOSurface",
                "ImageIO",
            }) |name| {
                mod.linkFramework(name, .{});
            }
            mod.linkSystemLibrary("z", .{});
        },
        else => {},
    }
}
