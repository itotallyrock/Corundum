
const std = @import("std");

/// The maximum number of half-moves (plies) in a chess game.
pub const MAX_PLIES = 255;

/// A ply is a half-move in chess. It is used to represent the number of moves made in a game.
pub const Ply = std.math.IntFittingRange(0, MAX_PLIES);

test Ply {
    try std.testing.expect(MAX_PLIES <= std.math.maxInt(Ply));
}