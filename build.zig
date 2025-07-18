const std = @import("std");
const builtin = @import("builtin");

const chess_project_root = "./projects/chess";
const uci_project_root = "./projects/uci";
const corundum_project_root = "./";

const chess_project_root_source = chess_project_root ++ "/src/root.zig";
const uci_project_root_source = uci_project_root ++ "/src/root.zig";
const corundum_project_root_source = corundum_project_root ++ "src/root.zig";
const corundum_main_source = corundum_project_root ++ "src/main.zig";

/// Setup the build
pub fn build(b: *std.Build) void {

    // Build options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const continuous_integration = b.option(bool, "ci", "Run in CI mode") orelse false;
    const fix_formatting = b.option(bool, "fmt-fix", "Fix format issues or simply check for them") orelse !continuous_integration;
    const zobrist_seed = b.option(u256, "zobrist-seed", "Zobrist hash seed for the chess library") orelse 0xEB1EDE23CD04F71760E7A908AEB122BBE48D0CF561AEC147678AC2F99E68E420;

    var projects = .{
        .chess = .{
            .steps = .{
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
                .build = b.step("corundum:build", "Build the corundum binary"),
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

    // Setup run step
    projects.corundum.steps.run.dependOn(&b.addRunArtifact(corundum_bin).step);

    // Setup all steps
    all_steps.all.dependOn(projects.chess.steps.all);
    all_steps.all.dependOn(projects.uci.steps.all);
    all_steps.all.dependOn(projects.corundum.steps.all);
    projects.chess.steps.all.dependOn(projects.chess.steps.@"test");
    projects.chess.steps.all.dependOn(projects.chess.steps.fmt);
    projects.uci.steps.all.dependOn(projects.uci.steps.@"test");
    projects.uci.steps.all.dependOn(projects.uci.steps.fmt);
    projects.corundum.steps.all.dependOn(projects.corundum.steps.build);
    projects.corundum.steps.all.dependOn(projects.corundum.steps.@"test");
    projects.corundum.steps.all.dependOn(projects.corundum.steps.fmt);

    // Setup install step
    b.installArtifact(corundum_bin);
}
