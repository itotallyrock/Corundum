const std = @import("std");

const CastleAbilities = @import("./castle.zig").CastleAbilities;
const CastleDirection = @import("./castle.zig").CastleDirection;
const Player = @import("./player.zig").Player;
const File = @import("./square.zig").File;

/// Represents the status of the current board (used for comptime specific board functions).
pub const BoardStatus = packed struct {
    const Self = @This();
    /// The player who is currently to move.
    side_to_move: Player,
    /// The castling abilities of the current position.
    castle_abilities: CastleAbilities,
    /// Whether there is an en passant square the current player can capture on.
    has_en_passant: bool,

    pub fn init(
        side_to_move: Player,
        castle_abilities: CastleAbilities,
        has_en_passant: bool,
    ) BoardStatus {
        return Self{
            .side_to_move = side_to_move,
            .castle_abilities = castle_abilities,
            .has_en_passant = has_en_passant,
        };
    }

    pub fn kingMove(self: Self) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            .castle_abilities = self.castle_abilities.kingMove(self.side_to_move),
            .has_en_passant = false,
        };
    }

    pub fn rookMove(self: Self, castle_direction: CastleDirection) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            .castle_abilities = self.castle_abilities.rookMove(self.side_to_move, castle_direction),
            .has_en_passant = false,
        };
    }

    pub fn rookCapture(self: Self, castle_direction: CastleDirection) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            .castle_abilities = self.castle_abilities.rookMove(self.side_to_move.opposite(), castle_direction),
            .has_en_passant = false,
        };
    }

    pub fn doublePawnMove(self: Self) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            .castle_abilities = self.castle_abilities,
            .has_en_passant = true,
        };
    }

    pub fn quietMove(self: Self) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            .castle_abilities = self.castle_abilities,
            .has_en_passant = false,
        };
    }
};
