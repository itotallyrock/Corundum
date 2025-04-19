const std = @import("std");
const Ply = @import("./ply.zig").Ply;
const BooleanRule = @import("./game_rules.zig").BooleanRule;

/// The maximum number of half-moves (plies) before a game is considered drawn due to the fifty-move rule.
pub const MAX_HALFMOVE_CLOCK = 100;

/// Tracks the number of half-moves (plies) since the last pawn move or capture.
pub fn HalfmoveClock(fifty_move_limit: BooleanRule) type {
    switch (fifty_move_limit) {
        .enabled => {
            return struct {
                const Self = @This();
                plies: std.math.IntFittingRange(0, MAX_HALFMOVE_CLOCK),

                pub fn init() Self {
                    return Self{
                        .plies = 0,
                    };
                }

                pub fn initPlies(plies: Ply) Self {
                    return Self{
                        .plies = @intCast(plies),
                    };
                }

                pub fn increment(self: *Self) void {
                    self.plies +|= 1;
                }

                pub fn decrement(self: *Self) void {
                    self.plies -|= 1;
                }

                pub fn reset(self: *Self) void {
                    self.plies = 0;
                }

                pub fn reachedMoveLimit(self: *Self) bool {
                    return self.plies >= MAX_HALFMOVE_CLOCK;
                }

                test increment {
                    var clock = Self.init();
                    clock.increment();
                    try std.testing.expectEqual(clock.plies, 1);
                    clock.increment();
                    try std.testing.expectEqual(clock.plies, 2);
                }

                test decrement {
                    var clock = Self.init();
                    clock.increment();
                    clock.increment();
                    clock.decrement();
                    try std.testing.expectEqual(clock.plies, 1);
                    clock.decrement();
                    try std.testing.expectEqual(clock.plies, 0);
                }

                test reachedMoveLimit {
                    var clock = Self.init();
                    try std.testing.expectEqual(clock.reachedMoveLimit(), false);
                    inline for (0..MAX_HALFMOVE_CLOCK) |_| {
                        clock.increment();
                    }
                    try std.testing.expectEqual(clock.reachedMoveLimit(), true);
                }
            };
        },
        .disabled => {
            return struct {
                const Self = @This();
                pub inline fn init() Self {
                    return Self{};
                }
                pub inline fn initPlies(_: Ply) Self {
                    return Self{};
                }
                pub inline fn increment(_: *Self) void {}
                pub inline fn decrement(_: *Self) void {}
                pub inline fn reset(_: *Self) void {}
                pub inline fn reachedMoveLimit(_: *Self) bool {
                    return false;
                }

                test reachedMoveLimit {
                    var clock = Self.init();
                    try std.testing.expectEqual(clock.reachedMoveLimit(), false);
                    inline for (0..MAX_HALFMOVE_CLOCK) |_| {
                        clock.increment();
                    }
                    try std.testing.expectEqual(clock.reachedMoveLimit(), false);
                }
            };
        },
    }
}

test {
    std.testing.refAllDeclsRecursive(HalfmoveClock(.enabled));
    std.testing.refAllDeclsRecursive(HalfmoveClock(.disabled));
}