const std = @import("std");

pub const Player = enum {
    White,
    Black,

    pub fn opposite(self: Player) Player {
        return if (self == .White) .Black else .White;
    }
};

pub fn ByPlayer(comptime T: type) type {
    return std.EnumArray(Player, T);
}
