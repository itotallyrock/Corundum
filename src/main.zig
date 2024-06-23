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
    std.testing.refAllDeclsRecursive(@This());
}

pub fn main() !void {
    @import("board.zig")
        .DefaultBoard
        .doublePawnPush(.e)
        .pawnPush(.e7)
        .pawnPush(.e4)
        .doublePawnPush(.f)
        .enPassantCapture(.e)
        .kingMove(.e8, .e7)
        .debugPrint();
}
