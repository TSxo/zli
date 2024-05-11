const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("zli", .{
        .root_source_file = .{
            .path = "src/zli.zig",
        },
    });

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
        .optimize = optimize,
        .target = target,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const examples_step = b.step("examples", "Build all the example");

    inline for (.{ "subcommands", "args", "simple" }) |name| {
        const example = b.addExecutable(.{
            .name = name,
            .root_source_file = .{
                .path = b.fmt("example/{s}.zig", .{name}),
            },
            .target = target,
            .optimize = optimize,
        });
        const install_example = b.addInstallArtifact(example, .{});
        example.root_module.addImport("zli", module);
        examples_step.dependOn(&example.step);
        examples_step.dependOn(&install_example.step);
    }
}
