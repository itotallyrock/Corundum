
const Player = @import("players.zig").Player;

pub const Piece = enum {
    Pawn,
    Rook,
    Knight,
    Bishop,
    Queen,
    King,
};

pub const NonKingPiece = enum {
    Pawn,
    Rook,
    Knight,
    Bishop,
    Queen,

    pub fn from_piece(piece: Piece) !NonKingPiece {
        return switch (piece) {
            .Pawn => .Pawn,
            .Rook => .Rook,
            .Knight => .Knight,
            .Bishop => .Bishop,
            .Queen => .Queen,
            .King => error.InvalidPiece,
        };
    }
};

pub const OwnedPiece = struct {
    player: Player,
    piece: Piece,
};

pub const OwnedNonKingPiece = struct {
    player: Player,
    piece: NonKingPiece,
};