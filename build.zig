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

    const waf = b.addUpdateSourceFiles();
    
    const waf_path = "zig-out/lib/LaggZigLib.asm";
    waf.addCopyFileToSource(lib.getEmittedAsm(), waf_path);
    waf.step.dependOn(&lib.step);
    b.getInstallStep().dependOn(&waf.step);

    const test_step = b.step("test", "Run unit tests");
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    test_step.dependOn(&run_lib_unit_tests.step);
}
