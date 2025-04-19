
const std = @import("std");
const ThreefoldRepetition = @import("./game_rules.zig").ThreefoldRepetition;
const ZobristHash = @import("./zobrist.zig").ZobristHash;

/// A hash used to track repetitions in a chess game.
/// This is a smaller-sized hash derived from a ZobristHash.
pub const RepetitionHash = struct {
    hash: u16,

    /// Creates a new RepetitionHash from a ZobristHash.
    pub fn fromZobristHash(zobrist: ZobristHash) RepetitionHash {
        return RepetitionHash{
            .hash = @truncate(zobrist.key),
        };
    }

    pub fn eq(self: RepetitionHash, other: RepetitionHash) bool {
        return self.hash == other.hash;
    }
};

test RepetitionHash {
    try std.testing.expect(@bitSizeOf(RepetitionHash) <= @bitSizeOf(ZobristHash));
}

/// A wrapper type that provides a state for tracking threefold repetitions.
pub fn RepetitionState(threefold_rule: ThreefoldRepetition) type {
    switch (threefold_rule) {
        .enabled => |enabled_rule| {
            return struct {
                const Self = @This();
                history: std.BoundedArray(RepetitionHash, enabled_rule.history_size),

                /// Creates a new RepetitionState with the specified history size.
                pub inline fn init() Self {
                    return Self{
                        .history = std.BoundedArray(RepetitionHash, enabled_rule.history_size).init(0) catch unreachable,
                    };
                }

                /// Attempts to add a hash to the history returning an error if it would cause a threefold repetition draw
                pub inline fn add(self: *Self, hash: RepetitionHash) error{DrawByRepetition}!void {
                    if (self.countRepetitions(hash) == 2) return error.DrawByRepetition;
                    self.history.appendAssumeCapacity(hash);
                }

                /// Removes the most recent hash from the history.
                pub inline fn pop(self: *Self) void {
                    _ = self.history.pop();
                }

                /// Counts the number of times a hash has appeared in the history.
                pub inline fn countRepetitions(self: *const Self, hash: RepetitionHash) u8 {
                    var count: u8 = 0;
                    for (self.history.constSlice()) |h| {
                        if (h.eq(hash)) count += 1;
                    }
                    return count;
                }

                /// Clears the history.
                pub inline fn clear(self: *Self) void {
                    self.history.clear();
                }

                /// Gets the number of hashes in the history.
                pub inline fn len(self: *const Self) u8 {
                    return @intCast(self.history.len);
                }

                test add {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });

                    try state.add(hash1);
                    try state.add(hash1);
                    try std.testing.expectError(error.DrawByRepetition, state.add(hash1));

                    const hash2 = RepetitionHash.fromZobristHash(.{ .key = 456 });
                    try state.add(hash2);
                    try state.add(hash2);
                    try std.testing.expectError(error.DrawByRepetition, state.add(hash2));
                }

                test len {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    const hash2 = RepetitionHash.fromZobristHash(.{ .key = 456 });

                    try state.add(hash1);
                    try std.testing.expectEqual(1, state.len());
                    try state.add(hash2);
                    try std.testing.expectEqual(2, state.len());
                }

                test clear {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    const hash2 = RepetitionHash.fromZobristHash(.{ .key = 456 });

                    try state.add(hash1);
                    try state.add(hash2);
                    try std.testing.expectEqual(2, state.len());
                    state.clear();
                    try std.testing.expectEqual(0, state.len());
                }

                test pop {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    const hash2 = RepetitionHash.fromZobristHash(.{ .key = 456 });

                    try state.add(hash1);
                    try state.add(hash2);
                    try std.testing.expectEqual(2, state.len());
                    state.pop();
                    try std.testing.expectEqual(1, state.len());
                    state.pop();
                    try std.testing.expectEqual(0, state.len());
                    state.pop();
                    try std.testing.expectEqual(0, state.len());
                }

                test countRepetitions {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    const hash2 = RepetitionHash.fromZobristHash(.{ .key = 456 });
                    try state.add(hash1);
                    try std.testing.expectEqual(1, state.countRepetitions(hash1));
                    try state.add(hash1);
                    try std.testing.expectEqual(2, state.countRepetitions(hash1));
                    try state.add(hash2);
                    try std.testing.expectEqual(1, state.countRepetitions(hash2));
                }
            };
        },
        .disabled => {
            return struct {
                const Self = @This();
                /// Create a new zero-length history RepetitionState.
                pub inline fn init() Self {
                    return Self{};
                }

                /// Add a hash to the zero-length history.
                pub inline fn add(_: *Self, _: RepetitionHash) !void {}

                /// Add a hash to the zero-length history.
                pub inline fn pop(_: *Self) void {}

                /// Count the number of times a hash has appeared in zero-length history.
                pub inline fn countRepetitions(_: *const Self, _: RepetitionHash) u8 {
                    return 0;
                }

                /// Clear the zero-length history.
                pub inline fn clear(_: *Self) void {}

                /// Get the zero-length history.
                pub inline fn len(_: *const Self) u8 {
                    return 0;
                }

                test add {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.countRepetitions(hash1));
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.countRepetitions(hash1));
                }

                test len {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.len());
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.len());
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.len());
                }

                test clear {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.len());
                    state.clear();
                    try std.testing.expectEqual(0, state.len());
                }

                test pop {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.len());
                    state.pop();
                    try std.testing.expectEqual(0, state.len());
                }

                test countRepetitions {
                    var state = Self.init();
                    const hash1 = RepetitionHash.fromZobristHash(.{ .key = 123 });
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.countRepetitions(hash1));
                    try state.add(hash1);
                    try std.testing.expectEqual(0, state.countRepetitions(hash1));
                }
            };
        },
    }
}

test RepetitionState {
    try std.testing.expectEqual(0, @bitSizeOf(RepetitionState(ThreefoldRepetition{ .disabled = .{} })));
    try std.testing.expect(@bitSizeOf(RepetitionState(ThreefoldRepetition{ .enabled = .{ .history_size = 100 } })) > 0);
}

test {
    std.testing.refAllDeclsRecursive(RepetitionState(.{ .disabled = .{} }));
    std.testing.refAllDeclsRecursive(RepetitionState(.{ .enabled = .{ .history_size = 255 } }));
    std.testing.refAllDeclsRecursive(RepetitionState(.{ .enabled = .{ .history_size = 100 } }));
}