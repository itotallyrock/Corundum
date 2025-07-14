const std = @import("std");

const app_name = "corundum";
const app_prefix = app_name ++ "_";

fn addLibrary(
    b: *std.Build,
    comptime step_name: []const u8,
    comptime library_name: []const u8,
    lib_mod: *std.Build.Module,
    all_tests_step: *std.Build.Step,
    all_builds_step: *std.Build.Step,
) *std.Build.Step.Compile {
    const build_step = b.step("build_" ++ step_name ++ "_lib", "Build " ++ library_name ++ " library");
    const test_step = b.step("test_" ++ step_name ++ "_lib", "Run unit tests for " ++ library_name ++ " library");

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = library_name,
        .root_module = lib_mod,
    });
    build_step.dependOn(&lib.step);
    all_builds_step.dependOn(&lib.step);

    const test_mod = b.addTest(.{
        .name = step_name ++ "_lib_tests",
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(test_mod);
    all_tests_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_lib_unit_tests.step);

    b.installArtifact(lib);

    return lib;
}

fn addBinaryModule(
    b: *std.Build,
    comptime binary_name: []const u8,
    exe_mod: *std.Build.Module,
    all_tests_step: *std.Build.Step,
    all_builds_step: *std.Build.Step,

) *std.Build.Step.Compile {
    const build_step = b.step("build_" ++ binary_name, "Build " ++ binary_name ++ " binary");
    const test_step = b.step("test_" ++ binary_name, "Run unit tests for " ++ binary_name ++ " binary");

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

    // Modules
    const chess_mod = b.createModule(.{
        .root_source_file = b.path("./projects/chess/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    chess_mod.addOptions("build_options", build_options);

    const uci_mod = b.createModule(.{
        .root_source_file = b.path("./projects/uci/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const root_lib_mod = b.createModule(.{
        .root_source_file = b.path("./src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_lib_mod.addImport("chess", chess_mod);
    root_lib_mod.addImport("uci", uci_mod);

    const root_bin_mod = b.createModule(.{
        .root_source_file = b.path("./src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_bin_mod.addImport("chess", chess_mod);
    root_bin_mod.addImport("uci", uci_mod);

    // Libraries
    const build_libraries = b.step("build_libs", "Build all libraries");
    const test_libraries = b.step("test_libs", "Test all libraries");
    _ = addLibrary(b, "uci", "corundum_uci", uci_mod, test_libraries, build_libraries);
    _ = addLibrary(b, "chess", "corundum_chess", chess_mod, test_libraries, build_libraries);
    _ = addLibrary(b, "corundum", "corundum", root_lib_mod, test_libraries, build_libraries);

    // Binaries
    const build_binaries = b.step("build_bins", "Build all binaries");
    const test_binaries = b.step("test_bins", "Test all binaries");
    const exe = addBinaryModule(b, "corundum", root_bin_mod, test_binaries, build_binaries);

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
