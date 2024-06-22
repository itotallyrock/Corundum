const std = @import("std");
const Bitboard = @import("bitboard.zig").Bitboard;
const Player = @import("players.zig").Player;
const Direction = @import("directions.zig").Direction;

/// A column index for the board
pub const File = enum(u3) {
    // zig fmt: off
    A, B, C, D, E, F, G, H,
    // zig fmt: on

    /// Returns the en passant square on the given file for the desired player
    pub fn epSquareFor(self: File, player: Player) EnPassantSquare {
        return @enumFromInt(@as(u6, @intFromEnum(self)) + @as(u6, @intFromEnum(Rank.ep_rank_for(player))) * 8);
    }

    test epSquareFor {
        // White
        try std.testing.expectEqual(File.A.epSquareFor(.white), EnPassantSquare.A3);
        try std.testing.expectEqual(File.B.epSquareFor(.white), EnPassantSquare.B3);
        try std.testing.expectEqual(File.C.epSquareFor(.white), EnPassantSquare.C3);
        try std.testing.expectEqual(File.D.epSquareFor(.white), EnPassantSquare.D3);
        try std.testing.expectEqual(File.E.epSquareFor(.white), EnPassantSquare.E3);
        try std.testing.expectEqual(File.F.epSquareFor(.white), EnPassantSquare.F3);
        try std.testing.expectEqual(File.G.epSquareFor(.white), EnPassantSquare.G3);
        // Black
        try std.testing.expectEqual(File.H.epSquareFor(.white), EnPassantSquare.H3);
        try std.testing.expectEqual(File.A.epSquareFor(.black), EnPassantSquare.A6);
        try std.testing.expectEqual(File.B.epSquareFor(.black), EnPassantSquare.B6);
        try std.testing.expectEqual(File.C.epSquareFor(.black), EnPassantSquare.C6);
        try std.testing.expectEqual(File.D.epSquareFor(.black), EnPassantSquare.D6);
        try std.testing.expectEqual(File.E.epSquareFor(.black), EnPassantSquare.E6);
        try std.testing.expectEqual(File.F.epSquareFor(.black), EnPassantSquare.F6);
        try std.testing.expectEqual(File.G.epSquareFor(.black), EnPassantSquare.G6);
        try std.testing.expectEqual(File.H.epSquareFor(.black), EnPassantSquare.H6);
    }
};

/// A row index for the board
pub const Rank = enum(u3) {
    // zig fmt: off
    _1, _2, _3, _4, _5, _6, _7, _8,
    // zig fmt: on

    /// Returns the rank for the en passant square for the desired player
    pub fn ep_rank_for(player: Player) Rank {
        if (player == .white) {
            return ._3;
        } else {
            return ._6;
        }
    }

    test ep_rank_for {
        try std.testing.expectEqual(Rank.ep_rank_for(.white), Rank._3);
        try std.testing.expectEqual(Rank.ep_rank_for(.black), Rank._6);
    }
};

/// A location for a single tile on the board.
pub const Square = enum(u6) {
    // zig fmt: off
    A1, B1, C1, D1, E1, F1, G1, H1,
    A2, B2, C2, D2, E2, F2, G2, H2,
    A3, B3, C3, D3, E3, F3, G3, H3,
    A4, B4, C4, D4, E4, F4, G4, H4,
    A5, B5, C5, D5, E5, F5, G5, H5,
    A6, B6, C6, D6, E6, F6, G6, H6,
    A7, B7, C7, D7, E7, F7, G7, H7,
    A8, B8, C8, D8, E8, F8, G8, H8,
    // zig fmt: on

    /// Creates a square from a file and rank.
    pub fn from_file_and_rank(file: File, rank: Rank) Square {
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
        return Bitboard{ .mask = Bitboard.A1.mask << @intFromEnum(self) };
    }

    /// Try to shift/move the square in the given direction.
    /// Returns null if the slided square would be out of bounds.
    pub fn shift(self: Square, comptime direction: Direction) ?Square {
        return self
            .toBitboard()
            .shift(direction)
            .getSquare();
    }

    test from_file_and_rank {
        try std.testing.expectEqual(Square.from_file_and_rank(File.A, Rank._1), Square.A1);
        try std.testing.expectEqual(Square.from_file_and_rank(File.B, Rank._4), Square.B4);
        try std.testing.expectEqual(Square.from_file_and_rank(File.C, Rank._8), Square.C8);
        try std.testing.expectEqual(Square.from_file_and_rank(File.D, Rank._3), Square.D3);
        try std.testing.expectEqual(Square.from_file_and_rank(File.E, Rank._6), Square.E6);
        try std.testing.expectEqual(Square.from_file_and_rank(File.F, Rank._2), Square.F2);
        try std.testing.expectEqual(Square.from_file_and_rank(File.G, Rank._7), Square.G7);
        try std.testing.expectEqual(Square.from_file_and_rank(File.H, Rank._5), Square.H5);
        try std.testing.expectEqual(Square.from_file_and_rank(File.A, Rank._5), Square.A5);
        try std.testing.expectEqual(Square.from_file_and_rank(File.B, Rank._2), Square.B2);
        try std.testing.expectEqual(Square.from_file_and_rank(File.C, Rank._7), Square.C7);
        try std.testing.expectEqual(Square.from_file_and_rank(File.D, Rank._1), Square.D1);
        try std.testing.expectEqual(Square.from_file_and_rank(File.E, Rank._8), Square.E8);
        try std.testing.expectEqual(Square.from_file_and_rank(File.F, Rank._4), Square.F4);
        try std.testing.expectEqual(Square.from_file_and_rank(File.G, Rank._1), Square.G1);
    }

    test fileOf {
        try std.testing.expectEqual(Square.A1.fileOf(), File.A);
        try std.testing.expectEqual(Square.B4.fileOf(), File.B);
        try std.testing.expectEqual(Square.C5.fileOf(), File.C);
        try std.testing.expectEqual(Square.D8.fileOf(), File.D);
        try std.testing.expectEqual(Square.E2.fileOf(), File.E);
        try std.testing.expectEqual(Square.G5.fileOf(), File.G);
        try std.testing.expectEqual(Square.H8.fileOf(), File.H);
        try std.testing.expectEqual(Square.A8.fileOf(), File.A);
        try std.testing.expectEqual(Square.H1.fileOf(), File.H);
        try std.testing.expectEqual(Square.F7.fileOf(), File.F);
    }

    test rankOf {
        try std.testing.expectEqual(Square.A1.rankOf(), Rank._1);
        try std.testing.expectEqual(Square.B4.rankOf(), Rank._4);
        try std.testing.expectEqual(Square.C5.rankOf(), Rank._5);
        try std.testing.expectEqual(Square.D8.rankOf(), Rank._8);
        try std.testing.expectEqual(Square.E2.rankOf(), Rank._2);
        try std.testing.expectEqual(Square.G5.rankOf(), Rank._5);
        try std.testing.expectEqual(Square.H8.rankOf(), Rank._8);
        try std.testing.expectEqual(Square.A8.rankOf(), Rank._8);
        try std.testing.expectEqual(Square.H1.rankOf(), Rank._1);
        try std.testing.expectEqual(Square.F7.rankOf(), Rank._7);
    }

    test toBitboard {
        try std.testing.expectEqual(Square.A1.toBitboard(), Bitboard.A1);
        try std.testing.expectEqual(Square.B4.toBitboard(), Bitboard{ .mask = 0x2000000 });
        try std.testing.expectEqual(Square.G5.toBitboard(), Bitboard{ .mask = 0x4000000000 });
        try std.testing.expectEqual(Square.H8.toBitboard(), Bitboard{ .mask = 0x8000000000000000 });
        try std.testing.expectEqual(Square.A8.toBitboard(), Bitboard{ .mask = 0x100000000000000 });
        try std.testing.expectEqual(Square.H1.toBitboard(), Bitboard{ .mask = 0x80 });
        try std.testing.expectEqual(Square.F7.toBitboard(), Bitboard{ .mask = 0x20000000000000 });
        try std.testing.expectEqual(Square.C2.toBitboard(), Bitboard{ .mask = 0x400 });
        try std.testing.expectEqual(Square.D3.toBitboard(), Bitboard{ .mask = 0x80000 });
        try std.testing.expectEqual(Square.E6.toBitboard(), Bitboard{ .mask = 0x100000000000 });
    }

    test shift {
        // Test A1 (bottom left corner)
        try std.testing.expectEqual(Square.A1.shift(Direction.North), .A2);
        try std.testing.expectEqual(Square.A1.shift(Direction.NorthEast), .B2);
        try std.testing.expectEqual(Square.A1.shift(Direction.East), .B1);
        try std.testing.expectEqual(Square.A1.shift(Direction.SouthEast), null);
        try std.testing.expectEqual(Square.A1.shift(Direction.South), null);
        try std.testing.expectEqual(Square.A1.shift(Direction.SouthWest), null);
        try std.testing.expectEqual(Square.A1.shift(Direction.West), null);

        // Test H8 (top right corner)
        try std.testing.expectEqual(Square.H8.shift(Direction.North), null);
        try std.testing.expectEqual(Square.H8.shift(Direction.NorthEast), null);
        try std.testing.expectEqual(Square.H8.shift(Direction.East), null);
        try std.testing.expectEqual(Square.H8.shift(Direction.SouthEast), null);
        try std.testing.expectEqual(Square.H8.shift(Direction.South), .H7);
        try std.testing.expectEqual(Square.H8.shift(Direction.SouthWest), .G7);
        try std.testing.expectEqual(Square.H8.shift(Direction.West), .G8);

        // Test E4 (middle)
        try std.testing.expectEqual(Square.E4.shift(Direction.North), .E5);
        try std.testing.expectEqual(Square.E4.shift(Direction.NorthEast), .F5);
        try std.testing.expectEqual(Square.E4.shift(Direction.NorthWest), .D5);
        try std.testing.expectEqual(Square.E4.shift(Direction.East), .F4);
        try std.testing.expectEqual(Square.E4.shift(Direction.SouthEast), .F3);
        try std.testing.expectEqual(Square.E4.shift(Direction.South), .E3);
        try std.testing.expectEqual(Square.E4.shift(Direction.SouthWest), .D3);
        try std.testing.expectEqual(Square.E4.shift(Direction.West), .D4);
    }
};

/// A subset of `Square` used only for en passant tiles.
pub const EnPassantSquare = enum(u6) {
    // zig fmt: off
    A3 = @intFromEnum(Square.A3), B3 = @intFromEnum(Square.B3), C3 = @intFromEnum(Square.C3), D3 = @intFromEnum(Square.D3), E3 = @intFromEnum(Square.E3), F3 = @intFromEnum(Square.F3), G3 = @intFromEnum(Square.G3), H3 = @intFromEnum(Square.H3),
    A6 = @intFromEnum(Square.A6), B6 = @intFromEnum(Square.B6), C6 = @intFromEnum(Square.C6), D6 = @intFromEnum(Square.D6), E6 = @intFromEnum(Square.E6), F6 = @intFromEnum(Square.F6), G6 = @intFromEnum(Square.G6), H6 = @intFromEnum(Square.H6),
    // zig fmt: on

    /// Create a normal `Square` from an `EnPassantSquare`
    pub fn to_square(self: EnPassantSquare) Square {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Create an `EnPassantSquare` from a `Square`
    pub fn from_square(square: Square) !EnPassantSquare {
        return switch (square) {
            .A3, .B3, .C3, .D3, .E3, .F3, .G3, .H3, .A6, .B6, .C6, .D6, .E6, .F6, .G6, .H6 => @enumFromInt(@intFromEnum(square)),
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
