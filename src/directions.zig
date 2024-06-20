const std = @import("std");
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

    test opposite {
        try std.testing.expectEqual(Direction.North.opposite(), Direction.South);
        try std.testing.expectEqual(Direction.South.opposite(), Direction.North);
        try std.testing.expectEqual(Direction.East.opposite(), Direction.West);
        try std.testing.expectEqual(Direction.West.opposite(), Direction.East);
        try std.testing.expectEqual(Direction.NorthEast.opposite(), Direction.SouthWest);
        try std.testing.expectEqual(Direction.NorthWest.opposite(), Direction.SouthEast);
        try std.testing.expectEqual(Direction.SouthEast.opposite(), Direction.NorthWest);
        try std.testing.expectEqual(Direction.SouthWest.opposite(), Direction.NorthEast);
    }

    test forward {
        try std.testing.expectEqual(Direction.forward(.White), Direction.North);
        try std.testing.expectEqual(Direction.forward(.Black), Direction.South);
    }
};
