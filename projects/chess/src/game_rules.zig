const std = @import("std");
const max_plies = @import("chess_build_options").max_plies;
const Ply = @import("./ply.zig").Ply;
const CastleGameType = @import("./castle.zig").CastleGameType;
const max_halfmove_clock = @import("./halfmove_clock.zig").max_halfmove_clock;

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

/// How big the board should be
pub const BoardDimensions = struct {
    const Self = @This();

    /// The number of rows on the board
    ranks: u16,
    /// The number of columns on the board
    files: u16,

    /// If the height and width are the same
    pub fn isSquare(self: Self) bool {
        return self.ranks == self.files;
    }

    test isSquare {
        try std.testing.expectEqual((BoardDimensions{ .ranks = 8, .files = 8 }).isSquare(), true);
        try std.testing.expectEqual((BoardDimensions{ .ranks = 32, .files = 32 }).isSquare(), true);
        try std.testing.expectEqual((BoardDimensions{ .ranks = 2, .files = 2 }).isSquare(), true);
        try std.testing.expectEqual((BoardDimensions{ .ranks = 8, .files = 1 }).isSquare(), false);
        try std.testing.expectEqual((BoardDimensions{ .ranks = 1, .files = 8 }).isSquare(), false);
        try std.testing.expectEqual((BoardDimensions{ .ranks = 8, .files = 18 }).isSquare(), false);
    }
};

pub const @"8x8": BoardDimensions = .{
    .ranks = 8,
    .files = 8,
};

/// The game rules to tell the engine_commands how to play the game.
pub const GameRules = struct {
    const Self = @This();
    /// The standard game rules for chess.
    pub const standard = Self.init(@"8x8", .standard, .enabled, .enabled, .enabled);
    pub const fischer = Self.init(@"8x8", .fischer_random, .enabled, .enabled, .enabled);

    /// The size of the board
    board_dimensions: BoardDimensions,
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
        board_dimensions: BoardDimensions,
        castle_game_type: CastleGameType,
        fifty_move_limit: BooleanRule,
        threefold_repetition: BooleanRule,
        insufficient_material: BooleanRule,
    ) Self {
        return Self{
            .board_dimensions = board_dimensions,
            .castle_game_type = castle_game_type,
            .fifty_move_limit = fifty_move_limit,
            // if threefold_repetition is enabled, set the history size to 100 if fifty_move_limit is enabled, otherwise set it to max_plies
            .threefold_repetition = if (threefold_repetition == .enabled) .{
                .enabled = .{
                    .history_size = if (fifty_move_limit == .enabled) max_halfmove_clock else max_plies,
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
    try std.testing.expectEqualDeep(rules.threefold_repetition, ThreefoldRepetition{ .enabled = .{ .history_size = max_halfmove_clock } });
    try std.testing.expectEqual(rules.insufficient_material, .enabled);
}
