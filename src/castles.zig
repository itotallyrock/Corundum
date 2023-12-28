const std = @import("std");
const Player = @import("players.zig").Player;

pub const CastleDirection = enum {
    KingSide,
    QueenSide,
};

pub const CastleRights = std.EnumArray(Player, std.EnumArray(CastleDirection, bool));