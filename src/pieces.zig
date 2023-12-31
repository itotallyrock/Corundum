const std = @import("std");
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

    pub fn to_piece(self: NonKingPiece) Piece {
        return switch (self) {
            .Pawn => .Pawn,
            .Rook => .Rook,
            .Knight => .Knight,
            .Bishop => .Bishop,
            .Queen => .Queen,
        };
    }

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

pub const PromotionPiece = enum {
    Rook,
    Knight,
    Bishop,
    Queen,

    pub fn to_piece(self: PromotionPiece) Piece {
        return switch (self) {
            .Rook => .Rook,
            .Knight => .Knight,
            .Bishop => .Bishop,
            .Queen => .Queen,
        };
    }
};

pub fn ByNonKingPiece(comptime T: type) type {
    return std.EnumArray(NonKingPiece, T);
}

pub fn ByPiece(comptime T: type) type {
    return std.EnumArray(Piece, T);
}

pub fn ByPromotionPiece(comptime T: type) type {
    return std.EnumArray(PromotionPiece, T);
}

pub const OwnedPiece = struct {
    player: Player,
    piece: Piece,
};

pub const OwnedNonKingPiece = struct {
    player: Player,
    piece: NonKingPiece,

    pub fn to_owned(self: OwnedNonKingPiece) OwnedPiece {
        return OwnedPiece {
            .player = self.player,
            .piece = switch (self.piece) {
                .Pawn => .Pawn,
                .Rook => .Rook,
                .Knight => .Knight,
                .Bishop => .Bishop,
                .Queen => .Queen,
            },
        };
    }
};