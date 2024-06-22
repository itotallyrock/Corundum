const std = @import("std");
const Player = @import("players.zig").Player;
const ByPlayer = @import("players.zig").ByPlayer;

/// Represents the direction of a castle move.
pub const CastleDirection = enum {
    /// The king-side castle direction.
    king_side,
    /// The queen-side castle direction.
    queen_side,
};

/// A type that maps `T` for each `CastleDirection`.
pub fn ByCastleDirection(comptime T: type) type {
    return std.EnumArray(CastleDirection, T);
}

/// Represents the rights to castle for each player and direction.
pub const CastleRights = struct {
    /// All possible castle rights.
    pub const all = CastleRights.init(ByPlayer(ByCastleDirection(bool)).initFill(ByCastleDirection(bool).initFill(true)));
    /// No castle rights.
    pub const none = CastleRights.init(ByPlayer(ByCastleDirection(bool)).initFill(ByCastleDirection(bool).initFill(false)));
    /// All rights for white.
    pub const white_all = CastleRights.none.add_right(.white, .king_side).add_right(.white, .queen_side);
    /// All rights for black.
    pub const black_all = CastleRights.none.add_right(.black, .king_side).add_right(.black, .queen_side);
    /// All rights for white on the king side.
    pub const white_king_side = CastleRights.none.add_right(.white, .king_side);
    /// All rights for white on the queen side.
    pub const white_queen_side = CastleRights.none.add_right(.white, .queen_side);
    /// All rights for black on the king side.
    pub const black_king_side = CastleRights.none.add_right(.black, .king_side);
    /// All rights for black on the queen side.
    pub const black_queen_side = CastleRights.none.add_right(.black, .queen_side);

    /// The underlying rights flags for each player and direction.
    rights: ByPlayer(ByCastleDirection(bool)),

    /// Get all rights for a given player.
    pub fn forSide(comptime player: Player) CastleRights {
        return if (player == .white) CastleRights.white_all else CastleRights.black_all;
    }

    /// Initialize the castle rights with the given rights.
    pub fn init(rights: ByPlayer(ByCastleDirection(bool))) CastleRights {
        return CastleRights{ .rights = rights };
    }

    /// Initialize the castle rights with the given rights flag to apply for all players and directions.
    pub fn initFill(allRights: bool) CastleRights {
        return CastleRights{
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
        return self.remove_right(player, .king_side).remove_right(player, .queen_side);
    }

    /// Remove the rights for a specific castle direction based on which rook moved and return it.
    pub fn rook_move(self: CastleRights, comptime player: Player, comptime direction: CastleDirection) CastleRights {
        return self.remove_right(player, direction);
    }

    /// Get the UCI string representation of the castle rights.
    /// i.e. "KQkq" for all rights, "KQk" for all rights except black queen side, etc.
    pub fn get_uci_string(self: CastleRights) []const u8 {
        if (self.has_rights(.white, .king_side) and self.has_rights(.white, .queen_side) and self.has_rights(.black, .king_side) and self.has_rights(.black, .queen_side)) {
            return "KQkq";
        }
        if (self.has_rights(.white, .king_side) and self.has_rights(.white, .queen_side) and self.has_rights(.black, .king_side) and !self.has_rights(.black, .queen_side)) {
            return "KQk";
        }
        if (self.has_rights(.white, .king_side) and self.has_rights(.white, .queen_side) and !self.has_rights(.black, .king_side) and self.has_rights(.black, .queen_side)) {
            return "KQq";
        }
        if (self.has_rights(.white, .king_side) and self.has_rights(.white, .queen_side) and !self.has_rights(.black, .king_side) and !self.has_rights(.black, .queen_side)) {
            return "KQ";
        }
        if (self.has_rights(.white, .king_side) and !self.has_rights(.white, .queen_side) and self.has_rights(.black, .king_side) and self.has_rights(.black, .queen_side)) {
            return "Kkq";
        }
        if (self.has_rights(.white, .king_side) and !self.has_rights(.white, .queen_side) and self.has_rights(.black, .king_side) and !self.has_rights(.black, .queen_side)) {
            return "Kk";
        }
        if (self.has_rights(.white, .king_side) and !self.has_rights(.white, .queen_side) and !self.has_rights(.black, .king_side) and self.has_rights(.black, .queen_side)) {
            return "Kq";
        }
        if (self.has_rights(.white, .king_side) and !self.has_rights(.white, .queen_side) and !self.has_rights(.black, .king_side) and !self.has_rights(.black, .queen_side)) {
            return "K";
        }
        if (!self.has_rights(.white, .king_side) and self.has_rights(.white, .queen_side) and self.has_rights(.black, .king_side) and self.has_rights(.black, .queen_side)) {
            return "Qkq";
        }
        if (!self.has_rights(.white, .king_side) and self.has_rights(.white, .queen_side) and self.has_rights(.black, .king_side) and !self.has_rights(.black, .queen_side)) {
            return "Qk";
        }
        if (!self.has_rights(.white, .king_side) and self.has_rights(.white, .queen_side) and !self.has_rights(.black, .king_side) and self.has_rights(.black, .queen_side)) {
            return "Qq";
        }
        if (!self.has_rights(.white, .king_side) and self.has_rights(.white, .queen_side) and !self.has_rights(.black, .king_side) and !self.has_rights(.black, .queen_side)) {
            return "Q";
        }
        if (!self.has_rights(.white, .king_side) and !self.has_rights(.white, .queen_side) and self.has_rights(.black, .king_side) and self.has_rights(.black, .queen_side)) {
            return "kq";
        }
        if (!self.has_rights(.white, .king_side) and !self.has_rights(.white, .queen_side) and self.has_rights(.black, .king_side) and !self.has_rights(.black, .queen_side)) {
            return "k";
        }
        if (!self.has_rights(.white, .king_side) and !self.has_rights(.white, .queen_side) and !self.has_rights(.black, .king_side) and self.has_rights(.black, .queen_side)) {
            return "q";
        }
        return "-";
    }
};
