const std = @import("std");

/// The maximum number of plies a game/search can reach
pub const max_plies = @import("chess_build_options").max_plies;

/// A ply is a half-move in chess. It is used to represent the number of moves made in a game.
pub const Ply = std.math.IntFittingRange(0, max_plies);

test Ply {
    try std.testing.expect(max_plies <= std.math.maxInt(Ply));
}
