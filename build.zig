const std = @import("std");
const builtin = @import("builtin");

const chess_project_root = "./projects/chess";
const uci_project_root = "./projects/uci";
const search_project_root = "./projects/search";
const corundum_project_root = "./";

const chess_project_root_source = chess_project_root ++ "/src/root.zig";
const uci_project_root_source = uci_project_root ++ "/src/root.zig";
const search_project_root_source = search_project_root ++ "/src/root.zig";
const corundum_project_root_source = corundum_project_root ++ "src/root.zig";
const corundum_main_source = corundum_project_root ++ "src/main.zig";

const option_defaults = .{
    .fix_formatting = false,
    .zobrist_seed = 0xEB1EDE23CD04F71760E7A908AEB122BBE48D0CF561AEC147678AC2F99E68E420,
    .max_command_length = 4096,
    .pawn_grain = 256,
    .max_material_score = 125,
    .max_plies = 255,
    .max_nodes = std.math.maxInt(u64),
    .thread_node_flush_interval = 1024,
    .enable_logging = true,
};

/// Setup the build
pub fn build(b: *std.Build) void {

    // Build options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const fix_formatting = b.option(bool, "fmt-fix", b.fmt("Fix format issues or simply check for them (default: {any})", .{option_defaults.fix_formatting})) orelse option_defaults.fix_formatting;
    const zobrist_seed = b.option(u256, "zobrist-seed", b.fmt("Zobrist hash seed for the chess library (default: 0x{X})", .{option_defaults.zobrist_seed})) orelse option_defaults.zobrist_seed;
    const max_command_length = b.option(u256, "max-command-length", b.fmt("The maximum length of a UCI command to buffer (default: {any})", .{option_defaults.max_command_length})) orelse option_defaults.max_command_length;
    const pawn_grain = b.option(u16, "pawn-grain", b.fmt("Determines the precision for pawn score, true for more exact, false for approximate but lower memory usage (default {any})", .{option_defaults.pawn_grain})) orelse option_defaults.pawn_grain;
    const max_material_score = b.option(u16, "max-score", b.fmt("The maximum material score represented in number of pawns (i.e. 150 pawns or ~12 queens) (default {any})", .{option_defaults.max_material_score})) orelse option_defaults.max_material_score;
    const max_plies = b.option(u16, "max-plies", b.fmt("The absolute maximum number of plies a search/game can reach (default {any})", .{option_defaults.max_plies})) orelse option_defaults.max_plies;
    const max_mate_plies = b.option(u16, "max-mate-plies", b.fmt("The maximum number of plies a mate can be kept track of for (defaults to max-plies {any})", .{max_plies})) orelse max_plies;
    const max_nodes = b.option(u64, "max-nodes", b.fmt("The absolute maximum number of nodes a search can search through (default {any})", .{option_defaults.max_nodes})) orelse option_defaults.max_nodes;
    const thread_node_flush_interval = b.option(u64, "node-flush-count", b.fmt("How many nodes a thread should increment locally before reporting to the shared node-count.  When a search specifies a max-nodes it will use this value to calculate the number of threads to avoid over-searching (i.e. <{d} nodes with a {d} node-flush-count would use one thread.   (default {d})", .{ 2 * option_defaults.thread_node_flush_interval, option_defaults.thread_node_flush_interval, option_defaults.thread_node_flush_interval })) orelse option_defaults.thread_node_flush_interval;
    const enable_logging = b.option(bool, "logging", b.fmt("Whether or not to include extra logging functionality. The specific logging functionality relies on other build variables and runtime conditions (default {any})", .{option_defaults.enable_logging})) orelse option_defaults.enable_logging;

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
                // NOTE: We don't use libc but something in "testing" does, so we need this to run tests on linux systems - https://github.com/ziglang/zig/issues/22210
                .link_libc = true,
            }),
            .tests = b.addRunArtifact(b.addTest(.{
                .root_module = b.modules.get("corundum_chess").?,
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
            })),
        },
        .search = .{
            .steps = .{
                .@"test" = b.step("search:test", "Run unit tests for the search library"),
                .fmt = b.step("search:fmt", "Check or fix formatting issues in the search library"),
                .all = b.step("search:all", "Check, test, and build the search library"),
            },
            .module = b.addModule("corundum_search", .{
                .root_source_file = b.path(search_project_root_source),
                .target = target,
                .optimize = optimize,
            }),
            .tests = b.addRunArtifact(b.addTest(.{
                .root_module = b.modules.get("corundum_search").?,
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
    projects.corundum.main_module.addImport("corundum_chess", projects.chess.module);
    projects.corundum.main_module.addImport("corundum_search", projects.uci.module);
    projects.corundum.module.addImport("corundum_uci", projects.uci.module);
    projects.corundum.module.addImport("corundum_chess", projects.chess.module);
    projects.corundum.module.addImport("corundum_search", projects.chess.module);

    projects.search.module.addImport("corundum_chess", projects.chess.module);

    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_logging", enable_logging);
    projects.chess.module.addOptions("build_options", build_options);
    projects.uci.module.addOptions("build_options", build_options);
    projects.search.module.addOptions("build_options", build_options);
    projects.corundum.module.addOptions("build_options", build_options);
    projects.corundum.main_module.addOptions("build_options", build_options);

    const chess_build_options = b.addOptions();
    chess_build_options.addOption(u256, "zobrist_seed", zobrist_seed);
    chess_build_options.addOption(u16, "max_plies", max_plies);
    projects.chess.module.addOptions("chess_build_options", chess_build_options);

    const search_build_options = b.addOptions();
    search_build_options.addOption(u16, "pawn_grain", pawn_grain);
    search_build_options.addOption(u16, "max_material_score", max_material_score);
    search_build_options.addOption(u16, "max_mate_plies", max_mate_plies);
    search_build_options.addOption(u64, "max_nodes", max_nodes);
    search_build_options.addOption(u64, "thread_node_flush_interval", thread_node_flush_interval);
    projects.search.module.addOptions("search_build_options", search_build_options);

    const corundum_build_options = b.addOptions();
    corundum_build_options.addOption(u256, "max_command_length", max_command_length);
    projects.corundum.module.addOptions("corundum_build_options", corundum_build_options);
    projects.corundum.main_module.addOptions("corundum_build_options", corundum_build_options);

    // Setup compilation steps
    const corundum_bin = b.addExecutable(.{
        .name = "corundum",
        .root_module = projects.corundum.main_module,
    });
    projects.corundum.steps.build.dependOn(&corundum_bin.step);

    // Setup test steps
    projects.chess.steps.@"test".dependOn(&projects.chess.tests.step);
    projects.uci.steps.@"test".dependOn(&projects.uci.tests.step);
    projects.search.steps.@"test".dependOn(&projects.search.tests.step);
    projects.corundum.steps.@"test".dependOn(&projects.corundum.tests.step);

    // Setup format checking
    projects.chess.steps.fmt.dependOn(&b.addFmt(.{ .check = !fix_formatting, .paths = &.{chess_project_root} }).step);
    projects.uci.steps.fmt.dependOn(&b.addFmt(.{ .check = !fix_formatting, .paths = &.{uci_project_root} }).step);
    projects.search.steps.fmt.dependOn(&b.addFmt(.{ .check = !fix_formatting, .paths = &.{search_project_root} }).step);
    projects.corundum.steps.fmt.dependOn(&b.addFmt(.{ .check = !fix_formatting, .paths = &.{corundum_project_root} }).step);

    // Setup run step
    const run = b.addRunArtifact(corundum_bin);
    run.step.dependOn(b.getInstallStep());
    projects.corundum.steps.run.dependOn(&run.step);
    if (b.args) |args| run.addArgs(args);

    // Setup all steps
    all_steps.all.dependOn(projects.chess.steps.all);
    all_steps.all.dependOn(projects.uci.steps.all);
    all_steps.all.dependOn(projects.search.steps.all);
    all_steps.all.dependOn(projects.corundum.steps.all);
    projects.chess.steps.all.dependOn(projects.chess.steps.@"test");
    projects.chess.steps.all.dependOn(projects.chess.steps.fmt);
    projects.uci.steps.all.dependOn(projects.uci.steps.@"test");
    projects.uci.steps.all.dependOn(projects.uci.steps.fmt);
    projects.search.steps.all.dependOn(projects.search.steps.@"test");
    projects.search.steps.all.dependOn(projects.search.steps.fmt);
    projects.corundum.steps.all.dependOn(projects.corundum.steps.build);
    projects.corundum.steps.all.dependOn(projects.corundum.steps.@"test");
    projects.corundum.steps.all.dependOn(projects.corundum.steps.fmt);

    // Setup install step
    b.installArtifact(corundum_bin);
}
