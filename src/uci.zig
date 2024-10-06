const std = @import("std");
const build_options = @import("build_options");
const mecha = @import("mecha");

const whitespace = mecha.many(mecha.ascii.whitespace, .{ .min = 1, .collect = false }).discard();

fn token(comptime literal: []const u8) mecha.Parser(void) {
    return mecha.combine(.{ mecha.string(literal).discard(), mecha.many(mecha.ascii.whitespace, .{ .collect = false }).discard() }).discard();
}

fn full_token(comptime literal: []const u8) mecha.Parser(void) {
    return mecha.combine(.{ token(literal).discard(), mecha.eos.discard() }).discard();
}

fn toDebugCommand(value: bool) UciCommand {
    return .{ .debug = .{ .on = value } };
}

fn key_value_parser(comptime key: []const u8, end: mecha.Parser(void)) mecha.Parser([]const u8) {
    return mecha.combine(.{ token(key).discard(), mecha.many(mecha.ascii.ascii, .{ .collect = false }), end });
}

fn toSetOption(option: SetOption) UciCommand {
    return .{ .setoption = option };
}

fn takeUntil(end: mecha.Parser(void)) mecha.Parser([]const u8) {
    return mecha.combine(.{
        mecha.many(mecha.ascii.ascii, .{ .collect = false }),
        end.discard(),
    });
}

pub const uci_parser: mecha.Parser(UciCommand) = mecha.oneOf(.{
    full_token("uci").mapConst(UciCommand{ .uci = .{} }),
    full_token("stop").mapConst(UciCommand{ .stop = .{} }),
    full_token("isready").mapConst(UciCommand{ .isready = .{} }),
    full_token("ucinewgame").mapConst(UciCommand{ .ucinewgame = .{} }),
    full_token("ponderhit").mapConst(UciCommand{ .ponderhit = .{} }),
    full_token("quit").mapConst(UciCommand{ .quit = .{} }),
    // mecha.combine(.{ token("debug"), mecha.oneOf(.{ full_token("on").mapConst(true), full_token("off").mapConst(false) }) }).map(toDebugCommand),
    // mecha.combine(.{token("setoption"), mecha.oneOf(.{
    //     mecha.combine(.{

    //     })
    // })}),
    // mecha.combine(.{
    //     token("setoption"),
    //     key_value_parser("name", mecha.oneOf(.{
    //         mecha.combine(.{ whitespace, token("value") }),
    //         mecha.eos,
    //     })),
    //     mecha.opt(key_value_parser("value", mecha.eos))
    // }).map(mecha.toStruct(SetOption)).map(toSetOption),
    // mecha.combine(.{ token("setoption"), whitespace, mecha.string("name"), whitespace, mecha.string("value") }).map(UciCommand{ .setoption = .{ .name = .name, .value = .value } }),
});

test "uci" {
    const input = "uci";
    const result = try uci_parser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.uci, result.value);
}

test "stop" {
    const input = "stop";
    const result = try uci_parser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.stop, result.value);
}

test "isready" {
    const input = "isready";
    const result = try uci_parser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.isready, result.value);
}

test "ucinewgame" {
    const input = "ucinewgame";
    const result = try uci_parser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.ucinewgame, result.value);
}

test "ponderhit" {
    const input = "ponderhit";
    const result = try uci_parser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.ponderhit, result.value);
}

test "quit" {
    const input = "quit";
    const result = try uci_parser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.quit, result.value);
}

// test "debug on command" {
//     const input = "debug on";
//     const result = try uci_parser.parse(std.testing.failing_allocator, input);
//     try std.testing.expectEqualDeep(UciCommand{ .debug = .{ .on = true } }, result.value);
// }
//
// test "debug off" {
//     const input = "debug off";
//     const result = try uci_parser.parse(std.testing.failing_allocator, input);
//     try std.testing.expectEqualDeep(UciCommand{ .debug = .{ .on = false } }, result.value);
// }

// test "setoption name Threads" {
//     const input = "setoption name Threads";
//     const result = try uci_parser.parse(std.testing.failing_allocator, input);
//     try std.testing.expectEqualDeep(UciCommand{ .setoption = .{ .name = "Threads", .value = null } }, result.value);
// }

// test "setoption name Hash value 4" {
//     const input = "setoption name Hash value 4";
//     const result = try uci_parser.parse(std.testing.failing_allocator, input);
//     try std.testing.expectEqualDeep(UciCommand{ .setoption = .{ .name = "Hash", .value = "4" } }, result.value);
// }

pub const SetOption = struct {
    name: []const u8,
    value: ?[]const u8,
};

/// A parsed incoming UCI command
pub const UciCommand = union(enum) {
    uci: struct {},
    debug: struct {
        on: bool = true,
    },
    isready: struct {},
    ucinewgame: struct {},
    setoption: SetOption,
    position: struct {
        position: union(enum) {
            fen: []const u8,
            startpos: struct {},
        },
        moves: ?[]const []const u8,
    },
    go: struct {
        searchmoves: ?[]const []const u8,
        ponder: bool = false,
        wtime: ?u32,
        btime: ?u32,
        winc: ?u32,
        binc: ?u32,
        movestogo: ?u32,
        depth: ?u32,
        nodes: ?u32,
        mate: ?u32,
        movetime: ?u32,
        infinite: bool = false,
    },
    stop: struct {},
    ponderhit: struct {},
    quit: struct {},
    register: union(enum) {
        user: struct {
            name: []const u8,
            code: []const u8,
        },
        later: struct {},
    },

    pub fn tryParse(line: []const u8) !UciCommand {
        if (std.ascii.eqlIgnoreCase(line, "uci")) {
            return .uci;
        } else if (std.ascii.eqlIgnoreCase(line, "isready")) {
            return .isready;
        } else if (std.ascii.eqlIgnoreCase(line, "ucinewgame")) {
            return .ucinewgame;
        } else if (std.ascii.eqlIgnoreCase(line, "ponderhit")) {
            return .ponderhit;
        } else if (std.ascii.eqlIgnoreCase(line, "quit")) {
            return .quit;
        } else if (std.ascii.eqlIgnoreCase(line, "stop")) {
            return .stop;
        } else if (std.ascii.eqlIgnoreCase(line, "debug on")) {
            return .{ .debug = .{ .on = true } };
        } else if (std.ascii.eqlIgnoreCase(line, "debug off")) {
            return .{ .debug = .{ .on = false } };
        } else if (std.ascii.startsWithIgnoreCase(line, "register ")) {
            @panic("TODO: Parse register command");
        } else if (std.ascii.startsWithIgnoreCase(line, "setoption name ")) {
            const name_and_maybe_value = line[15..];
            if (std.mem.lastIndexOf(u8, name_and_maybe_value, " value ")) |value_index| {
                const name = name_and_maybe_value[0..value_index];
                const value = name_and_maybe_value[value_index + 7 ..];
                return .{ .setoption = .{ .name = name, .value = value } };
            } else {
                return .{ .setoption = .{ .name = name_and_maybe_value, .value = null } };
            }
        } else if (std.ascii.startsWithIgnoreCase(line, "position ")) {
            @panic("TODO: Parse position command");
        } else if (std.ascii.startsWithIgnoreCase(line, "go ")) {
            @panic("TODO: Parse go command");
        }
        // TODO: The rest
        return error.UnrecognizedCommand;
    }
};

pub const UciCommandParseError = error{UnrecognizedCommand};

pub const UciOptionType = enum {
    check,
    spin,
    combo,
    string,
    button,
};

pub const UciOptionValue = union(UciOptionType) {
    check: bool,
    spin: i32,
    combo: []const u8,
    string: []const u8,
    button,
};

pub const UciOptionConfig = struct {
    name: []const u8,
    config: union(UciOptionType) {
        check: struct {
            default: bool = false,
        },
        spin: struct {
            default: i32,
            min: i32,
            max: i32,
        },
        combo: struct {
            default: []const u8,
            options: []const []const u8,
        },
        string: struct {
            default: []const u8,
        },
        button,
    },

    /// Tries to parse the given value into the correct UciOptionValue
    // Inline since this is often immediately switched on after calling, this switch can be combined with the switch in the caller
    pub fn tryParse(self: UciOptionConfig, value: ?[]const u8) !UciOptionValue {
        switch (self.config) {
            .check => {
                if (value) |v| {
                    if (v.len == 0) {
                        return .{ .check = self.config.check.default };
                    } else if (std.ascii.eqlIgnoreCase(v, "true")) {
                        return .{ .check = true };
                    } else if (std.ascii.eqlIgnoreCase(v, "false")) {
                        return .{ .check = false };
                    } else {
                        return error.InvalidOptionValue;
                    }
                } else {
                    return .{ .check = self.config.check.default };
                }
            },
            .spin => {
                if (value) |v| {
                    if (v.len > 0) {
                        const i = std.fmt.parseInt(i32, v, 10) catch return error.InvalidOptionValue;
                        if (i < self.config.spin.min or i > self.config.spin.max) {
                            return error.InvalidOptionValue;
                        }
                        return .{ .spin = i };
                    } else {
                        return .{ .spin = self.config.spin.default };
                    }
                } else {
                    return .{ .spin = self.config.spin.default };
                }
            },
            .button => return .button,
            .combo => {
                if (value) |v| {
                    if (v.len == 0) {
                        return .{ .combo = self.config.combo.default };
                    }

                    for (self.config.combo.options) |option| {
                        if (std.mem.eql(u8, v, option)) {
                            return .{ .combo = option };
                        }
                    }
                    return error.InvalidOptionValue;
                } else {
                    return .{ .combo = self.config.combo.default };
                }
            },
            .string => {
                if (value) |v| {
                    return .{ .string = v };
                } else {
                    return .{ .string = self.config.string.default };
                }
            },
        }
    }

    test tryParse {
        const spin_config = UciOptionConfig{
            .name = "test",
            .config = .{ .spin = .{ .default = 10, .min = 0, .max = 100 } },
        };
        try std.testing.expectEqualDeep(UciOptionValue{ .spin = 10 }, try spin_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue{ .spin = 10 }, try spin_config.tryParse(""));
        try std.testing.expectEqualDeep(UciOptionValue{ .spin = 20 }, try spin_config.tryParse("20"));
        try std.testing.expectError(error.InvalidOptionValue, spin_config.tryParse("200"));
        try std.testing.expectError(error.InvalidOptionValue, spin_config.tryParse("a"));

        const check_config = UciOptionConfig{
            .name = "test",
            .config = .{ .check = .{ .default = true } },
        };
        try std.testing.expectEqualDeep(UciOptionValue{ .check = true }, try check_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = true }, try check_config.tryParse(""));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = true }, try check_config.tryParse("true"));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = true }, try check_config.tryParse("tRuE"));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = false }, try check_config.tryParse("false"));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = false }, try check_config.tryParse("fAlSe"));
        try std.testing.expectError(error.InvalidOptionValue, check_config.tryParse("a"));

        const combo_config = UciOptionConfig{
            .name = "test",
            .config = .{ .combo = .{ .default = "a", .options = &[_][]const u8{ "a", "b", "c" } } },
        };
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "a" }, try combo_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "a" }, try combo_config.tryParse(""));
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "a" }, try combo_config.tryParse("a"));
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "b" }, try combo_config.tryParse("b"));
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "c" }, try combo_config.tryParse("c"));
        try std.testing.expectError(error.InvalidOptionValue, combo_config.tryParse("d"));
        try std.testing.expectError(error.InvalidOptionValue, combo_config.tryParse("C"));

        const string_config = UciOptionConfig{
            .name = "test",
            .config = .{ .string = .{ .default = "a" } },
        };
        try std.testing.expectEqualDeep(UciOptionValue{ .string = "a" }, try string_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue{ .string = "" }, try string_config.tryParse(""));
        try std.testing.expectEqualDeep(UciOptionValue{ .string = "lol" }, try string_config.tryParse("lol"));

        const button_config = UciOptionConfig{
            .name = "test",
            .config = .button,
        };
        try std.testing.expectEqualDeep(UciOptionValue.button, try button_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue.button, try button_config.tryParse(""));
    }
};

/// A message sent from the engine to the GUI
pub const UciResponse = union(enum) {
    id: union(enum) {
        name: []const u8,
        author: []const u8,
    },
    uciok,
    readyok,
    bestmove: struct {
        move: []const u8,
        ponder: ?[]const u8,
    },
    copyprotection: enum { checking, ok, @"error" },
    registration: enum { checking, ok, @"error" },
    info: struct {
        depth: ?u32,
        seldepth: ?u32,
        time: ?u32,
        nodes: ?u32,
        pv: ?[]const []const u8,
        multipv: ?u32,
        // TODO: Account for upper/lowerbound scores
        score: ?union(enum) { mate: i32, depth: u32 },
        hashfull: ?u32,
        nps: ?u32,
        tbhits: ?u32,
        cpuload: ?u32,
        string: ?[]const u8,
    },
    option: UciOptionConfig,
};

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

    pub fn tryParse(line: []const u8) CliCommandParseError!CliCommand {
        if (std.ascii.eqlIgnoreCase(line, "bench")) {
            return .bench;
        } else if (std.ascii.eqlIgnoreCase(line, "perft")) {
            // TODO: Parse FEN and depth
            return .{ .perft = .{ .fen = undefined, .depth = 0 } };
        }

        return .{ .uci = try UciCommand.tryParse(line) };
    }
};

pub const CliCommandParseError = UciCommandParseError || error{
    HelpNotImplemented,
    BenchNotImplemented,
    PerftNotImplemented,
    InvalidPerftCommand,
};

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

    /// Create a new CLI manager with the given input and output streams.
    pub fn init(input: std.io.AnyReader, output: std.io.AnyWriter) CliManager {
        return CliManager{
            .input_stream = input,
            .output_stream = output,
        };
    }

    /// The main loop for the CLI manager.
    /// Continuously reads input from the input stream and processes it as commands, mostly for running as a UCI engine.
    pub fn run(self: *CliManager) !void {
        try self.output_stream.print("{s} v{s} by {s}\n", .{ engine_name, build_options.version, engine_authors });
        main_loop: while (true) {
            const line = try self.readLine();
            const command = CliCommand.tryParse(line) catch |err| switch (err) {
                UciCommandParseError.UnrecognizedCommand => {
                    try self.output_stream.print("Unknown command: '{s}'. Type help for more information.\n", .{line});
                    continue;
                },
                else => return err,
            };
            switch (command) {
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
                                0 => try self.output_stream.print("Unknown option: '{s}'", .{option.name}),
                                1 => {
                                    try self.output_stream.print("Unknown option: '{s}', supported option is:", .{ option.name, engine_options[1].name });
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

        std.debug.print("Read line '{s}'\n", .{trimmed});

        return trimmed;
    }
};
