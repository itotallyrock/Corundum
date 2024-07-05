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
        setup,// after uci and we've returned uciok
        initialized,// after isready and we've returned readyok
    },
};

pub const CliCommand = union(enum) {
    bench,
    perft: PerfCommand,
    uci: UciCommand,
};

pub const CliCommandError = UciCommandError || error {
    UnrecognizedCommand,
};

fn parse_cli_command(command: []const u8) CliCommandError!CliCommand {
    _ = command;
    return error.UnrecognizedCommand;
}

pub const CliManager = struct {
    state: CliState = .none,
    // TODO: Thread stuff for reading commands
};