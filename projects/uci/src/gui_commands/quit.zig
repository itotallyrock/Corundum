const std = @import("std");

pub const Quit = struct {
    pub fn parse(source: []const u8) !?Quit {
        if (std.ascii.eqlIgnoreCase(source, "quit")) {
            return Quit{};
        } else if (std.ascii.startsWithIgnoreCase(source, "quit")) {
            return error.InvalidQuitCommand;
        }

        return null;
    }
};

test Quit {
    try std.testing.expectEqualDeep(Quit{}, Quit.parse("quit"));
    try std.testing.expectEqualDeep(Quit{}, Quit.parse("QUIT"));
    try std.testing.expectEqual(null, Quit.parse("not a quit command"));
    try std.testing.expectError(error.InvalidQuitCommand, Quit.parse("quit invalid"));
}
