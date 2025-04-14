const std = @import("std");
const Player = @import("./player.zig").Player;

/// A piece on the board.
pub const Piece = enum(u3) {
    /// Either side's pawn
    pawn,
    /// Either side's rook/castle
    rook,
    /// Either side's knight
    knight,
    /// Either side's bishop
    bishop,
    /// Either side's queen
    queen,
    /// Either side's king
    king,
};

/// A piece that is not a king.
pub const NonKingPiece = enum(u3) {
    /// Either side's pawn
    pawn = @intFromEnum(Piece.pawn),
    /// Either side's rook/castle
    rook = @intFromEnum(Piece.rook),
    /// Either side's knight
    knight = @intFromEnum(Piece.knight),
    /// Either side's bishop
    bishop = @intFromEnum(Piece.bishop),
    /// Either side's queen
    queen = @intFromEnum(Piece.queen),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn toPiece(self: NonKingPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn fromPiece(piece: Piece) !NonKingPiece {
        return switch (piece) {
            .pawn, .rook, .knight, .bishop, .queen => @enumFromInt(@intFromEnum(piece)),
            .king => error.InvalidPiece,
        };
    }

    test toPiece {
        try std.testing.expectEqual(NonKingPiece.rook.toPiece(), Piece.rook);
        try std.testing.expectEqual(NonKingPiece.queen.toPiece(), Piece.queen);
        try std.testing.expectEqual(NonKingPiece.pawn.toPiece(), Piece.pawn);
        try std.testing.expectEqual(NonKingPiece.knight.toPiece(), Piece.knight);
        try std.testing.expectEqual(NonKingPiece.bishop.toPiece(), Piece.bishop);
    }

    test fromPiece {
        try std.testing.expectEqual(NonKingPiece.fromPiece(Piece.rook), NonKingPiece.rook);
        try std.testing.expectEqual(NonKingPiece.fromPiece(Piece.queen), NonKingPiece.queen);
        try std.testing.expectEqual(NonKingPiece.fromPiece(Piece.pawn), NonKingPiece.pawn);
        try std.testing.expectEqual(NonKingPiece.fromPiece(Piece.knight), NonKingPiece.knight);
        try std.testing.expectEqual(NonKingPiece.fromPiece(Piece.bishop), NonKingPiece.bishop);
        try std.testing.expectError(error.InvalidPiece, NonKingPiece.fromPiece(Piece.king));
    }
};

/// A piece that a pawn can be promoted to.
pub const PromotionPiece = enum(u3) {
    /// Promote to a rook
    rook = @intFromEnum(Piece.rook),
    /// Promote to a knight
    knight = @intFromEnum(Piece.knight),
    /// Promote to a bishop
    bishop = @intFromEnum(Piece.bishop),
    /// Promote to a queen
    queen = @intFromEnum(Piece.queen),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn toPiece(self: PromotionPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn fromPiece(piece: Piece) !PromotionPiece {
        return switch (piece) {
            .rook, .knight, .bishop, .queen => @enumFromInt(@intFromEnum(piece)),
            .pawn, .king => error.InvalidPiece,
        };
    }

    test toPiece {
        try std.testing.expectEqual(PromotionPiece.rook.toPiece(), Piece.rook);
        try std.testing.expectEqual(PromotionPiece.queen.toPiece(), Piece.queen);
        try std.testing.expectEqual(PromotionPiece.knight.toPiece(), Piece.knight);
        try std.testing.expectEqual(PromotionPiece.bishop.toPiece(), Piece.bishop);
    }

    test fromPiece {
        try std.testing.expectEqual(PromotionPiece.fromPiece(Piece.rook), PromotionPiece.rook);
        try std.testing.expectEqual(PromotionPiece.fromPiece(Piece.queen), PromotionPiece.queen);
        try std.testing.expectEqual(PromotionPiece.fromPiece(Piece.knight), PromotionPiece.knight);
        try std.testing.expectEqual(PromotionPiece.fromPiece(Piece.bishop), PromotionPiece.bishop);
        try std.testing.expectError(error.InvalidPiece, PromotionPiece.fromPiece(Piece.pawn));
        try std.testing.expectError(error.InvalidPiece, PromotionPiece.fromPiece(Piece.king));
    }
};

/// A piece that is not a pawn.
pub const NonPawnPiece = enum(u3) {
    /// Either side's rook/castle
    rook = @intFromEnum(Piece.rook),
    /// Either side's knight
    knight = @intFromEnum(Piece.knight),
    /// Either side's bishop
    bishop = @intFromEnum(Piece.bishop),
    /// Either side's queen
    queen = @intFromEnum(Piece.queen),
    /// Either side's king
    king = @intFromEnum(Piece.king),

    /// Convert to the corresponding vanilla `Piece`.
    pub fn toPiece(self: NonPawnPiece) Piece {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Try to convert from a vanilla `Piece`.
    pub fn fromPiece(piece: Piece) !NonPawnPiece {
        return switch (piece) {
            .rook, .knight, .bishop, .queen, .king => @enumFromInt(@intFromEnum(piece)),
            .pawn => error.InvalidPiece,
        };
    }

    test toPiece {
        try std.testing.expectEqual(NonPawnPiece.rook.toPiece(), Piece.rook);
        try std.testing.expectEqual(NonPawnPiece.queen.toPiece(), Piece.queen);
        try std.testing.expectEqual(NonPawnPiece.knight.toPiece(), Piece.knight);
        try std.testing.expectEqual(NonPawnPiece.bishop.toPiece(), Piece.bishop);
        try std.testing.expectEqual(NonPawnPiece.king.toPiece(), Piece.king);
    }

    test fromPiece {
        try std.testing.expectEqual(NonPawnPiece.fromPiece(Piece.rook), NonPawnPiece.rook);
        try std.testing.expectEqual(NonPawnPiece.fromPiece(Piece.queen), NonPawnPiece.queen);
        try std.testing.expectEqual(NonPawnPiece.fromPiece(Piece.knight), NonPawnPiece.knight);
        try std.testing.expectEqual(NonPawnPiece.fromPiece(Piece.bishop), NonPawnPiece.bishop);
        try std.testing.expectEqual(NonPawnPiece.fromPiece(Piece.king), NonPawnPiece.king);
        try std.testing.expectError(error.InvalidPiece, NonPawnPiece.fromPiece(Piece.pawn));
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
    /// The player that owns the piece.
    player: Player,
    /// The piece itself.
    piece: NonKingPiece,

    /// Convert to an `OwnedPiece` (convert inner `NonKingPiece` to `Piece`).
    pub fn to_owned(self: OwnedNonKingPiece) OwnedPiece {
        return OwnedPiece{
            .player = self.player,
            .piece = self.piece.toPiece(),
        };
    }
};

/// A piece that is not a pawn and has an associated player.
pub const OwnedNonPawnPiece = struct {
    /// The player that owns the piece.
    player: Player,
    /// The piece itself.
    piece: NonPawnPiece,

    /// Convert to an `OwnedPiece` (convert inner `NonPawnPiece` to `Piece`).
    pub fn to_owned(self: OwnedNonKingPiece) OwnedPiece {
        return OwnedPiece{
            .player = self.player,
            .piece = self.piece.toPiece(),
        };
    }
};
