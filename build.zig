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

    const native_step = b.step("native", "Build Dawn + Skia + bridge static archives");
    const native_fail = b.addSystemCommand(&.{
        "sh",
        "-c",
        "printf '%s\\n' 'fun-graphics native build: Skia/Dawn commits are unpinned in deps/versions.zig' >&2; exit 1",
    });
    native_step.dependOn(&native_fail.step);
}
