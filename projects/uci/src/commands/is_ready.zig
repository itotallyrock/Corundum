const std = @import("std");

pub const IsReady = struct {
    pub fn parse(source: []const u8) !?IsReady {
        if (std.ascii.eqlIgnoreCase(source, "isready")) {
            return IsReady{};
        } else if (std.ascii.startsWithIgnoreCase(source, "isready")) {
            return error.InvalidIsReadyCommand;
        }

        return null;
    }
};

test IsReady {
    try std.testing.expectEqualDeep(IsReady{}, IsReady.parse("isready"));
    try std.testing.expectEqualDeep(IsReady{}, IsReady.parse("ISREADY"));
    try std.testing.expectEqual(null, IsReady.parse("not a isready command"));
    try std.testing.expectError(error.InvalidIsReadyCommand, IsReady.parse("isready invalid"));
}
