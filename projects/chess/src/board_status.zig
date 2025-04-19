
const std = @import("std");
const Player = @import("./player.zig").Player;
const CastleAbilities = @import("./castle.zig").CastleAbilities;
const File = @import("./square.zig").File;

/// Represents an optional file. This is used for the en passant square, which can be null if there is no en passant square.
/// We can't use Optional because we need to store the file in a packed struct.
pub const OptionalFile = packed struct {
    has_value: bool,
    _file: File,

    pub fn initNull() OptionalFile {
        return OptionalFile{
            .has_value = false,
            ._file = File.a,
        };
    }

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
        const test1 = OptionalFile.initNull();
        try std.testing.expectEqual(null, test1.inner());
        const test2 = OptionalFile.init(.a);
        try std.testing.expectEqual(test2.inner().?, .a);
    }
};

/// Represents the status of the current board (used for comptime specific board functions).
pub const BoardStatus = packed struct {
    /// The player who is currently to move.
    side_to_move: Player,
    /// The castling abilities of the current position.
    castle_abilities: CastleAbilities,
    /// The en passant square, if any.
    en_passant_file: OptionalFile,
};