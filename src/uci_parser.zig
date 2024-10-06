const std = @import("std");
const mecha = @import("mecha");
const uci = @import("uci.zig");
const SetOption = uci.SetOption;
const UciCommand = uci.UciCommand;
const parser_utils = @import("parser_utils.zig");
const full = parser_utils.full;
const fullT = parser_utils.fullT;
const whitespace = parser_utils.whitespace;
const takeUntil = parser_utils.takeUntil;

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
