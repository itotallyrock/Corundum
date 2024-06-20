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
        return OwnedPiece{
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

    test to_piece {
        try std.testing.expectEqual(NonKingPiece.Rook.to_piece(), Piece.Rook);
        try std.testing.expectEqual(NonKingPiece.Queen.to_piece(), Piece.Queen);
        try std.testing.expectEqual(NonKingPiece.Pawn.to_piece(), Piece.Pawn);
        try std.testing.expectEqual(NonKingPiece.Knight.to_piece(), Piece.Knight);
        try std.testing.expectEqual(NonKingPiece.Bishop.to_piece(), Piece.Bishop);
    }

    test from_piece {
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.Rook), NonKingPiece.Rook);
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.Queen), NonKingPiece.Queen);
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.Pawn), NonKingPiece.Pawn);
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.Knight), NonKingPiece.Knight);
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.Bishop), NonKingPiece.Bishop);
        try std.testing.expectError(error.InvalidPiece, NonKingPiece.from_piece(Piece.King));
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
            .Pawn, .King => error.InvalidPiece,
        };
    }

    test to_piece {
        try std.testing.expectEqual(PromotionPiece.Rook.to_piece(), Piece.Rook);
        try std.testing.expectEqual(PromotionPiece.Queen.to_piece(), Piece.Queen);
        try std.testing.expectEqual(PromotionPiece.Knight.to_piece(), Piece.Knight);
        try std.testing.expectEqual(PromotionPiece.Bishop.to_piece(), Piece.Bishop);
    }

    test from_piece {
        try std.testing.expectEqual(PromotionPiece.from_piece(Piece.Rook), PromotionPiece.Rook);
        try std.testing.expectEqual(PromotionPiece.from_piece(Piece.Queen), PromotionPiece.Queen);
        try std.testing.expectEqual(PromotionPiece.from_piece(Piece.Knight), PromotionPiece.Knight);
        try std.testing.expectEqual(PromotionPiece.from_piece(Piece.Bishop), PromotionPiece.Bishop);
        try std.testing.expectError(error.InvalidPiece, PromotionPiece.from_piece(Piece.Pawn));
        try std.testing.expectError(error.InvalidPiece, PromotionPiece.from_piece(Piece.King));
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

    test to_piece {
        try std.testing.expectEqual(NonPawnPiece.Rook.to_piece(), Piece.Rook);
        try std.testing.expectEqual(NonPawnPiece.Queen.to_piece(), Piece.Queen);
        try std.testing.expectEqual(NonPawnPiece.Knight.to_piece(), Piece.Knight);
        try std.testing.expectEqual(NonPawnPiece.Bishop.to_piece(), Piece.Bishop);
        try std.testing.expectEqual(NonPawnPiece.King.to_piece(), Piece.King);
    }

    test from_piece {
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.Rook), NonPawnPiece.Rook);
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.Queen), NonPawnPiece.Queen);
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.Knight), NonPawnPiece.Knight);
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.Bishop), NonPawnPiece.Bishop);
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.King), NonPawnPiece.King);
        try std.testing.expectError(error.InvalidPiece, NonPawnPiece.from_piece(Piece.Pawn));
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
        return OwnedPiece{
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
        return OwnedPiece{
            .player = self.player,
            .piece = self.piece.to_piece(),
        };
    }
};
