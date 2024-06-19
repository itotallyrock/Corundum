const std = @import("std");
const Player = @import("players.zig").Player;
const ByPlayer = @import("players.zig").ByPlayer;

/// Represents the direction of a castle move.
pub const CastleDirection = enum {
    /// The king-side castle direction.
    KingSide,
    /// The queen-side castle direction.
    QueenSide,
};

/// A type that maps `T` for each `CastleDirection`.
pub fn ByCastleDirection(comptime T: type) type {
    return std.EnumArray(CastleDirection, T);
}

/// Represents the rights to castle for each player and direction.
pub const CastleRights = struct {
    /// All possible castle rights.
    pub const All = ByPlayer(ByCastleDirection(bool)).initFill(ByCastleDirection(bool).initFill(true));
    /// No castle rights.
    pub const None = ByPlayer(ByCastleDirection(bool)).initFill(ByCastleDirection(bool).initFill(false));
    /// All rights for white.
    pub const WhiteAll = CastleRights.All.remove_right(.Black, .KingSide).remove_right(.Black, .QueenSide);
    /// All rights for black.
    pub const BlackAll = CastleRights.All.remove_right(.White, .KingSide).remove_right(.White, .QueenSide);
    /// All rights for white on the king side.
    pub const WhiteKingSide = None.All.add_right(.Black, .QueenSide);
    /// All rights for white on the queen side.
    pub const WhiteQueenSide = None.All.add_right(.Black, .KingSide);
    /// All rights for black on the king side.
    pub const BlackKingSide = None.All.add_right(.White, .QueenSide);
    /// All rights for black on the queen side.
    pub const BlackQueenSide = None.All.add_right(.White, .KingSide);

    /// The underlying rights flags for each player and direction.
    rights: ByPlayer(ByCastleDirection(bool)),

    /// Get all rights for a given player.
    pub fn forSide(comptime player: Player) CastleRights {
        return if (player == .White) CastleRights.WhiteAll else CastleRights.BlackAll;
    }

    /// Initialize the castle rights with the given rights.
    pub fn init(rights: ByPlayer(ByCastleDirection(bool))) CastleRights {
        return CastleRights { .rights = rights };
    }

    /// Initialize the castle rights with the given rights flag to apply for all players and directions.
    pub fn initFill(allRights: bool) CastleRights {
        return CastleRights {
            .rights = ByPlayer(ByCastleDirection(bool)).initFill(ByCastleDirection(bool).initFill(allRights)),
        };
    }

    /// Check if a player has the rights to castle in a given direction.
    pub fn has_rights(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) bool {
        return self.rights.get(player).get(direction);
    }

    /// Remove the rights to castle in a given direction for a player and return it.
    pub fn remove_right(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) CastleRights {
        var result = self;
        result.rights.getPtr(player).set(direction, false);
        return result;
    }

    /// Add the rights to castle in a given direction for a player and return it.
    pub fn add_right(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) CastleRights {
        var result = self;
        result.rights.getPtr(player).set(direction, true);
        return result;
    }

    /// Remove all rights for a player and return it.
    pub fn king_move(self: CastleRights, comptime player: Player) CastleRights {
        return self.remove_right(player, .KingSide).remove_right(player, .QueenSide);
    }

    /// Remove the rights for a specific castle direction based on which rook moved and return it.
    pub fn rook_move(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) CastleRights {
        return self.remove_right(player, direction);
    }

    /// Get the UCI string representation of the castle rights.
    /// i.e. "KQkq" for all rights, "KQk" for all rights except black queen side, etc.
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
