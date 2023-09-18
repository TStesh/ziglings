const std = @import("std");
const builtin = std.builtin;
// const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{
		.preferred_optimize_mode = builtin.OptimizeMode.ReleaseFast
	});
	
    const exe = b.addExecutable(.{
        .name = "sudoku",
        .root_source_file = .{ .path = "src/sudoku.zig" },
        .target = target,
        .optimize = optimize,
		.single_threaded = true,
    });
	exe.strip = true;

    b.installArtifact(exe);
}
