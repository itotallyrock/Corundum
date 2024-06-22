const std = @import("std");
const Player = @import("players.zig").Player;

/// Represents an absolute direction on the board (always from white's perspective).
pub const Direction = enum(i5) {
    north = 8,
    south = -8,
    east = 1,
    west = -1,
    north_east = 9,
    north_west = 7,
    south_east = -7,
    south_west = -9,

    /// Returns the direction that is the opposite of this one.
    pub fn opposite(self: Direction) Direction {
        return @enumFromInt(-@intFromEnum(self));
    }

    /// Returns north or south depending on the player.
    pub fn forward(player: Player) Direction {
        switch (player) {
            .white => return .north,
            .black => return .south,
        }
    }

    test opposite {
        try std.testing.expectEqual(Direction.north.opposite(), Direction.south);
        try std.testing.expectEqual(Direction.south.opposite(), Direction.north);
        try std.testing.expectEqual(Direction.east.opposite(), Direction.west);
        try std.testing.expectEqual(Direction.west.opposite(), Direction.east);
        try std.testing.expectEqual(Direction.north_east.opposite(), Direction.south_west);
        try std.testing.expectEqual(Direction.north_west.opposite(), Direction.south_east);
        try std.testing.expectEqual(Direction.south_east.opposite(), Direction.north_west);
        try std.testing.expectEqual(Direction.south_west.opposite(), Direction.north_east);
    }

    test forward {
        try std.testing.expectEqual(Direction.forward(.white), Direction.north);
        try std.testing.expectEqual(Direction.forward(.black), Direction.south);
    }
};

/// A type that is indexed by `Direction`
pub fn ByDirection(comptime T: type) type {
    return std.EnumArray(Direction, T);
}
