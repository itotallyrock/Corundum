const std = @import("std");
const Bitboard = @import("bitboard.zig").Bitboard;
const Player = @import("players.zig").Player;

pub const Direction = enum(i5) {
    North = 8,
    South = -8,
    East = 1,
    West = -1,
    NorthEast = 9,
    NorthWest = 7,
    SouthEast = -7,
    SouthWest = -9,

    pub fn opposite(self: Direction) Direction {
        return @enumFromInt(-@intFromEnum(self));
    }

    pub fn forward(player: Player) Direction {
        switch (player) {
            .White => return .North,
            .Black => return .South,
        }
    }
};

pub const File = enum(u3) {
    A, B, C, D, E, F, G, H,

    pub fn ep_square_for(self: File, player: Player) EnPassantSquare {
        return @enumFromInt(@as(u6, @intFromEnum(self)) + @as(u6, @intFromEnum(Rank.ep_rank_for(player))) * 8);
    }
};

pub const Rank = enum(u3) {
    _1, _2, _3, _4, _5, _6, _7, _8,

    pub fn ep_rank_for(player: Player) Rank {
        if (player == .White) {
            return ._3;
        } else {
            return ._6;
        }
    }
};

pub const Square = enum(u6) {
    A1, B1, C1, D1, E1, F1, G1, H1,
    A2, B2, C2, D2, E2, F2, G2, H2,
    A3, B3, C3, D3, E3, F3, G3, H3,
    A4, B4, C4, D4, E4, F4, G4, H4,
    A5, B5, C5, D5, E5, F5, G5, H5,
    A6, B6, C6, D6, E6, F6, G6, H6,
    A7, B7, C7, D7, E7, F7, G7, H7,
    A8, B8, C8, D8, E8, F8, G8, H8,

    pub fn from_rank_and_file(rank: Rank, file: File) Square {
        return @enumFromInt(@as(u8, @intFromEnum(rank)) * 8 + @as(u8, @intFromEnum(file)));
    }

    pub fn to_bitboard(self: Square) Bitboard {
        return Bitboard { .mask = Bitboard.A1.mask << @intFromEnum(self) };
    }

    pub fn shift(self: Square, direction: Direction) ?Square {
        const offset = @as(i8, @intFromEnum(self)) + @as(i8, @intFromEnum(direction));
        if (offset < 0 or offset > 63) return null;
        return @enumFromInt(offset);
    }
};

pub const EnPassantSquare = enum(u6) {
    A3 = @intFromEnum(Square.A3), B3 = @intFromEnum(Square.B3), C3 = @intFromEnum(Square.C3), D3 = @intFromEnum(Square.D3), E3 = @intFromEnum(Square.E3), F3 = @intFromEnum(Square.F3), G3 = @intFromEnum(Square.G3), H3 = @intFromEnum(Square.H3),
    A6 = @intFromEnum(Square.A6), B6 = @intFromEnum(Square.B6), C6 = @intFromEnum(Square.C6), D6 = @intFromEnum(Square.D6), E6 = @intFromEnum(Square.E6), F6 = @intFromEnum(Square.F6), G6 = @intFromEnum(Square.G6), H6 = @intFromEnum(Square.H6),

    pub fn to_square(self: EnPassantSquare) Square {
        return @enumFromInt(@intFromEnum(self));
    }

    pub fn from_square(square: Square) !EnPassantSquare {
        return switch (square) {
            .A3 => .A3,
            .B3 => .B3,
            .C3 => .C3,
            .D3 => .D3,
            .E3 => .E3,
            .F3 => .F3,
            .G3 => .G3,
            .H3 => .H3,
            .A6 => .A6,
            .B6 => .B6,
            .C6 => .C6,
            .D6 => .D6,
            .E6 => .E6,
            .F6 => .F6,
            .G6 => .G6,
            .H6 => .H6,
            ._ => error.InvalidEnPassantSquare,
        };
    }
};

pub fn BySquare(comptime T: type) type {
    return std.EnumArray(Square, T);
}

pub fn ByEnPassantSquare(comptime T: type) type {
    return std.EnumArray(EnPassantSquare, T);
}

pub fn ByDirection(comptime T: type) type {
    return std.EnumArray(Direction, T);
}