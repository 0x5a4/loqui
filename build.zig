const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "loqui",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Dependencies
    const ansi_term_dep = b.dependency("ansi_term", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("ansi-term", ansi_term_dep.module("ansi-term"));

    const tomlz_dep = b.dependency("tomlz", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("tomlz", tomlz_dep.module("tomlz"));
    
    b.installArtifact(exe);

    // Run Step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test Step
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Play Step
    const play_cmd = b.addRunArtifact(exe);
    play_cmd.step.dependOn(b.getInstallStep());

    const default_args = b.allocator.dupe(u8, "game") catch unreachable;
    play_cmd.addArgs(&[_][]const u8{default_args});

    const play_step = b.step("play", "Run the app. Automatically sets the content dir to './game'");
    play_step.dependOn(&play_cmd.step);
}

