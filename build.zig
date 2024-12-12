const std = @import("std");

// fn addBackendOption(b: *std.Build, exe: *std.Build.Step.Compile) []const u8 {
//     const desc = "Backend to use for camera\n" ++
//         "\t\t\t\tOptions:\n" ++
//         "\t\t\t\tSDL3\n" ++
//         "\t\t\t\topencv (zig-cv)\n";
//     const backend = b.option([]const u8, "backend", desc) orelse "SDL3";
//     const options = b.addOptions();
//     options.addOption([]const u8, "backend", backend);
//     exe.root_module.addOptions("config", options);
//     return backend;
// }

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "cam",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // raylib
    const raylib_dep = b.dependency("raylib-zig", .{ .target = target, .optimize = optimize });
    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    exe.linkSystemLibrary("SDL3");
    exe.linkLibC();
    b.installArtifact(exe);

    // run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
