const std = @import("std");
const Ply = @import("./ply.zig").Ply;
const MAX_PLIES = @import("./ply.zig").MAX_PLIES;
const CastleGameType = @import("./castle.zig").CastleGameType;
const MAX_HALFMOVE_CLOCK = @import("./halfmove_clock.zig").MAX_HALFMOVE_CLOCK;

/// A boolean rule that can be enabled or disabled.
pub const BooleanRule = enum(u1) {
    /// The rule is enabled.
    enabled,
    /// The rule is disabled.
    disabled,
};

/// Configures the threefold repetition rule.
pub const ThreefoldRepetition = union(BooleanRule) {
    /// The threefold repetition rule is enabled.
    enabled: struct {
        /// The number of half-moves (plies) to reserve for storing history to check for threefold repetitions.
        history_size: Ply,
    },
    /// The threefold repetition rule is disabled.
    disabled: struct {},
};

/// The game rules to tell the engine how to play the game.
pub const GameRules = struct {
    const Self = @This();
    /// The standard game rules for chess.
    pub const standard = Self.init(.standard, .enabled, .enabled, .enabled);
    pub const fischer = Self.init(.fischer_random, .enabled, .enabled, .enabled);

    /// Configure how castle rules are applied.
    castle_game_type: CastleGameType,
    /// Whether the fifty-move rule is enabled.
    fifty_move_limit: BooleanRule,
    /// Whether the threefold repetition rule is enabled (and its history size).
    threefold_repetition: ThreefoldRepetition,
    /// Whether the insufficient material rule is enabled.
    insufficient_material: BooleanRule,

    /// Create a new set of game rules.
    pub fn init(
        castle_game_type: CastleGameType,
        fifty_move_limit: BooleanRule,
        threefold_repetition: BooleanRule,
        insufficient_material: BooleanRule,
    ) Self {
        return Self{
            .castle_game_type = castle_game_type,
            .fifty_move_limit = fifty_move_limit,
            // if threefold_repetition is enabled, set the history size to 100 if fifty_move_limit is enabled, otherwise set it to MAX_PLIES
            .threefold_repetition = if (threefold_repetition == .enabled) .{
                .enabled = .{
                    .history_size = if (fifty_move_limit == .enabled) MAX_HALFMOVE_CLOCK else MAX_PLIES,
                },
            } else .{ .disabled = .{} },
            .insufficient_material = insufficient_material,
        };
    }
};

test "standard game rules" {
    const rules = GameRules.standard;
    try std.testing.expectEqual(rules.castle_game_type, .standard);
    try std.testing.expectEqual(rules.fifty_move_limit, .enabled);
    try std.testing.expectEqualDeep(rules.threefold_repetition, ThreefoldRepetition{ .enabled = .{ .history_size = MAX_HALFMOVE_CLOCK } });
    try std.testing.expectEqual(rules.insufficient_material, .enabled);
}
