const std = @import("std");
const build_options = @import("build_options");

pub const SetOption = struct {
    name: []const u8,
    value: ?[]const u8,
};

/// A parsed incoming UCI command
pub const UciCommand = union(enum) {
    uci,
    debug: struct {
        on: bool = true,
    },
    isready,
    ucinewgame,
    setoption: SetOption,
    position: struct {
        position: union(enum) {
            fen: []const u8,
            startpos,
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
    stop,
    ponderhit,
    quit,
    register: union(enum) {
        user: struct {
            name: []const u8,
            code: []const u8,
        },
        later,
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
            std.debug.print("WOWOWO '{s}' ''\n", .{line});
            _ = name_and_maybe_value;
            @panic("TODO");
            // if (std.mem.lastIndexOf(u8, name_and_maybe_value, " value ")) |value_index| {
            //     const name = name_and_maybe_value[0..value_index];
            //     const value = name_and_maybe_value[value_index + 7 ..];
            //     return .{ .setoption = .{ .name = name, .value = value } };
            // } else {
            //     return .{ .setoption = .{ .name = name_and_maybe_value, .value = null } };
            // }
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

    pub fn tryParse(self: UciOptionConfig, value: ?[]const u8) !UciOptionValue {
        // TODO: Move this to the caller of this method
        // if (!std.ascii.eqlIgnoreCase(self.name, set_option.name)) {
        //     return null;
        // }

        switch (self.config) {
            .check => {
                if (value) |v| {
                    if (std.ascii.eqlIgnoreCase(v, "true")) {
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
                    const i = try std.fmt.parseInt(i32, v, 10);
                    if (i < self.config.spin.min or i > self.config.spin.max) {
                        return error.InvalidOptionValue;
                    }
                    return .{ .spin = i };
                } else {
                    return .{ .spin = self.config.spin.default };
                }
            },
            .button => return .button,
            else => @panic("TODO: Implement the rest of the option types"),
        }
    }
};

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

pub const PerfCommand = struct {
    fen: []const u8,
    depth: u32,
};

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
    perft: PerfCommand,
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

    pub fn init(input: std.io.AnyReader, output: std.io.AnyWriter) CliManager {
        return CliManager{
            .input_stream = input,
            .output_stream = output,
        };
    }

    pub fn run(self: *CliManager) !void {
        try self.output_stream.print("{s} v{s} by {s}\n", .{ engine_name, build_options.version, engine_authors });
        while (true) {
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
                                    _ = value;
                                    std.debug.print("Setting option {s}\n", .{option.name});
                                    // TODO: Update engine with option

                                    continue;
                                }
                            }
                            try self.output_stream.print("Unknown option: '{s}'.\n", .{option.name});
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

    fn readLine(self: *CliManager) ![]const u8 {
        var line = std.BoundedArray(u8, base_buffer_size).init(0) catch unreachable;
        try self.input_stream.streamUntilDelimiter(line.writer(), '\n', base_buffer_size);
        const trimmed = std.mem.trim(u8, line.slice(), &std.ascii.whitespace);

        std.debug.print("Read line '{s}'\n", .{trimmed});

        return trimmed;
    }
};
