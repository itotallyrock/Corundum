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
};

/// A type that is indexed by player
///
/// ```zig
/// const std = @import("std");
/// const Bitboard = @import("bitboard.zig").Bitboard;
/// const ByPlayer = @import("players.zig").ByPlayer;
/// const playerMasks = ByPlayer(Bitboard).initFill(Bitboard.Empty);
/// std.testing.assert(playerMasks.get(.White).isEmpty() && playerMasks.get(.Black).isEmpty());
/// ```
pub fn ByPlayer(comptime T: type) type {
    return std.EnumArray(Player, T);
}
