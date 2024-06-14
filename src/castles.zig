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