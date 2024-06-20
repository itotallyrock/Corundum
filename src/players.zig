const std = @import("std");

/// A an owner of pieces with a turn to move.
pub const Player = enum {
    /// The player with the white pieces, typically first to move
    White,
    /// The player with the black pieces, typically second to move
    Black,

    /// Get the opposite player
    pub fn opposite(self: Player) Player {
        return if (self == .White) .Black else .White;
    }

    test opposite {
        try std.testing.expectEqual(Player.White.opposite(), .Black);
        try std.testing.expectEqual(Player.Black.opposite(), .White);
    }
};

/// A type that is indexed by player
pub fn ByPlayer(comptime T: type) type {
    return std.EnumArray(Player, T);
}

test ByPlayer {
    const playerMasks = ByPlayer(bool).initFill(true);
    try std.testing.expect(playerMasks.get(.White) and playerMasks.get(.Black));
}
