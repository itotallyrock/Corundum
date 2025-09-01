const std = @import("std");

pub const Uci = struct {
    pub fn parse(source: []const u8) !?Uci {
        if (std.ascii.eqlIgnoreCase(source, "uci")) {
            return Uci{};
        }

        if (std.ascii.startsWithIgnoreCase(source, "uci ")) {
            return error.InvalidUciCommand;
        }

        return null;
    }
};

test Uci {
    try std.testing.expectEqualDeep(Uci{}, Uci.parse("uci"));
    try std.testing.expectEqualDeep(Uci{}, Uci.parse("UCI"));
    try std.testing.expectEqual(null, Uci.parse("not a uci command"));
    try std.testing.expectError(error.InvalidUciCommand, Uci.parse("uci invalid"));
}
