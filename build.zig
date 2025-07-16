const std = @import("std");
const builtin = @import("builtin");

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

const chess_project_root = "./projects/chess";
const uci_project_root = "./projects/uci";
const corundum_project_root = "./";

const chess_project_root_source = chess_project_root ++ "/src/root.zig";
const uci_project_root_source = uci_project_root ++ "/src/root.zig";
const corundum_project_root_source = corundum_project_root ++ "src/root.zig";
const corundum_main_source = corundum_project_root ++ "src/main.zig";

/// Setup the build
pub fn build(b: *std.Build) void {
    b.reference_trace = 20;

    // Build options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const continuous_integration = b.option(bool, "ci", "Run in CI mode") orelse false;
    const fix_formatting = b.option(bool, "fmt-fix", "Fix format issues or simply check for them") orelse !continuous_integration;
    const zobrist_seed = b.option(u256, "zobrist-seed", "Zobrist hash seed for the chess library") orelse 0xEB1EDE23CD04F71760E7A908AEB122BBE48D0CF561AEC147678AC2F99E68E420;

    var projects = .{
        .chess = .{
            .steps = .{
                .build = b.step("chess:build", "Build the chess library"),
                .@"test" = b.step("chess:test", "Run unit tests for the chess library"),
                .fmt = b.step("chess:fmt", "Check or fix formatting issues in the chess library"),
                .all = b.step("chess:all", "Check, test, and build the chess library"),
            },
            .module = b.addModule("corundum_chess", .{
                .root_source_file = b.path(chess_project_root_source),
                .target = target,
                .optimize = optimize,
            }),
            .tests = b.addRunArtifact(b.addTest(.{
                .root_module = b.modules.get("corundum_chess").?,
                .target = target,
                .optimize = optimize,
            })),
        },
        .uci = .{
            .steps = .{
                .build = b.step("uci:build", "Build the UCI library"),
                .@"test" = b.step("uci:test", "Run unit tests for the UCI library"),
                .fmt = b.step("uci:fmt", "Check or fix formatting issues in the UCI library"),
                .all = b.step("uci:all", "Check, test, and build the UCI library"),
            },
            .module = b.addModule("corundum_uci", .{
                .root_source_file = b.path(uci_project_root_source),
                .target = target,
                .optimize = optimize,
            }),
            .tests = b.addRunArtifact(b.addTest(.{
                .root_module = b.modules.get("corundum_uci").?,
                .target = target,
                .optimize = optimize,
            })),
        },
        .corundum = .{
            .steps = .{
                .build = b.step("corundum:build", "Build the corundum library/binary"),
                .@"test" = b.step("corundum:test", "Run unit tests for the corundum library/binary"),
                .fmt = b.step("corundum:fmt", "Check or fix formatting issues in the corundum library/binary"),
                .all = b.step("corundum:all", "Check, test, and build the corundum library/binary"),
                .run = b.step("corundum:run", "Run the corundum binary"),
            },
            .module = b.addModule("corundum_lib", .{
                .root_source_file = b.path(corundum_project_root_source),
                .target = target,
                .optimize = optimize,
            }),
            .main_module = b.addModule("corundum", .{
                .root_source_file = b.path(corundum_main_source),
                .target = target,
                .optimize = optimize,
            }),
            .tests = b.addRunArtifact(b.addTest(.{
                .root_module = b.modules.get("corundum").?,
                .target = target,
                .optimize = optimize,
            })),
        },
    };

    const all_steps = .{
        .build = b.step("all:build", "Build all libraries and binaries"),
        .@"test" = b.step("all:test", "Run unit tests for all libraries and binaries"),
        .fmt = b.step("all:fmt", "Check or fix formatting issues in all libraries and binaries"),
        .all = b.step("all:all", "Check, test, and build all libraries and binaries"),
    };

    // Setup project dependencies
    projects.corundum.main_module.addImport("corundum_uci", projects.uci.module);
    projects.corundum.main_module.addImport("corundum_uci", projects.uci.module);
    projects.corundum.module.addImport("corundum_chess", projects.chess.module);
    projects.corundum.module.addImport("corundum_chess", projects.chess.module);

    const chess_build_options = b.addOptions();
    chess_build_options.addOption(u256, "zobrist_seed", zobrist_seed);
    projects.chess.module.addOptions("chess_build_options", chess_build_options);

    // Setup compilation steps
    const chess_lib = b.addLibrary(.{
        .name = "corundum_chess",
        .root_module = projects.chess.module,
    });
    projects.chess.steps.build.dependOn(&chess_lib.step);
    const uci_lib = b.addLibrary(.{
        .name = "corundum_uci",
        .root_module = projects.uci.module,
    });
    projects.uci.steps.build.dependOn(&uci_lib.step);
    const corundum_lib = b.addLibrary(.{
        .name = "corundum_lib",
        .root_module = projects.corundum.module,
    });
    projects.corundum.steps.build.dependOn(&corundum_lib.step);
    const corundum_bin = b.addExecutable(.{
        .name = "corundum",
        .root_module = projects.corundum.main_module,
    });
    projects.corundum.steps.build.dependOn(&corundum_bin.step);

    // Setup test steps
    projects.chess.steps.@"test".dependOn(&projects.chess.tests.step);
    projects.uci.steps.@"test".dependOn(&projects.uci.tests.step);
    projects.corundum.steps.@"test".dependOn(&projects.corundum.tests.step);

    // Setup format checking
    projects.chess.steps.fmt.dependOn(&b.addFmt(.{ .check = !fix_formatting, .paths = &.{chess_project_root} }).step);
    projects.uci.steps.fmt.dependOn(&b.addFmt(.{ .check = !fix_formatting, .paths = &.{uci_project_root} }).step);
    projects.corundum.steps.fmt.dependOn(&b.addFmt(.{ .check = !fix_formatting, .paths = &.{corundum_project_root} }).step);

    // Setup all steps
    all_steps.all.dependOn(projects.chess.steps.all);
    all_steps.all.dependOn(projects.uci.steps.all);
    all_steps.all.dependOn(projects.corundum.steps.all);
    projects.chess.steps.all.dependOn(projects.chess.steps.build);
    projects.chess.steps.all.dependOn(projects.chess.steps.@"test");
    projects.chess.steps.all.dependOn(projects.chess.steps.fmt);
    projects.uci.steps.all.dependOn(projects.uci.steps.build);
    projects.uci.steps.all.dependOn(projects.uci.steps.@"test");
    projects.uci.steps.all.dependOn(projects.uci.steps.fmt);
    projects.corundum.steps.all.dependOn(projects.corundum.steps.build);
    projects.corundum.steps.all.dependOn(projects.corundum.steps.@"test");
    projects.corundum.steps.all.dependOn(projects.corundum.steps.fmt);

    // Setup install step
    b.installArtifact(chess_lib);
    b.installArtifact(uci_lib);
    b.installArtifact(corundum_bin);
}
