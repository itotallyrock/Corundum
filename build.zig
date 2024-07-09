const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_name = b.option(
        []const u8,
        "exe_name",
        "Name of the executable",
    ) orelse "corundum";

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", "0.0.1");

    const mecha_dep = b.dependency("mecha", .{
        .target = target,
        .optimize = optimize,
    });

    // Add the main executable
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addOptions("build_options", build_options);
    exe.root_module.addImport("mecha", mecha_dep.module("mecha"));

    b.installArtifact(exe);

    b.step("run", "Run the application").dependOn(&b.addRunArtifact(exe).step);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_tests.root_module.addOptions("build_options", build_options);
    main_tests.root_module.addImport("mecha", mecha_dep.module("mecha"));

    b.step("test", "Run tests").dependOn(&b.addRunArtifact(main_tests).step);
}
