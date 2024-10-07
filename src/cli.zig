const std = @import("std");
const mecha = @import("mecha");
const build_options = @import("build_options");
const uci = @import("uci.zig");
const UciOptionConfig = uci.UciOptionConfig;
const UciResponse = uci.UciResponse;
const UciCommand = uci.UciCommand;
const UciParser = @import("uci_parser.zig").UciParser;
const parser_utils = @import("parser_utils.zig");
const full = parser_utils.full;
const whitespace = parser_utils.whitespace;

/// A non-uci command sent to the engine to performance test, or [perft](https://www.chessprogramming.org/Perft), a given position to a certain depth
pub const PerftCommand = struct {
    fen: []const u8,
    depth: u32,
};

/// The state of the CLI and UCI engine
pub const CliState = union(enum) {
    none,
    bench,
    perft,
    // TODO: Wrap uci union in a struct which has a Searcher/Engine struct or similar
    uci: union(enum) {
        uninitialized, // after uci and we've returned uciok
        initialized, // after isready and we've returned readyok
    },
};

pub const CliCommand = union(enum) {
    bench,
    help,
    perft: PerftCommand,
    uci: UciCommand,
};

pub const CliCommandParser = mecha.oneOf(.{
    full(mecha.string("bench")).mapConst(CliCommand{ .bench = {} }),
    full(mecha.string("help")).mapConst(CliCommand{ .help = {} }),
    // TODO: Parse perft args
    full(mecha.string("perft")).mapConst(CliCommand{ .perft = .{ .depth = 1, .fen = "startpos" } }),
    UciParser.map(struct {
        fn createCliCommand(command: UciCommand) CliCommand {
            return CliCommand{ .uci = command };
        }
    }.createCliCommand),
});

/// The CLI manager is responsible for parsing commands from the user and maintaining an engine state
pub const CliManager = struct {
    const base_buffer_size: usize = 1024;
    const engine_name = "Corundum";
    const engine_authors = "Jeffrey Meyer <itotallyrock>";
    const engine_options = [_]UciOptionConfig{ .{
        .name = "Hash",
        .config = .{ .spin = .{ .default = 16, .min = 1, .max = 1024 } },
    }, .{
        .name = "Threads",
        .config = .{ .spin = .{ .default = 1, .min = 1, .max = 64 } },
    }, .{
        .name = "MultiPV",
        .config = .{ .spin = .{ .default = 1, .min = 1, .max = 5 } },
    }, .{
        .name = "Clear Hash",
        .config = .button,
    }, .{
        .name = "Ponder",
        .config = .{ .check = .{ .default = false } },
    } };

    state: CliState = .none,
    input_stream: std.io.AnyReader,
    output_stream: std.io.AnyWriter,
    allocator: std.mem.Allocator,

    /// Create a new CLI manager with the given input and output streams.
    pub fn init(allocator: std.mem.Allocator, input: std.io.AnyReader, output: std.io.AnyWriter) CliManager {
        return CliManager{
            .input_stream = input,
            .output_stream = output,
            .allocator = allocator,
        };
    }

    /// The main loop for the CLI manager.
    /// Continuously reads input from the input stream and processes it as commands, mostly for running as a UCI engine.
    pub fn run(self: *CliManager) !void {
        // Print engine meta data on startup
        try self.output_stream.print("{s} v{s} by {s}\n", .{ engine_name, build_options.version, engine_authors });

        main_loop: while (true) {
            const line = try self.readLine();

            if (std.mem.trim(u8, line, " \n\t\r").len == 0) {
                continue;
            }

            const parse_result = CliCommandParser.parse(self.allocator, line) catch |err| switch (err) {
                error.ParserFailed => {
                    try self.output_stream.print("Unknown command: '{s}'. Type help for more information.\n", .{line});
                    continue;
                },
                else => return err,
            };

            switch (parse_result.value) {
                .help => {
                    // TODO: Implement help
                    try self.output_stream.print("Help is not implemented.\n", .{});
                },
                .bench => {
                    // TODO: Implement bench
                    try self.output_stream.print("Bench is not implemented.\n", .{});
                },
                .perft => {
                    // TODO: Implement perft
                    try self.output_stream.print("Perft is not implemented.\n", .{});
                },
                .uci => |uci_command| {
                    switch (uci_command) {
                        .uci => {
                            try self.writeResponse(.{ .id = .{ .name = engine_name } });
                            try self.writeResponse(.{ .id = .{ .author = engine_authors } });
                            try self.output_stream.print("\n", .{});
                            for (engine_options) |option| {
                                try self.writeResponse(.{ .option = option });
                            }
                            try self.writeResponse(.uciok);
                            self.state = .{ .uci = .uninitialized };
                        },
                        .isready => {
                            // TODO: Initialize the engine
                            try self.writeResponse(.readyok);
                            self.state = .{ .uci = .initialized };
                        },
                        .setoption => |option| {
                            for (engine_options) |engine_option| {
                                if (std.ascii.eqlIgnoreCase(option.name, engine_option.name)) {
                                    const value = engine_option.tryParse(option.value) catch {
                                        try self.output_stream.print("Invalid value for option '{s}': {s}\n", .{ option.name, option.value orelse "" });
                                        continue;
                                    };
                                    // _ = value;
                                    std.debug.print("Setting option {s} {?}\n", .{ option.name, value });
                                    // TODO: Update engine with option

                                    continue :main_loop;
                                }
                            }

                            // Handle unknown option
                            switch (engine_options.len) {
                                0 => try self.output_stream.print("Unknown option: '{s}' no supported options", .{option.name}),
                                1 => {
                                    try self.output_stream.print("Unknown option: '{s}', only supported option is:", .{ option.name, engine_options[1].name });
                                },
                                2 => {
                                    try self.output_stream.print("Unknown option: '{s}', supported options are: {s} and {s}", .{ option.name, engine_options[0].name, engine_options[1].name });
                                },
                                else => {
                                    try self.output_stream.print("Unknown option: {s}, supported options are: ", .{option.name});
                                    inline for (comptime engine_options[1 .. engine_options.len - 1]) |engine_option| {
                                        try self.output_stream.print("{s}, ", .{engine_option.name});
                                    }
                                    try self.output_stream.print("and {s}\n", .{engine_options[engine_options.len - 1].name});
                                },
                            }
                        },
                        .position => |position_and_moves| {
                            _ = position_and_moves;
                            // TODO: Implement set position
                        },
                        .go => |go_options| {
                            _ = go_options;
                            // TODO: Implement go
                        },
                        .stop => {
                            // TODO: Implement stop
                        },
                        // TODO: The rest of the UCI commands
                        .quit => break,
                        else => {
                            try self.output_stream.print("Unsupported UCI command.\n", .{});
                        },
                    }
                },
            }
        }
    }

    /// Respond to the GUI with the given UCI response.
    fn writeResponse(self: *CliManager, response: UciResponse) !void {
        switch (response) {
            .id => |id_response| switch (id_response) {
                .name => |name| try self.output_stream.print("id name {s}\n", .{name}),
                .author => |author| try self.output_stream.print("id author {s}\n", .{author}),
            },
            .uciok => try self.output_stream.print("uciok\n", .{}),
            .readyok => try self.output_stream.print("readyok\n", .{}),
            .copyprotection => |state| try self.output_stream.print("copyprotection {s}\n", .{@tagName(state)}),
            .registration => |state| try self.output_stream.print("registration {s}\n", .{@tagName(state)}),
            .info => |info| {
                try self.output_stream.print("info", .{});
                if (info.depth) |depth| {
                    try self.output_stream.print(" depth {d}", .{depth});
                }
                if (info.seldepth) |seldepth| {
                    try self.output_stream.print(" seldepth {d}", .{seldepth});
                }
                if (info.time) |time| {
                    try self.output_stream.print(" time {d}", .{time});
                }
                if (info.nodes) |nodes| {
                    try self.output_stream.print(" nodes {d}", .{nodes});
                }
                if (info.pv) |pv| {
                    try self.output_stream.print(" pv", .{});
                    for (pv) |line| {
                        try self.output_stream.print(" {s}", .{line});
                    }
                }
                if (info.multipv) |multipv| {
                    try self.output_stream.print(" multipv {d}", .{multipv});
                }
                if (info.score) |score| {
                    try self.output_stream.print(" score", .{});
                    switch (score) {
                        .mate => |mate| try self.output_stream.print(" mate {d}", .{mate}),
                        .depth => |depth| try self.output_stream.print(" cp {d}", .{depth}),
                    }
                }
                if (info.hashfull) |hashfull| {
                    try self.output_stream.print(" hashfull {d}", .{hashfull});
                }
                if (info.nps) |nps| {
                    try self.output_stream.print(" nps {d}", .{nps});
                }
                if (info.tbhits) |tbhits| {
                    try self.output_stream.print(" tbhits {d}", .{tbhits});
                }
                if (info.cpuload) |cpuload| {
                    try self.output_stream.print(" cpuload {d}", .{cpuload});
                }
                if (info.string) |string| {
                    try self.output_stream.print(" string {s}", .{string});
                }
                try self.output_stream.print("\n", .{});
            },
            .bestmove => |bestmove| {
                try self.output_stream.print("bestmove {s}", .{bestmove.move});
                if (bestmove.ponder) |ponder_move| {
                    try self.output_stream.print(" ponder {s}\n", .{ponder_move});
                } else {
                    try self.output_stream.print("\n", .{});
                }
            },
            .option => |option| {
                switch (option.config) {
                    .string => |string_option| try self.output_stream.print("option name {s} type string default {s}\n", .{ option.name, string_option.default }),
                    .spin => |spin_option| try self.output_stream.print("option name {s} type spin default {d} min {d} max {d}\n", .{ option.name, spin_option.default, spin_option.min, spin_option.max }),
                    .check => |check_option| try self.output_stream.print("option name {s} type check default {s}\n", .{ option.name, if (check_option.default) "true" else "false" }),
                    .combo => |combo_option| {
                        try self.output_stream.print("option name {s} type combo default {s}", .{ option.name, combo_option.default });
                        for (combo_option.options) |combo_choice| {
                            try self.output_stream.print(" var {s}", .{combo_choice});
                        }
                        try self.output_stream.print("\n", .{});
                    },
                    .button => try self.output_stream.print("option name {s} type button\n", .{option.name}),
                }
            },
        }
    }

    /// Read a single command line input
    // NOTE: This must be inline in order for the "line" stack address to remain constant
    inline fn readLine(self: *CliManager) ![]const u8 {
        var line = std.BoundedArray(u8, base_buffer_size).init(0) catch unreachable;
        try self.input_stream.streamUntilDelimiter(line.writer(), '\n', base_buffer_size);
        const trimmed = std.mem.trim(u8, line.slice(), &std.ascii.whitespace);

        return trimmed;
    }
};
