const std = @import("std");

const CastleAbilities = @import("./castle.zig").CastleAbilities;
const CastleDirection = @import("./castle.zig").CastleDirection;
const Player = @import("./player.zig").Player;
const File = @import("./square.zig").File;

/// Represents an optional file. This is used for the en passant square, which can be null if there is no en passant square.
/// We can't use Optional because we need to store the file in a packed struct.
pub const OptionalFile = packed struct {
    has_value: bool,
    _file: File,

    pub const none = OptionalFile{
        .has_value = false,
        ._file = File.a,
    };

    pub fn init(f: File) OptionalFile {
        return OptionalFile{
            .has_value = true,
            ._file = f,
        };
    }

    pub fn inner(self: OptionalFile) ?File {
        if (self.has_value) {
            return self._file;
        } else {
            return null;
        }
    }

    test inner {
        const test1 = OptionalFile.none;
        try std.testing.expectEqual(null, test1.inner());
        const test2 = OptionalFile.init(.a);
        try std.testing.expectEqual(test2.inner().?, .a);
    }
};

/// Represents the status of the current board (used for comptime specific board functions).
pub const BoardStatus = packed struct {
    const Self = @This();
    /// The player who is currently to move.
    side_to_move: Player,
    /// The castling abilities of the current position.
    castle_abilities: CastleAbilities,
    /// The en passant square, if any.
    en_passant_file: OptionalFile,

    pub fn init(
        side_to_move: Player,
        castle_abilities: CastleAbilities,
        en_passant_file: OptionalFile,
    ) BoardStatus {
        return Self{
            .side_to_move = side_to_move,
            .castle_abilities = castle_abilities,
            .en_passant_file = en_passant_file,
        };
    }

    pub fn kingMove(self: Self) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            // TODO: Consider checking for existing rights before removing or debug assert
            .castle_abilities = self.castle_abilities.kingMove(self.side_to_move),
            .en_passant_file = OptionalFile.none,
        };
    }

    pub fn rookMove(self: Self, castle_direction: CastleDirection) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            // TODO: Consider checking for existing rights before removing or debug assert
            .castle_abilities = self.castle_abilities.rookMove(self.side_to_move, castle_direction),
            .en_passant_file = OptionalFile.none,
        };
    }

    pub fn rookCapture(self: Self, castle_direction: CastleDirection) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            // TODO: Consider checking for existing rights before removing or debug assert
            .castle_abilities = self.castle_abilities.rookMove(self.side_to_move.opposite(), castle_direction),
            .en_passant_file = OptionalFile.none,
        };
    }

    pub fn doublePawnMove(self: Self, file: File) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            .castle_abilities = self.castle_abilities,
            .en_passant_file = OptionalFile.init(file),
        };
    }

    pub fn quietMove(self: Self) Self {
        return Self{
            .side_to_move = self.side_to_move.opposite(),
            .castle_abilities = self.castle_abilities,
            .en_passant_file = OptionalFile.none,
        };
    }
};
