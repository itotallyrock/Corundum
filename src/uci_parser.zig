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

pub fn takeUntil(end_parser: anytype) mecha.Parser([]const u8) {
    const Res = mecha.Result([]const u8);
    return .{
        .parse = struct {
            fn parse(allocator: std.mem.Allocator, s: []const u8) !Res {
                var index: usize = 0;
                while (index < s.len) {
                    const end = try end_parser.parse(allocator, s[index..]);
                    switch (end.value) {
                        .ok => return Res.ok(index + end.index, s[0 .. index - 1]),
                        .err => index += 1,
                    }
                }

                return Res.ok(index, s[0..index]);
            }
        }.parse,
    };
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
    fullT(UciCommand, mecha.combine(.{
        mecha.string("debug").discard(),
        whitespace.discard(),
        mecha.oneOf(.{
            mecha.string("on").mapConst(UciCommand{ .debug = .{ .on = true } }),
            mecha.string("off").mapConst(UciCommand{ .debug = .{ .on = false } }),
        }),
    })),
    // SetOption
    mecha.combine(.{
        mecha.string("setoption").discard(),
        whitespace.discard(),
        mecha.string("name").discard(),
        whitespace.discard(),
        mecha.oneOf(.{
            mecha.combine(.{
                takeUntil(mecha.string("value").discard()),
                whitespace.discard(),
                takeUntil(mecha.eos),
            }).map(mecha.toStruct(SetOption)),
            takeUntil(mecha.eos).map(struct {
                fn createSetOption(name: []const u8) SetOption {
                    return SetOption{ .name = name, .value = null };
                }
            }.createSetOption),
        }).map(struct {
            fn createSetOption(value: SetOption) UciCommand {
                return UciCommand{ .setoption = value };
            }
        }.createSetOption),
    }),
});

test "uci" {
    const input = "uci";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.uci, result.value.ok);
}

test "stop" {
    const input = "stop";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.stop, result.value.ok);
}

test "isready" {
    const input = "isready";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.isready, result.value.ok);
}

test "ucinewgame" {
    const input = "ucinewgame";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.ucinewgame, result.value.ok);
}

test "ponderhit" {
    const input = "ponderhit";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.ponderhit, result.value.ok);
}

test "quit" {
    const input = "quit";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand.quit, result.value.ok);
}

test "debug on command" {
    const input = "debug on";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand{ .debug = .{ .on = true } }, result.value.ok);
}

test "debug off" {
    const input = "debug off";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand{ .debug = .{ .on = false } }, result.value.ok);
}

test "setoption name Threads" {
    const input = "setoption name Threads";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand{ .setoption = .{ .name = "Threads", .value = null } }, result.value.ok);
}

test "setoption name Hash value 4" {
    const input = "setoption name Hash value 4";
    const result = try UciParser.parse(std.testing.failing_allocator, input);
    try std.testing.expectEqualDeep(UciCommand{ .setoption = .{ .name = "Hash", .value = "4" } }, result.value.ok);
}
