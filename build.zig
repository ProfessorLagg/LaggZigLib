const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/_root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "LaggZigLib",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    const lib_waf = b.addUpdateSourceFiles();
    const lib_waf_path = "zig-out/lib/LaggZigLib.asm";
    lib_waf.addCopyFileToSource(lib.getEmittedAsm(), lib_waf_path);
    lib_waf.step.dependOn(&lib.step);
    b.getInstallStep().dependOn(&lib_waf.step);

    const test_step = b.step("test", "Run unit tests");
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
        .test_runner = .{ .path = b.path("src/test_runner.zig"), .mode = .simple },
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    test_step.dependOn(&run_lib_unit_tests.step);

    const exe = b.addExecutable(.{
        .name = "LaggZigLib_dbg",
        .root_source_file = b.path("src/_dbg.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
        .link_libc = false,
    });
    b.installArtifact(exe);

    const exe_waf = b.addUpdateSourceFiles();
    const exe_waf_path = "zig-out/bin/LaggZigLib_dbg.asm";
    exe_waf.addCopyFileToSource(exe.getEmittedAsm(), exe_waf_path);
    exe_waf.step.dependOn(&exe.step);
    b.getInstallStep().dependOn(&exe_waf.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the debugger");
    run_step.dependOn(&run_cmd.step);
}
