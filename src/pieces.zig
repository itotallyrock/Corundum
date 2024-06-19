const std = @import("std");
const Player = @import("players.zig").Player;

/// A piece on the board.
pub const Piece = enum(u3) {
    Pawn,
    Rook,
    Knight,
    Bishop,
    Queen,
    King,

    /// Create an `OwnedPiece` from this piece given an owning `Player`.
    pub fn owned_by(self: Piece, player: Player) OwnedPiece {
        return OwnedPiece {
            .player = player,
            .piece = self,
        };
    }
};

/// A piece that is not a king.
pub const NonKingPiece = enum(u3) {
    Pawn = @intFromEnum(Piece.Pawn),
    Rook = @intFromEnum(Piece.Rook),
    Knight = @intFromEnum(Piece.Knight),
    Bishop = @intFromEnum(Piece.Bishop),
    Queen = @intFromEnum(Piece.Queen),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn to_piece(self: NonKingPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn from_piece(piece: Piece) !NonKingPiece {
        return switch (piece) {
            .Pawn, .Rook, .Knight, .Bishop, .Queen => @enumFromInt(@intFromEnum(piece)),
            .King => error.InvalidPiece,
        };
    }
};

/// A piece that a pawn can be promoted to.
pub const PromotionPiece = enum(u3) {
    Rook = @intFromEnum(Piece.Rook),
    Knight = @intFromEnum(Piece.Knight),
    Bishop = @intFromEnum(Piece.Bishop),
    Queen = @intFromEnum(Piece.Queen),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn to_piece(self: PromotionPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn from_piece(piece: Piece) !PromotionPiece {
        return switch (piece) {
            .Rook, .Knight, .Bishop, .Queen => @enumFromInt(@intFromEnum(piece)),
            .Pawn => error.InvalidPiece,
        };
    }
};

/// A piece that is not a pawn.
pub const NonPawnPiece = enum(u3) {
    Rook = @intFromEnum(Piece.Rook),
    Knight = @intFromEnum(Piece.Knight),
    Bishop = @intFromEnum(Piece.Bishop),
    Queen = @intFromEnum(Piece.Queen),
    King = @intFromEnum(Piece.King),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn to_piece(self: NonPawnPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn from_piece(piece: Piece) !NonPawnPiece {
        return switch (piece) {
            .Rook, .Knight, .Bishop, .Queen, .King => @enumFromInt(@intFromEnum(piece)),
            .Pawn => error.InvalidPiece,
        };
    }
};

/// A type that maps `NonKingPiece` to `T`.
pub fn ByNonKingPiece(comptime T: type) type {
    return std.EnumArray(NonKingPiece, T);
}

/// A type that maps `Piece` to `T`.
pub fn ByPiece(comptime T: type) type {
    return std.EnumArray(Piece, T);
}

/// A type that maps `PromotionPiece` to `T`.
pub fn ByPromotionPiece(comptime T: type) type {
    return std.EnumArray(PromotionPiece, T);
}

/// A piece that has an associated player.
pub const OwnedPiece = struct {
    /// The player that owns the piece.
    player: Player,
    /// The piece itself.
    piece: Piece,
};

/// A piece that is not a king and has an associated player.
pub const OwnedNonKingPiece = struct {
    player: Player,
    piece: NonKingPiece,

    /// Convert to an `OwnedPiece` (convert inner `NonKingPiece` to `Piece`).
    pub fn to_owned(self: OwnedNonKingPiece) OwnedPiece {
        return OwnedPiece {
            .player = self.player,
            .piece = self.piece.to_piece(),
        };
    }
};

/// A piece that is not a pawn and has an associated player.
pub const OwnedNonPawnPiece = struct {
    player: Player,
    piece: NonPawnPiece,

    /// Convert to an `OwnedPiece` (convert inner `NonPawnPiece` to `Piece`).
    pub fn to_owned(self: OwnedNonKingPiece) OwnedPiece {
        return OwnedPiece {
            .player = self.player,
            .piece = self.piece.to_piece(),
        };
    }
};
