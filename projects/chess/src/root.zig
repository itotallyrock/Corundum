//! Chess core types and functions to maintain game state, allow moves to be made/unmade, support move generation and evaluation.

const std = @import("std");

/// The player module contains types and functions related to players in chess.
pub const player = @import("./player.zig");
/// The direction module contains types and functions related directionality on a chess board.
pub const direction = @import("./direction.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}