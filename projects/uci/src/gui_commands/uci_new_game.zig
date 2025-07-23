const std = @import("std");

pub const UciNewGame = struct {
    pub fn parse(source: []const u8) !?UciNewGame {
        if (std.ascii.eqlIgnoreCase(source, "ucinewgame")) {
            return UciNewGame{};
        } else if (std.ascii.startsWithIgnoreCase(source, "ucinewgame")) {
            return error.InvalidUciNewGameCommand;
        }

        return null;
    }
};

test UciNewGame {
    try std.testing.expectEqualDeep(UciNewGame{}, UciNewGame.parse("ucinewgame"));
    try std.testing.expectEqualDeep(UciNewGame{}, UciNewGame.parse("UCINEWGAME"));
    try std.testing.expectEqual(null, UciNewGame.parse("not a ucinewgame command"));
    try std.testing.expectError(error.InvalidUciNewGameCommand, UciNewGame.parse("ucinewgame invalid"));
}
