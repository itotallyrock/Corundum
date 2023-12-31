const std = @import("std");
const Player = @import("players.zig").Player;
const ByPlayer = @import("players.zig").ByPlayer;

pub const CastleDirection = enum {
    KingSide,
    QueenSide,
};

pub fn ByCastleDirection(comptime T: type) type {
    return std.EnumArray(CastleDirection, T);
}

pub const CastleRights = struct {
    rights: ByPlayer(ByCastleDirection(bool)),

    pub fn init(rights: ByPlayer(ByCastleDirection(bool))) CastleRights {
        return CastleRights { .rights = rights };
    }

    pub fn initFill(allRights: bool) CastleRights {
        return CastleRights {
            .rights = ByPlayer(ByCastleDirection(bool)).initFill(ByCastleDirection(bool).initFill(allRights)),
        };
    }

    pub fn has_rights(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) bool {
        return self.rights.get(player).get(direction);
    }
};