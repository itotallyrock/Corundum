const std = @import("std");

pub const PonderHit = struct {
    pub fn parse(source: []const u8) !?PonderHit {
        if (std.ascii.eqlIgnoreCase(source, "ponderhit")) {
            return PonderHit{};
        } else if (std.ascii.startsWithIgnoreCase(source, "ponderhit")) {
            return error.InvalidPonderHitCommand;
        }

        return null;
    }
};

test PonderHit {
    try std.testing.expectEqualDeep(PonderHit{}, PonderHit.parse("ponderhit"));
    try std.testing.expectEqualDeep(PonderHit{}, PonderHit.parse("PONDERHIT"));
    try std.testing.expectEqual(null, PonderHit.parse("not a ponderhit command"));
    try std.testing.expectError(error.InvalidPonderHitCommand, PonderHit.parse("ponderhit invalid"));
}
