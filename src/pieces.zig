const std = @import("std");
const Player = @import("players.zig").Player;

/// A piece on the board.
pub const Piece = enum(u3) {
    pawn,
    rook,
    knight,
    bishop,
    queen,
    king,

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
    pawn = @intFromEnum(Piece.pawn),
    rook = @intFromEnum(Piece.rook),
    knight = @intFromEnum(Piece.knight),
    bishop = @intFromEnum(Piece.bishop),
    queen = @intFromEnum(Piece.queen),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn to_piece(self: NonKingPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn from_piece(piece: Piece) !NonKingPiece {
        return switch (piece) {
            .pawn, .rook, .knight, .bishop, .queen => @enumFromInt(@intFromEnum(piece)),
            .king => error.InvalidPiece,
        };
    }

    test to_piece {
        try std.testing.expectEqual(NonKingPiece.rook.to_piece(), Piece.rook);
        try std.testing.expectEqual(NonKingPiece.queen.to_piece(), Piece.queen);
        try std.testing.expectEqual(NonKingPiece.pawn.to_piece(), Piece.pawn);
        try std.testing.expectEqual(NonKingPiece.knight.to_piece(), Piece.knight);
        try std.testing.expectEqual(NonKingPiece.bishop.to_piece(), Piece.bishop);
    }

    test from_piece {
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.rook), NonKingPiece.rook);
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.queen), NonKingPiece.queen);
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.pawn), NonKingPiece.pawn);
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.knight), NonKingPiece.knight);
        try std.testing.expectEqual(NonKingPiece.from_piece(Piece.bishop), NonKingPiece.bishop);
        try std.testing.expectError(error.InvalidPiece, NonKingPiece.from_piece(Piece.king));
    }
};

/// A piece that a pawn can be promoted to.
pub const PromotionPiece = enum(u3) {
    rook = @intFromEnum(Piece.rook),
    knight = @intFromEnum(Piece.knight),
    bishop = @intFromEnum(Piece.bishop),
    queen = @intFromEnum(Piece.queen),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn to_piece(self: PromotionPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn from_piece(piece: Piece) !PromotionPiece {
        return switch (piece) {
            .rook, .knight, .bishop, .queen => @enumFromInt(@intFromEnum(piece)),
            .pawn, .king => error.InvalidPiece,
        };
    }

    test to_piece {
        try std.testing.expectEqual(PromotionPiece.rook.to_piece(), Piece.rook);
        try std.testing.expectEqual(PromotionPiece.queen.to_piece(), Piece.queen);
        try std.testing.expectEqual(PromotionPiece.knight.to_piece(), Piece.knight);
        try std.testing.expectEqual(PromotionPiece.bishop.to_piece(), Piece.bishop);
    }

    test from_piece {
        try std.testing.expectEqual(PromotionPiece.from_piece(Piece.rook), PromotionPiece.rook);
        try std.testing.expectEqual(PromotionPiece.from_piece(Piece.queen), PromotionPiece.queen);
        try std.testing.expectEqual(PromotionPiece.from_piece(Piece.knight), PromotionPiece.knight);
        try std.testing.expectEqual(PromotionPiece.from_piece(Piece.bishop), PromotionPiece.bishop);
        try std.testing.expectError(error.InvalidPiece, PromotionPiece.from_piece(Piece.pawn));
        try std.testing.expectError(error.InvalidPiece, PromotionPiece.from_piece(Piece.king));
    }
};

/// A piece that is not a pawn.
pub const NonPawnPiece = enum(u3) {
    rook = @intFromEnum(Piece.rook),
    knight = @intFromEnum(Piece.knight),
    bishop = @intFromEnum(Piece.bishop),
    queen = @intFromEnum(Piece.queen),
    king = @intFromEnum(Piece.king),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn to_piece(self: NonPawnPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn from_piece(piece: Piece) !NonPawnPiece {
        return switch (piece) {
            .rook, .knight, .bishop, .queen, .king => @enumFromInt(@intFromEnum(piece)),
            .pawn => error.InvalidPiece,
        };
    }

    test to_piece {
        try std.testing.expectEqual(NonPawnPiece.rook.to_piece(), Piece.rook);
        try std.testing.expectEqual(NonPawnPiece.queen.to_piece(), Piece.queen);
        try std.testing.expectEqual(NonPawnPiece.knight.to_piece(), Piece.knight);
        try std.testing.expectEqual(NonPawnPiece.bishop.to_piece(), Piece.bishop);
        try std.testing.expectEqual(NonPawnPiece.king.to_piece(), Piece.king);
    }

    test from_piece {
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.rook), NonPawnPiece.rook);
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.queen), NonPawnPiece.queen);
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.knight), NonPawnPiece.knight);
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.bishop), NonPawnPiece.bishop);
        try std.testing.expectEqual(NonPawnPiece.from_piece(Piece.king), NonPawnPiece.king);
        try std.testing.expectError(error.InvalidPiece, NonPawnPiece.from_piece(Piece.pawn));
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
