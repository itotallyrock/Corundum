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
    pub const All = ByPlayer(ByCastleDirection(bool)).initFill(ByCastleDirection(bool).initFill(true));
    pub const None = ByPlayer(ByCastleDirection(bool)).initFill(ByCastleDirection(bool).initFill(false));
    pub const WhiteAll = CastleRights.All.remove_right(.Black, .KingSide).remove_right(.Black, .QueenSide);
    pub const BlackAll = CastleRights.All.remove_right(.White, .KingSide).remove_right(.White, .QueenSide);
    pub const WhiteKingSide = None.All.add_right(.Black, .QueenSide);
    pub const WhiteQueenSide = None.All.add_right(.Black, .KingSide);
    pub const BlackKingSide = None.All.add_right(.White, .QueenSide);
    pub const BlackQueenSide = None.All.add_right(.White, .KingSide);

    rights: ByPlayer(ByCastleDirection(bool)),

    pub fn forSide(comptime player: Player) CastleRights {
        return if (player == .White) CastleRights.WhiteAll else CastleRights.BlackAll;
    }

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

    pub fn remove_right(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) CastleRights {
        var result = self;
        result.rights.getPtr(player).set(direction, false);
        return result;
    }

    pub fn add_right(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) CastleRights {
        var result = self;
        result.rights.getPtr(player).set(direction, true);
        return result;
    }

    pub fn king_move(self: CastleRights, comptime player: Player) CastleRights {
        return self.remove_right(player, .KingSide).remove_right(player, .QueenSide);
    }

    pub fn rook_move(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) CastleRights {
        return self.remove_right(player, direction);
    }

    pub fn get_uci_string(self: CastleRights) []const u8 {
        if (self.has_rights(.White, .KingSide) and self.has_rights(.White, .QueenSide) and self.has_rights(.Black, .KingSide) and self.has_rights(.Black, .QueenSide)) {
            return "KQkq";
        }
        if (self.has_rights(.White, .KingSide) and self.has_rights(.White, .QueenSide) and self.has_rights(.Black, .KingSide) and !self.has_rights(.Black, .QueenSide)) {
            return "KQk";
        }
        if (self.has_rights(.White, .KingSide) and self.has_rights(.White, .QueenSide) and !self.has_rights(.Black, .KingSide) and self.has_rights(.Black, .QueenSide)) {
            return "KQq";
        }
        if (self.has_rights(.White, .KingSide) and self.has_rights(.White, .QueenSide) and !self.has_rights(.Black, .KingSide) and !self.has_rights(.Black, .QueenSide)) {
            return "KQ";
        }
        if (self.has_rights(.White, .KingSide) and !self.has_rights(.White, .QueenSide) and self.has_rights(.Black, .KingSide) and self.has_rights(.Black, .QueenSide)) {
            return "Kkq";
        }
        if (self.has_rights(.White, .KingSide) and !self.has_rights(.White, .QueenSide) and self.has_rights(.Black, .KingSide) and !self.has_rights(.Black, .QueenSide)) {
            return "Kk";
        }
        if (self.has_rights(.White, .KingSide) and !self.has_rights(.White, .QueenSide) and !self.has_rights(.Black, .KingSide) and self.has_rights(.Black, .QueenSide)) {
            return "Kq";
        }
        if (self.has_rights(.White, .KingSide) and !self.has_rights(.White, .QueenSide) and !self.has_rights(.Black, .KingSide) and !self.has_rights(.Black, .QueenSide)) {
            return "K";
        }
        if (!self.has_rights(.White, .KingSide) and self.has_rights(.White, .QueenSide) and self.has_rights(.Black, .KingSide) and self.has_rights(.Black, .QueenSide)) {
            return "Qkq";
        }
        if (!self.has_rights(.White, .KingSide) and self.has_rights(.White, .QueenSide) and self.has_rights(.Black, .KingSide) and !self.has_rights(.Black, .QueenSide)) {
            return "Qk";
        }
        if (!self.has_rights(.White, .KingSide) and self.has_rights(.White, .QueenSide) and !self.has_rights(.Black, .KingSide) and self.has_rights(.Black, .QueenSide)) {
            return "Qq";
        }
        if (!self.has_rights(.White, .KingSide) and self.has_rights(.White, .QueenSide) and !self.has_rights(.Black, .KingSide) and !self.has_rights(.Black, .QueenSide)) {
            return "Q";
        }
        if (!self.has_rights(.White, .KingSide) and !self.has_rights(.White, .QueenSide) and self.has_rights(.Black, .KingSide) and self.has_rights(.Black, .QueenSide)) {
            return "kq";
        }
        if (!self.has_rights(.White, .KingSide) and !self.has_rights(.White, .QueenSide) and self.has_rights(.Black, .KingSide) and !self.has_rights(.Black, .QueenSide)) {
            return "k";
        }
        if (!self.has_rights(.White, .KingSide) and !self.has_rights(.White, .QueenSide) and !self.has_rights(.Black, .KingSide) and self.has_rights(.Black, .QueenSide)) {
            return "q";
        }
        return "-";
    }
};