const std = @import("std");

/// A an owner of pieces with a turn to move.
pub const Player = enum {
    /// The player with the white pieces, typically first to move
    white,
    /// The player with the black pieces, typically second to move
    black,

    /// Get the opposite player
    pub fn opposite(self: Player) Player {
        return if (self == .white) .black else .white;
    }

    test opposite {
        try std.testing.expectEqual(Player.white.opposite(), .black);
        try std.testing.expectEqual(Player.black.opposite(), .white);
    }
};

/// A type that is indexed by player
pub fn ByPlayer(comptime T: type) type {
    return std.EnumArray(Player, T);
}

test ByPlayer {
    const playerMasks = ByPlayer(bool).initFill(true);
    try std.testing.expect(playerMasks.get(.white) and playerMasks.get(.black));
}
