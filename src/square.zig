const std = @import("std");
const Bitboard = @import("bitboard.zig").Bitboard;
const Player = @import("players.zig").Player;

/// Represents an absolute direction on the board (always from white's perspective).
pub const Direction = enum(i5) {
    North = 8,
    South = -8,
    East = 1,
    West = -1,
    NorthEast = 9,
    NorthWest = 7,
    SouthEast = -7,
    SouthWest = -9,

    /// Returns the direction that is the opposite of this one.
    pub fn opposite(self: Direction) Direction {
        return @enumFromInt(-@intFromEnum(self));
    }

    /// Returns north or south depending on the player.
    pub fn forward(player: Player) Direction {
        switch (player) {
            .White => return .North,
            .Black => return .South,
        }
    }
};

/// A column index for the board
pub const File = enum(u3) {
    A, B, C, D, E, F, G, H,

    /// Returns the en passant square on the given file for the desired player
    pub fn ep_square_for(self: File, player: Player) EnPassantSquare {
        return @enumFromInt(@as(u6, @intFromEnum(self)) + @as(u6, @intFromEnum(Rank.ep_rank_for(player))) * 8);
    }
};

/// A row index for the board
pub const Rank = enum(u3) {
    _1, _2, _3, _4, _5, _6, _7, _8,

    /// Returns the rank for the en passant square for the desired player
    pub fn ep_rank_for(player: Player) Rank {
        if (player == .White) {
            return ._3;
        } else {
            return ._6;
        }
    }
};

/// A location for a single tile on the board.
pub const Square = enum(u6) {
    A1, B1, C1, D1, E1, F1, G1, H1,
    A2, B2, C2, D2, E2, F2, G2, H2,
    A3, B3, C3, D3, E3, F3, G3, H3,
    A4, B4, C4, D4, E4, F4, G4, H4,
    A5, B5, C5, D5, E5, F5, G5, H5,
    A6, B6, C6, D6, E6, F6, G6, H6,
    A7, B7, C7, D7, E7, F7, G7, H7,
    A8, B8, C8, D8, E8, F8, G8, H8,

    /// Creates a square from a rank and file.
    pub fn from_rank_and_file(rank: Rank, file: File) Square {
        return @enumFromInt(@as(u8, @intFromEnum(rank)) * 8 + @as(u8, @intFromEnum(file)));
    }

    /// Creates a `Bitboard` with only this square set.
    pub fn to_bitboard(self: Square) Bitboard {
        return Bitboard { .mask = Bitboard.A1.mask << @intFromEnum(self) };
    }

    /// Try to shift/move the square in the given direction.
    /// Returns null if the slided square would be out of bounds.
    pub fn shift(self: Square, direction: Direction) ?Square {
        const offset = @as(i8, @intFromEnum(self)) + @as(i8, @intFromEnum(direction));
        if (offset < 0 or offset > 63) return null;
        return @enumFromInt(offset);
    }
};

/// A subset of `Square` used only for en passant tiles.
pub const EnPassantSquare = enum(u6) {
    A3 = @intFromEnum(Square.A3), B3 = @intFromEnum(Square.B3), C3 = @intFromEnum(Square.C3), D3 = @intFromEnum(Square.D3), E3 = @intFromEnum(Square.E3), F3 = @intFromEnum(Square.F3), G3 = @intFromEnum(Square.G3), H3 = @intFromEnum(Square.H3),
    A6 = @intFromEnum(Square.A6), B6 = @intFromEnum(Square.B6), C6 = @intFromEnum(Square.C6), D6 = @intFromEnum(Square.D6), E6 = @intFromEnum(Square.E6), F6 = @intFromEnum(Square.F6), G6 = @intFromEnum(Square.G6), H6 = @intFromEnum(Square.H6),

    /// Create a normal `Square` from an `EnPassantSquare`
    pub fn to_square(self: EnPassantSquare) Square {
        return @enumFromInt(@intFromEnum(self));
    }

    /// Create an `EnPassantSquare` from a `Square`
    pub fn from_square(square: Square) !EnPassantSquare {
        return switch (square) {
            .A3, .B3, .C3, .D3, .E3, .F3, .G3, .H3, .A6, .B6, .C6, .D6, .E6, .F6, .G6, .H6 => @enumFromInt(@intFromEnum(square)),
            ._ => error.InvalidEnPassantSquare,
        };
    }
};

/// A type that is indexed by `Square`
pub fn BySquare(comptime T: type) type {
    return std.EnumArray(Square, T);
}

/// A type that is indexed by `EnPassantSquare`
pub fn ByEnPassantSquare(comptime T: type) type {
    return std.EnumArray(EnPassantSquare, T);
}

/// A type that is indexed by `Direction`
pub fn ByDirection(comptime T: type) type {
    return std.EnumArray(Direction, T);
}
