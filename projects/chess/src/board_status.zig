
const std = @import("std");
const Player = @import("./player.zig").Player;
const CastleAbilities = @import("./castle.zig").CastleAbilities;
const File = @import("./square.zig").File;

/// Represents the status of the current board (used for comptime specific board functions).
pub const BoardStatus = packed struct {
    /// The player who is currently to move.
    side_to_move: Player,
    /// The castling abilities of the current position.
    castle_abilities: CastleAbilities,
    /// The en passant square, if any.
    en_passant_file: ?File,
};