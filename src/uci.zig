const std = @import("std");

/// A parsed incoming UCI command
pub const UciCommand = union(enum) {
    uci,
    debug: struct {
        on: bool = true,
    },
    isready,
    ucinewgame,
    setoption: struct {
        name: []const u8,
        value: ?[]const u8,
    },
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

    pub fn tryParse(line: []const u8) ?UciCommand {
        if (std.mem.eql(u8, line, "uci")) {
            return .uci;
        } else if (std.mem.eql(u8, line, "isready")) {
            return .isready;
        } else if (std.mem.eql(u8, line, "ucinewgame")) {
            return .ucinewgame;
        } else if (std.mem.eql(u8, line, "ponderhit")) {
            return .ponderhit;
        } else if (std.mem.eql(u8, line, "quit")) {
            return .quit;
        } else if (std.mem.eql(u8, line, "stop")) {
            return .stop;
        }
        // TODO: The rest
        return null;
    }
};

pub const UciCommandError = error{UciNotImplemented};

pub fn parse(command: []const u8) !UciCommand {
    _ = command;
    return error.UciNotImplemented;
}

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
        score: ?union(enum) { mate: i32, depth: u32 },
        hashfull: ?u32,
        nps: ?u32,
        tbhits: ?u32,
        cpuload: ?u32,
        string: ?[]const u8,
    },
    option: struct {
        name: []const u8,
        config: union(enum) {
            check: struct {
                default: bool = false,
            },
            spin: struct {
                default: u32,
                min: u32,
                max: u32,
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
    },
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
    perft: PerfCommand,
    uci: UciCommand,

    pub fn tryParse(line: []const u8) CliCommandError!CliCommand {
        if (std.mem.eql(u8, line, "bench")) {
            return .bench;
        } else if (std.mem.eql(u8, line, "perft")) {
            // TODO: Parse FEN and depth
            return .{ .perft = .{ .fen = undefined, .depth = 0 } };
        } else if (UciCommand.tryParse(line)) |uci_command| {
            return .{ .uci = uci_command };
        } else {
            return error.UnrecognizedCommand;
        }
    }
};

pub const CliCommandError = UciCommandError || error{
    UnrecognizedCommand,
};

pub const CliManager = struct {
    const base_buffer_size: usize = 1024;
    const engine_name = "Corundum";
    const engine_authors = "Jeffrey Meyer <itotallyrock>";

    input_buffer: [base_buffer_size]u8 = undefined,
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
        while (try self.readCommand()) |command| {
            switch (command) {
                .bench => {
                    @panic("Bench not implemented");
                },
                .perft => {
                    @panic("Perft not implemented");
                },
                .uci => |uci_command| {
                    switch (uci_command) {
                        .uci => {
                            // TODO: Use UciResponse
                            try self.output_stream.print("id name {s}\n", .{engine_name});
                            try self.output_stream.print("id author {s}\n", .{engine_authors});
                            // TODO: Print options
                            try self.output_stream.print("uciok\n", .{});
                            self.state = .{ .uci = .uninitialized };
                        },
                        .quit => break,
                        else => {
                            return error.UciNotImplemented;
                        },
                    }
                },
            }
        }
    }

    fn readCommand(self: *CliManager) !?CliCommand {
        // var buffer = self.input_buffer;
        // var i: usize = 0;
        // while (true) {
        //     const n = self.input_stream.read(buffer[i..]) catch return null;
        //     if (n == 0) {
        //         break;
        //     }
        //     i += n;
        //     if (buffer[i - 1] == '\n') {
        //         break;
        //     }
        // }
        var line = try std.ArrayList(u8).initCapacity(std.heap.page_allocator, base_buffer_size);
        // _ = self;
        // defer line.deinit();
        // _ = try line.writer().write("bench\r\n");
        try self.input_stream.streamUntilDelimiter(line.writer(), '\n', null);
        const trimmed = std.mem.trim(u8, line.items, "\n\t\u{0}\r ");
        std.debug.print("Read line: {s}\n", .{trimmed});

        return CliCommand.tryParse(trimmed) catch {
            std.debug.print("Invalid command: \"{s}\"\n", .{trimmed});
            return null;
        };
    }
};
