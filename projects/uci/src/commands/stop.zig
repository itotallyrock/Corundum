const std = @import("std");

pub const Stop = struct {
    pub fn parse(source: []const u8) !?Stop {
        if (std.ascii.eqlIgnoreCase(source, "stop")) {
            return Stop{};
        } else if (std.ascii.startsWithIgnoreCase(source, "stop")) {
            return error.InvalidStopCommand;
        }

        return null;
    }
};

test Stop {
    try std.testing.expectEqualDeep(Stop{}, Stop.parse("stop"));
    try std.testing.expectEqualDeep(Stop{}, Stop.parse("STOP"));
    try std.testing.expectEqual(null, Stop.parse("not a stop command"));
    try std.testing.expectError(error.InvalidStopCommand, Stop.parse("stop invalid"));
}
