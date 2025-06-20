const std = @import("std");

pub fn parseOnOff(source: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(source, "on")) {
        return true;
    } else if (std.ascii.eqlIgnoreCase(source, "off")) {
        return false;
    }
    return null;
}

pub const Debug = struct {
    const Self = @This();
    enabled: bool = false,

    pub fn parse(source: []const u8) !?Debug {
        if (std.ascii.startsWithIgnoreCase(source, "debug")) {
            const command = std.mem.trimLeft(u8, source[5..], " ");
            return Self{
                .enabled = parseOnOff(command) orelse return error.InvalidDebugCommand,
            };
        }
        return null;
    }
};

test Debug {
    try std.testing.expectEqualDeep(Debug{ .enabled = true }, Debug.parse("debug on"));
    try std.testing.expectEqualDeep(Debug{ .enabled = true }, Debug.parse("DEBUG ON"));
    try std.testing.expectEqualDeep(Debug{ .enabled = false }, Debug.parse("debug off"));
    try std.testing.expectEqualDeep(Debug{ .enabled = false }, Debug.parse("DEBUG OFF"));
    try std.testing.expectError(error.InvalidDebugCommand, Debug.parse("debug invalid"));
    try std.testing.expectError(error.InvalidDebugCommand, Debug.parse("debug"));
    try std.testing.expectEqual(null, Debug.parse("not a debug command"));
}
