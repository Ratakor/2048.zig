const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "2048",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = b.option(bool, "strip", "Strip the binary") orelse switch (optimize) {
            .Debug, .ReleaseSafe => false,
            .ReleaseFast, .ReleaseSmall => true,
        },
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const board_tests = b.addTest(.{
        .root_source_file = b.path("src/Board.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(board_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const release = b.step("release", "Make an upstream binary release");
    const release_targets = &[_][]const u8{
        "aarch64-linux", "x86_64-linux", "x86-linux", "riscv64-linux",
    };
    for (release_targets) |target_string| {
        const rel_exe = b.addExecutable(.{
            .name = "2048",
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(std.Target.Query.parse(.{
                .arch_os_abi = target_string,
            }) catch unreachable),
            .optimize = .ReleaseSafe,
            .strip = true,
        });

        const install = b.addInstallArtifact(rel_exe, .{});
        install.dest_dir = .prefix;
        install.dest_sub_path = b.fmt("{s}-{s}", .{ target_string, rel_exe.name });

        release.dependOn(&install.step);
    }

    const fmt_step = b.step("fmt", "Format all source files");
    fmt_step.dependOn(&b.addFmt(.{ .paths = &.{ "build.zig", "src" } }).step);

    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
}
