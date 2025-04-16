const std = @import("std");
const Bitboard = @import("./bitboard.zig").Bitboard;
const Player = @import("./player.zig").Player;
const BoardDirection = @import("./direction.zig").BoardDirection;
const CastleDirection = @import("./castle.zig").CastleDirection;

/// A column index for the board
pub const File = enum(u3) {
    // zig fmt: off
    a, b, c, d, e, f, g, h,
    // zig fmt: on

    /// Returns the en passant square on the given file for the desired player
    pub fn epSquareFor(self: File, player: Player) EnPassantSquare {
        return EnPassantSquare.from_square(Square.fromFileAndRank(self, Rank.epRankFor(player))) catch unreachable;
    }

    /// Returns the promotion square on the given file for the desired player
    pub fn promotionSquareFor(self: File, player: Player) Square {
        return Square.fromFileAndRank(self, Rank.promotionTargetRank(player));
    }

    /// Get the file the king moves to when castling
    pub fn castlingKingTargetFile(castle_direction: CastleDirection) File {
        if (castle_direction == .king_side) {
            return .g;
        } else {
            return .c;
        }
    }

    /// Get the file the rook moves to when castling
    pub fn castlingRookTargetFile(castle_direction: CastleDirection) File {
        if (castle_direction == .king_side) {
            return .f;
        } else {
            return .d;
        }
    }

    test castlingKingTargetFile {
        try std.testing.expectEqual(File.castlingKingTargetFile(.king_side), File.g);
        try std.testing.expectEqual(File.castlingKingTargetFile(.queen_side), File.c);
    }

    test castlingRookTargetFile {
        try std.testing.expectEqual(File.castlingRookTargetFile(.king_side), File.f);
        try std.testing.expectEqual(File.castlingRookTargetFile(.queen_side), File.d);
    }

    test epSquareFor {
        // White
        try std.testing.expectEqual(File.a.epSquareFor(.white), EnPassantSquare.a3);
        try std.testing.expectEqual(File.b.epSquareFor(.white), EnPassantSquare.b3);
        try std.testing.expectEqual(File.c.epSquareFor(.white), EnPassantSquare.c3);
        try std.testing.expectEqual(File.d.epSquareFor(.white), EnPassantSquare.d3);
        try std.testing.expectEqual(File.e.epSquareFor(.white), EnPassantSquare.e3);
        try std.testing.expectEqual(File.f.epSquareFor(.white), EnPassantSquare.f3);
        try std.testing.expectEqual(File.g.epSquareFor(.white), EnPassantSquare.g3);
        // Black
        try std.testing.expectEqual(File.h.epSquareFor(.white), EnPassantSquare.h3);
        try std.testing.expectEqual(File.a.epSquareFor(.black), EnPassantSquare.a6);
        try std.testing.expectEqual(File.b.epSquareFor(.black), EnPassantSquare.b6);
        try std.testing.expectEqual(File.c.epSquareFor(.black), EnPassantSquare.c6);
        try std.testing.expectEqual(File.d.epSquareFor(.black), EnPassantSquare.d6);
        try std.testing.expectEqual(File.e.epSquareFor(.black), EnPassantSquare.e6);
        try std.testing.expectEqual(File.f.epSquareFor(.black), EnPassantSquare.f6);
        try std.testing.expectEqual(File.g.epSquareFor(.black), EnPassantSquare.g6);
        try std.testing.expectEqual(File.h.epSquareFor(.black), EnPassantSquare.h6);
    }

    test promotionSquareFor {
        try std.testing.expectEqual(File.a.promotionSquareFor(.white), Square.a8);
        try std.testing.expectEqual(File.b.promotionSquareFor(.white), Square.b8);
        try std.testing.expectEqual(File.c.promotionSquareFor(.white), Square.c8);
        try std.testing.expectEqual(File.d.promotionSquareFor(.white), Square.d8);
        try std.testing.expectEqual(File.e.promotionSquareFor(.white), Square.e8);
        try std.testing.expectEqual(File.f.promotionSquareFor(.white), Square.f8);
        try std.testing.expectEqual(File.g.promotionSquareFor(.white), Square.g8);
        try std.testing.expectEqual(File.h.promotionSquareFor(.white), Square.h8);
        try std.testing.expectEqual(File.a.promotionSquareFor(.black), Square.a1);
        try std.testing.expectEqual(File.b.promotionSquareFor(.black), Square.b1);
        try std.testing.expectEqual(File.c.promotionSquareFor(.black), Square.c1);
        try std.testing.expectEqual(File.d.promotionSquareFor(.black), Square.d1);
        try std.testing.expectEqual(File.e.promotionSquareFor(.black), Square.e1);
        try std.testing.expectEqual(File.f.promotionSquareFor(.black), Square.f1);
        try std.testing.expectEqual(File.g.promotionSquareFor(.black), Square.g1);
        try std.testing.expectEqual(File.h.promotionSquareFor(.black), Square.h1);
    }
};

/// A row index for the board
pub const Rank = enum(u3) {
    // zig fmt: off
    _1, _2, _3, _4, _5, _6, _7, _8,
    // zig fmt: on

    /// Returns the rank for the en passant square for the desired player
    pub fn epRankFor(player: Player) Rank {
        if (player == .white) {
            return ._3;
        } else {
            return ._6;
        }
    }

    /// Returns the rank for a pawn promotion of the desired player
    pub fn promotionTargetRank(player: Player) Rank {
        if (player == .white) {
            return ._8;
        } else {
            return ._1;
        }
    }

    /// Returns the rank all pawns promote from for the desired player
    pub fn promotionFromRank(player: Player) Rank {
        if (player == .white) {
            return ._7;
        } else {
            return ._2;
        }
    }

    /// Returns the rank the major pieces start on for the desired player
    pub fn backRank(player: Player) Rank {
        if (player == .white) {
            return ._1;
        } else {
            return ._8;
        }
    }

    /// Returns the rank all pawns start on for the desired player
    pub fn pawnRank(player: Player) Rank {
        if (player == .white) {
            return ._2;
        } else {
            return ._7;
        }
    }

    /// Returns the rank all pawns double push end on for the desired player
    pub fn doublePushedRank(player: Player) Rank {
        if (player == .white) {
            return ._4;
        } else {
            return ._5;
        }
    }

    test doublePushedRank {
        try std.testing.expectEqual(Rank.doublePushedRank(.white), Rank._4);
        try std.testing.expectEqual(Rank.doublePushedRank(.black), Rank._5);
    }

    test promotionFromRank {
        try std.testing.expectEqual(Rank.promotionFromRank(.white), Rank._7);
        try std.testing.expectEqual(Rank.promotionFromRank(.black), Rank._2);
    }

    test pawnRank {
        try std.testing.expectEqual(Rank.pawnRank(.white), Rank._2);
        try std.testing.expectEqual(Rank.pawnRank(.black), Rank._7);
    }

    test epRankFor {
        try std.testing.expectEqual(Rank.epRankFor(.white), Rank._3);
        try std.testing.expectEqual(Rank.epRankFor(.black), Rank._6);
    }

    test promotionTargetRank {
        try std.testing.expectEqual(Rank.promotionTargetRank(.white), Rank._8);
        try std.testing.expectEqual(Rank.promotionTargetRank(.black), Rank._1);
    }

    test backRank {
        try std.testing.expectEqual(Rank.backRank(.white), Rank._1);
        try std.testing.expectEqual(Rank.backRank(.black), Rank._8);
    }
};

/// A location for a single tile on the board.
pub const Square = enum(u6) {
    // zig fmt: off
    a1, b1, c1, d1, e1, f1, g1, h1,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8,
    // zig fmt: on

    /// Creates a square from a file and rank.
    pub fn fromFileAndRank(file: File, rank: Rank) Square {
        return @enumFromInt(@as(u8, @intFromEnum(rank)) * 8 + @as(u8, @intFromEnum(file)));
    }

    /// Returns the rank of the square.
    pub fn rankOf(self: Square) Rank {
        return @enumFromInt(@as(u8, @intFromEnum(self)) / 8);
    }

    /// Returns the file of the square.
    pub fn fileOf(self: Square) File {
        return @enumFromInt(@as(u8, @intFromEnum(self)) % 8);
    }

    /// Creates a `Bitboard` with only this square set.
    pub fn toBitboard(self: Square) Bitboard {
        return Bitboard.initInt(Bitboard.a1.mask.mask << @intFromEnum(self));
    }

    /// Try to shift/move the square in the given direction.
    /// Returns null if the slided square would be out of bounds.
    pub fn shift(self: Square, direction: BoardDirection) ?Square {
        return self
            .toBitboard()
            .shift(direction)
            .getSquare();
    }

    test fromFileAndRank {
        try std.testing.expectEqual(Square.fromFileAndRank(.a, ._1), .a1);
        try std.testing.expectEqual(Square.fromFileAndRank(.b, ._4), .b4);
        try std.testing.expectEqual(Square.fromFileAndRank(.c, ._8), .c8);
        try std.testing.expectEqual(Square.fromFileAndRank(.d, ._3), .d3);
        try std.testing.expectEqual(Square.fromFileAndRank(.e, ._6), .e6);
        try std.testing.expectEqual(Square.fromFileAndRank(.f, ._2), .f2);
        try std.testing.expectEqual(Square.fromFileAndRank(.g, ._7), .g7);
        try std.testing.expectEqual(Square.fromFileAndRank(.h, ._5), .h5);
        try std.testing.expectEqual(Square.fromFileAndRank(.a, ._5), .a5);
        try std.testing.expectEqual(Square.fromFileAndRank(.b, ._2), .b2);
        try std.testing.expectEqual(Square.fromFileAndRank(.c, ._7), .c7);
        try std.testing.expectEqual(Square.fromFileAndRank(.d, ._1), .d1);
        try std.testing.expectEqual(Square.fromFileAndRank(.e, ._8), .e8);
        try std.testing.expectEqual(Square.fromFileAndRank(.f, ._4), .f4);
        try std.testing.expectEqual(Square.fromFileAndRank(.g, ._1), .g1);
    }

    test fileOf {
        try std.testing.expectEqual(Square.a1.fileOf(), .a);
        try std.testing.expectEqual(Square.b4.fileOf(), .b);
        try std.testing.expectEqual(Square.c5.fileOf(), .c);
        try std.testing.expectEqual(Square.d8.fileOf(), .d);
        try std.testing.expectEqual(Square.e2.fileOf(), .e);
        try std.testing.expectEqual(Square.g5.fileOf(), .g);
        try std.testing.expectEqual(Square.h8.fileOf(), .h);
        try std.testing.expectEqual(Square.a8.fileOf(), .a);
        try std.testing.expectEqual(Square.h1.fileOf(), .h);
        try std.testing.expectEqual(Square.f7.fileOf(), .f);
    }

    test rankOf {
        try std.testing.expectEqual(Square.a1.rankOf(), ._1);
        try std.testing.expectEqual(Square.b4.rankOf(), ._4);
        try std.testing.expectEqual(Square.c5.rankOf(), ._5);
        try std.testing.expectEqual(Square.d8.rankOf(), ._8);
        try std.testing.expectEqual(Square.e2.rankOf(), ._2);
        try std.testing.expectEqual(Square.g5.rankOf(), ._5);
        try std.testing.expectEqual(Square.h8.rankOf(), ._8);
        try std.testing.expectEqual(Square.a8.rankOf(), ._8);
        try std.testing.expectEqual(Square.h1.rankOf(), ._1);
        try std.testing.expectEqual(Square.f7.rankOf(), ._7);
    }

    test toBitboard {
        try std.testing.expectEqual(Square.a1.toBitboard(), Bitboard.a1);
        try std.testing.expectEqual(Square.b4.toBitboard(), Bitboard.initInt(0x2000000));
        try std.testing.expectEqual(Square.g5.toBitboard(), Bitboard.initInt(0x4000000000));
        try std.testing.expectEqual(Square.h8.toBitboard(), Bitboard.initInt(0x8000000000000000));
        try std.testing.expectEqual(Square.a8.toBitboard(), Bitboard.initInt(0x100000000000000));
        try std.testing.expectEqual(Square.h1.toBitboard(), Bitboard.initInt(0x80));
        try std.testing.expectEqual(Square.f7.toBitboard(), Bitboard.initInt(0x20000000000000));
        try std.testing.expectEqual(Square.c2.toBitboard(), Bitboard.initInt(0x400));
        try std.testing.expectEqual(Square.d3.toBitboard(), Bitboard.initInt(0x80000));
        try std.testing.expectEqual(Square.e6.toBitboard(), Bitboard.initInt(0x100000000000));
    }

    test shift {
        // Test A1 (bottom left corner)
        try std.testing.expectEqual(Square.a1.shift(.north), .a2);
        try std.testing.expectEqual(Square.a1.shift(.north_east), .b2);
        try std.testing.expectEqual(Square.a1.shift(.east), .b1);
        try std.testing.expectEqual(Square.a1.shift(.south_east), null);
        try std.testing.expectEqual(Square.a1.shift(.south), null);
        try std.testing.expectEqual(Square.a1.shift(.south_west), null);
        try std.testing.expectEqual(Square.a1.shift(.west), null);

        // Test H8 (top right corner)
        try std.testing.expectEqual(Square.h8.shift(.north), null);
        try std.testing.expectEqual(Square.h8.shift(.north_east), null);
        try std.testing.expectEqual(Square.h8.shift(.east), null);
        try std.testing.expectEqual(Square.h8.shift(.south_east), null);
        try std.testing.expectEqual(Square.h8.shift(.south), .h7);
        try std.testing.expectEqual(Square.h8.shift(.south_west), .g7);
        try std.testing.expectEqual(Square.h8.shift(.west), .g8);

        // Test E4 (middle)
        try std.testing.expectEqual(Square.e4.shift(.north), .e5);
        try std.testing.expectEqual(Square.e4.shift(.north_east), .f5);
        try std.testing.expectEqual(Square.e4.shift(.north_west), .d5);
        try std.testing.expectEqual(Square.e4.shift(.east), .f4);
        try std.testing.expectEqual(Square.e4.shift(.south_east), .f3);
        try std.testing.expectEqual(Square.e4.shift(.south), .e3);
        try std.testing.expectEqual(Square.e4.shift(.south_west), .d3);
        try std.testing.expectEqual(Square.e4.shift(.west), .d4);
    }
};

/// A subset of `Square` used only for en passant tiles.
pub const EnPassantSquare = enum(u6) {
    // zig fmt: off
    a3 = @intFromEnum(Square.a3), b3 = @intFromEnum(Square.b3), c3 = @intFromEnum(Square.c3), d3 = @intFromEnum(Square.d3), e3 = @intFromEnum(Square.e3), f3 = @intFromEnum(Square.f3), g3 = @intFromEnum(Square.g3), h3 = @intFromEnum(Square.h3),
    a6 = @intFromEnum(Square.a6), b6 = @intFromEnum(Square.b6), c6 = @intFromEnum(Square.c6), d6 = @intFromEnum(Square.d6), e6 = @intFromEnum(Square.e6), f6 = @intFromEnum(Square.f6), g6 = @intFromEnum(Square.g6), h6 = @intFromEnum(Square.h6),
    // zig fmt: on

    /// Create a normal `Square` from an `EnPassantSquare`
    pub fn to_square(self: EnPassantSquare) Square {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Create an `EnPassantSquare` from a `Square`
    pub fn from_square(square: Square) !EnPassantSquare {
        return switch (square) {
            .a3, .b3, .c3, .d3, .e3, .f3, .g3, .h3, .a6, .b6, .c6, .d6, .e6, .f6, .g6, .h6 => @enumFromInt(@intFromEnum(square)),
            else => error.InvalidEnPassantSquare,
        };
    }
};

/// A type that is indexed by `Rank`
pub fn ByRank(comptime T: type) type {
    return std.EnumArray(Rank, T);
}

/// A type that is indexed by `File`
pub fn ByFile(comptime T: type) type {
    return std.EnumArray(File, T);
}

/// A type that is indexed by `Square`
pub fn BySquare(comptime T: type) type {
    return std.EnumArray(Square, T);
}

/// A type that is indexed by `EnPassantSquare`
pub fn ByEnPassantSquare(comptime T: type) type {
    return std.EnumArray(EnPassantSquare, T);
}
