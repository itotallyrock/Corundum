const std = @import("std");
const Player = @import("players.zig").Player;

/// Represents an absolute direction on the board (always from white's perspective).
pub const BoardDirection = enum(i5) {
    north = 8,
    south = -8,
    east = 1,
    west = -1,
    north_east = 9,
    north_west = 7,
    south_east = -7,
    south_west = -9,

    /// Returns the direction that is the opposite of this one.
    pub fn opposite(self: BoardDirection) BoardDirection {
        return @enumFromInt(-@intFromEnum(self));
    }

    /// Returns north or south depending on the player.
    pub fn forward(player: Player) BoardDirection {
        switch (player) {
            .white => return .north,
            .black => return .south,
        }
    }

    test opposite {
        try std.testing.expectEqual(BoardDirection.north.opposite(), BoardDirection.south);
        try std.testing.expectEqual(BoardDirection.south.opposite(), BoardDirection.north);
        try std.testing.expectEqual(BoardDirection.east.opposite(), BoardDirection.west);
        try std.testing.expectEqual(BoardDirection.west.opposite(), BoardDirection.east);
        try std.testing.expectEqual(BoardDirection.north_east.opposite(), BoardDirection.south_west);
        try std.testing.expectEqual(BoardDirection.north_west.opposite(), BoardDirection.south_east);
        try std.testing.expectEqual(BoardDirection.south_east.opposite(), BoardDirection.north_west);
        try std.testing.expectEqual(BoardDirection.south_west.opposite(), BoardDirection.north_east);
    }

    test forward {
        try std.testing.expectEqual(BoardDirection.forward(.white), BoardDirection.north);
        try std.testing.expectEqual(BoardDirection.forward(.black), BoardDirection.south);
    }
};

/// A type that is indexed by `BoardDirection`
pub fn ByBoardDirection(comptime T: type) type {
    return std.EnumArray(BoardDirection, T);
}
