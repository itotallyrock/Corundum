//! Chess core types and functions to maintain game state, allow moves to be made/unmade, support move generation and evaluation.
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
/// The castle module contains types and functions related to castling in chess.
pub const castle = @import("./castle.zig");
/// The move module contains types and functions related to moves in chess.
pub const move = @import("./move.zig");
/// The zobrist module contains types and functions related to Zobrist hashing, a common technique for representing chess positions.
pub const zobrist = @import("./zobrist.zig");
/// The piece_arrangement module contains types and functions related to the arrangement of pieces on a chess board.
pub const piece_arrangement = @import("./piece_arrangement.zig");
/// The ply module contains types and functions related to the concept of ply in chess, which is a half-move.
pub const ply = @import("./ply.zig");
/// The square count module contains a type containing a number of squares
pub const square_count = @import("./square_count.zig");
/// The game rules module contains types and functions related to the game setup and alternative gamemode specific config.
pub const game_rules = @import("./game_rules.zig");
/// The board status module contains types and functions related to the status of a chess board use for comptime specific board functions.
pub const board_status = @import("./board_status.zig").BoardStatus;
/// The history state module contains types and functions related to preservation of moves across the history of a chess game.
pub const history_state = @import("./history_state.zig");

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@This());
}
