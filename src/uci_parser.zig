const std = @import("std");
const mecha = @import("mecha");

/// A parsed incoming UCI command
pub const UciCommand = union(enum) {
    uci: struct {},
    debug: Debug,
    isready: struct {},
    ucinewgame: struct {},
    setoption: SetOption,
    position: Position,
    go: Go,
    stop: struct {},
    ponderhit: struct {},
    quit: struct {},
    register: Register,
};

pub const Debug = struct {
    on: bool,
};

pub const SetOption = struct {
    name: []const u8,
    value: ?[]const u8,
};

pub const Go = struct {
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
};

pub const Position = struct {
    position: union(enum) {
        fen: []const u8,
        startpos: struct {},
    },
    moves: ?[]const []const u8,
};

pub const Register = union(enum) {
    user: struct {
        name: []const u8,
        code: []const u8,
    },
    later: struct {},
};

fn full(parser: anytype) mecha.Parser(void) {
    return mecha.combine(.{
        parser.discard(),
        mecha.eos.discard(),
    });
}

fn fullT(comptime T: type, parser: mecha.Parser(T)) mecha.Parser(T) {
    return mecha.combine(.{
        parser,
        mecha.eos.discard(),
    });
}

const whitespace = mecha.many(mecha.ascii.whitespace, .{ .collect = false, .min = 1 });
fn takeUntil(end: anytype) mecha.Parser([]const u8) {
    return mecha.combine(.{
        mecha.many(mecha.ascii.ascii, .{ .collect = false, .min = 1 }),
        end.discard(),
    });
}

pub const UciParser = mecha.oneOf(.{
    // Simple commands
    full(mecha.string("uci")).mapConst(UciCommand{ .uci = .{} }),
    full(mecha.string("isready")).mapConst(UciCommand{ .isready = .{} }),
    full(mecha.string("ucinewgame")).mapConst(UciCommand{ .ucinewgame = .{} }),
    full(mecha.string("stop")).mapConst(UciCommand{ .stop = .{} }),
    full(mecha.string("ponderhit")).mapConst(UciCommand{ .ponderhit = .{} }),
    full(mecha.string("quit")).mapConst(UciCommand{ .quit = .{} }),
    // Debug
    fullT(bool, mecha.combine(.{
        mecha.string("debug").discard(),
        whitespace.discard(),
        mecha.oneOf(.{
            mecha.string("on").mapConst(true),
            mecha.string("off").mapConst(false),
        }),
    })).map(createDebug),
    // SetOption
    mecha.combine(.{
        mecha.string("setoption").discard(),
        whitespace.discard(),
        mecha.string("name").discard(),
        whitespace.discard(),
        takeUntil(mecha.oneOf(.{
            mecha.string(" value ").discard(),
            mecha.eos,
        })),
        mecha.opt(mecha.combine(.{
            whitespace.discard(),
            mecha.string("value").discard(),
            whitespace.discard(),
            takeUntil(mecha.eos),
        })),
    }).map(mecha.toStruct(SetOption)).map(createSetOption),
});

fn createDebug(value: bool) UciCommand {
    return UciCommand{ .debug = .{ .on = value } };
}

fn createSetOption(value: SetOption) UciCommand {
    return UciCommand{ .setoption = value };
}

test "uci" {
    const input = "uci";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.uci, result.value);
}

test "stop" {
    const input = "stop";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.stop, result.value);
}

test "isready" {
    const input = "isready";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.isready, result.value);
}

test "ucinewgame" {
    const input = "ucinewgame";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.ucinewgame, result.value);
}

test "ponderhit" {
    const input = "ponderhit";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.ponderhit, result.value);
}

test "quit" {
    const input = "quit";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.quit, result.value);
}

test "debug on command" {
    const input = "debug on";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand{ .debug = .{ .on = true } }, result.value);
}

test "debug off" {
    const input = "debug off";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand{ .debug = .{ .on = false } }, result.value);
}

test "setoption name Threads" {
    const input = "setoption name Threads";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand{ .setoption = .{ .name = "Threads", .value = null } }, result.value);
}

test "setoption name Hash value 4" {
    const input = "setoption name Hash value 4";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand{ .setoption = .{ .name = "Hash", .value = "4" } }, result.value);
}
