//! Chess core types and functions to maintain game state, allow moves to be made/unmade, support move generation and evaluation.

const std = @import("std");

/// The player module contains types and functions related to players in chess.
pub const player = @import("./player.zig");
/// The direction module contains types and functions related directionality on a chess board.
pub const direction = @import("./direction.zig");
/// The piece module contains types and functions related to chess pieces.
pub const piece = @import("./piece.zig");
/// The square module contains types and functions related to squares on a chess board.
pub const square = @import("./square.zig");
/// The bitboard module contains types and functions related to bitboards, a common representation of chess boards.
pub const bitboard = @import("./bitboard.zig");
/// The line module contains types and functions related to lines between squares on a chess board.
pub const line = @import("./line.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}