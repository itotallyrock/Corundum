const std = @import("std");

fn addLibrary(
    b: *std.Build,
    comptime library_name: []const u8,
    comptime root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: *std.Build.Step.Options,
    all_tests_step: *std.Build.Step,
    all_builds_step: *std.Build.Step,
) *std.Build.Step.Compile {
    const build_step = b.step("build_" ++ library_name ++ "_lib", "Build " ++ library_name ++ " library");
    const test_step = b.step("test_" ++ library_name ++ "_lib", "Run unit tests for " ++ library_name ++ " library");

    const lib_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addOptions("build_options", options);
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = library_name ++ "_lib",
        .root_module = lib_mod,
    });
    build_step.dependOn(&lib.step);
    all_builds_step.dependOn(&lib.step);

    const test_mod = b.addTest(.{
        .name = library_name ++ "_lib_tests",
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(test_mod);
    all_tests_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_lib_unit_tests.step);

    b.installArtifact(lib);

    return lib;
}

fn addBinary(
    b: *std.Build,
    comptime binary_name: []const u8,
    comptime root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: *std.Build.Step.Options,
    all_tests_step: *std.Build.Step,
    all_builds_step: *std.Build.Step,
) *std.Build.Step.Compile {
    const build_step = b.step("build_" ++ binary_name, "Build " ++ binary_name ++ " binary");
    const test_step = b.step("test_" ++ binary_name, "Run unit tests for " ++ binary_name ++ " binary");
    const exe_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addOptions("build_options", options);
    const exe = b.addExecutable(.{
        .linkage = .static,
        .name = binary_name,
        .root_module = exe_mod,
    });
    build_step.dependOn(&exe.step);
    all_builds_step.dependOn(&exe.step);

    const exe_unit_tests = b.addTest(.{
        .name = binary_name ++ "_tests",
        .root_module = exe_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(exe_unit_tests);
    test_step.dependOn(&run_lib_unit_tests.step);
    all_tests_step.dependOn(&run_lib_unit_tests.step);

    b.installArtifact(exe);

    return exe;
}

/// Setup the build
pub fn build(b: *std.Build) void {
    // Build options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_options = b.addOptions();
    build_options.addOption(u256, "zobrist_seed", 0xEB1EDE23CD04F71760E7A908AEB122BBE48D0CF561AEC147678AC2F99E68E420);

    // Libraries
    const build_libraries = b.step("build_libs", "Build all libraries");
    const test_libraries = b.step("test_libs", "Test all libraries");
    _ = addLibrary(b, "uci", "./projects/uci/src/root.zig", target, optimize, build_options, test_libraries, build_libraries);
    _ = addLibrary(b, "chess", "./projects/chess/src/root.zig", target, optimize, build_options, test_libraries, build_libraries);
    _ = addLibrary(b, "corundum", "./src/root.zig", target, optimize, build_options, test_libraries, build_libraries);

    // Binaries
    const build_binaries = b.step("build_bins", "Build all binaries");
    const test_binaries = b.step("test_bins", "Test all binaries");
    const exe = addBinary(b, "corundum", "./src/main.zig", target, optimize, build_options, test_binaries, build_binaries);

    // Run the default executable
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    run_step.dependOn(&run_cmd.step);

    // Grouped build steps
    var build_all = b.step("all", "Build all binaries and libraries");
    build_all.dependOn(build_libraries);
    build_all.dependOn(build_binaries);

    var test_all = b.step("test", "Test all binaries and libraries");
    test_all.dependOn(test_libraries);
    test_all.dependOn(test_binaries);
}
