comptime { @setEvalBranchQuota(2000); }

const std = @import("std");

pub const Square = @import("square.zig").Square;
pub const EnPassantSquare = @import("square.zig").EnPassantSquare;
pub const Board = @import("board.zig").Board;
pub const PieceArrangement = @import("board.zig").PieceArrangement;
pub const Player = @import("players.zig").Player;
pub const CastleRights = @import("castles.zig").CastleRights;
pub const CastleDirection = @import("castles.zig").CastleDirection;
pub const Piece = @import("pieces.zig").Piece;
pub const NonKingPiece = @import("pieces.zig").NonKingPiece;
pub const OwnedPiece = @import("pieces.zig").OwnedPiece;
pub const OwnedNonKingPiece = @import("pieces.zig").OwnedNonKingPiece;
pub const ByPlayer = @import("players.zig").ByPlayer;

test {
    std.testing.refAllDecls(@import("bitboard.zig"));
    std.testing.refAllDecls(@import("board.zig"));
    std.testing.refAllDecls(@import("castles.zig"));
    // std.testing.refAllDecls(@import("fen.zig"));
    // std.testing.refAllDecls(@import("moves.zig"));
    std.testing.refAllDecls(@import("pieces.zig"));
    std.testing.refAllDecls(@import("players.zig"));
    std.testing.refAllDecls(@import("square.zig"));
    std.testing.refAllDecls(@import("zobrist.zig"));
}

pub fn main() !void {
    @import("board.zig")
        .DefaultBoard
        .double_pawn_push(.E)
        .pawn_push(.E7)
        .pawn_push(.E4)
        .double_pawn_push(.F)
        .en_passant_capture(.E)
        .king_move(.E8, .E7)
        .debug_print();
}
