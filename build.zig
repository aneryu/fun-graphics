const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const versions_mod = b.createModule(.{
        .root_source_file = b.path("deps/versions.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("fun_graphics", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    mod.addIncludePath(b.path("include"));
    mod.addImport("versions", versions_mod);
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

    const lib = b.addLibrary(.{
        .name = "fun_graphics",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/static_link_smoke.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
            .imports = &.{
                .{ .name = "fun_graphics", .module = mod },
            },
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run fun-graphics stub ABI tests");
    test_step.dependOn(&run_tests.step);

    const versions_tests = b.addTest(.{
        .root_module = versions_mod,
    });
    const run_versions_tests = b.addRunArtifact(versions_tests);
    test_step.dependOn(&run_versions_tests.step);

    const versions = @import("deps/versions.zig");
    const native_step = b.step("native", "Build Dawn (and Skia when pinned) static archives");
    if (!versions.isDawnPinned()) {
        const native_fail = b.addSystemCommand(&.{
            "sh",
            "-c",
            "printf '%s\\n' 'fun-graphics native build: Dawn commit is unpinned in deps/versions.zig' >&2; exit 1",
        });
        native_step.dependOn(&native_fail.step);
    } else {
        const home = b.graph.environ_map.get("HOME") orelse "/tmp";
        const dawn_src = b.fmt("{s}/.cache/fun-graphics/worktrees/dawn/{s}", .{ home, versions.dawn.commit });
        const dawn_out = b.fmt("{s}/.cache/fun-graphics/native/dawn-{s}", .{ home, versions.dawn.commit });

        const fetch_dawn = b.addSystemCommand(&.{ "sh" });
        fetch_dawn.addFileArg(b.path("tools/fetch_source.sh"));
        fetch_dawn.addArg("dawn");
        fetch_dawn.addArg(versions.dawn.repository);
        fetch_dawn.addArg(versions.dawn.commit);

        const build_dawn = b.addSystemCommand(&.{ "sh" });
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
            const skia_src = b.fmt("{s}/.cache/fun-graphics/worktrees/skia/{s}", .{ home, versions.skia.commit });
            const skia_out = b.fmt("{s}/.cache/fun-graphics/native/skia-{s}", .{ home, versions.skia.commit });

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
        }
    }
}
