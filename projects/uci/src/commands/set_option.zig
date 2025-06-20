const std = @import("std");

pub const StartingSetOption = union(enum) {
    startpos,
    fen: []const u8,

    pub fn parse(source: []const u8) !StartingSetOption {
        if (std.ascii.eqlIgnoreCase(source, "startpos")) {
            return .{ .startpos = {} };
        } else if (std.ascii.startsWithIgnoreCase(source, "fen ")) {
            const fen_part = std.mem.trim(u8, source[4..], " ");
            // TODO: validate FEN format?
            return .{ .fen = fen_part };
        }

        return error.InvalidSetOptionInSetOptionCommand;
    }
};

pub const SetOption = struct {
    const Self = @This();

    name: []const u8,
    value: ?[]const u8,

    pub fn parse(source: []const u8) !?Self {
        if (std.ascii.startsWithIgnoreCase(source, "setoption")) {
            const remaining_command = std.mem.trim(u8, source[9..], " ");
            if (!std.ascii.startsWithIgnoreCase(remaining_command, "name ")) return error.InvalidSetOptionMissingName;
            const unprefixed_name_and_possible_value = std.mem.trimLeft(u8, remaining_command[5..], " ");

            const value_index = std.ascii.indexOfIgnoreCase(unprefixed_name_and_possible_value, " value ");
            const name, const value = if (value_index) |index| .{ unprefixed_name_and_possible_value[0..index], unprefixed_name_and_possible_value[index + 7..] } else .{ unprefixed_name_and_possible_value, null };
            if (name.len == 0 or std.ascii.eqlIgnoreCase(name, "value")) return error.InvalidSetOptionMissingName;

            return Self{
                .name = name,
                .value = value,
            };
        }
        return null;
    }
};

test SetOption {
    try std.testing.expectEqualDeep(SetOption{ .name = "Threads", .value = "10" }, SetOption.parse("setoption name Threads value 10"));
    try std.testing.expectEqualDeep(SetOption{ .name = "Threads", .value = null }, SetOption.parse("SETOPTION name Threads"));
    try std.testing.expectEqualDeep(SetOption{ .name = "Nalimov Table Base Path", .value = "C:/Nalimov" }, SetOption.parse("SETOPTION NAME Nalimov Table Base Path VALUE C:/Nalimov"));
    try std.testing.expectEqualDeep(SetOption{ .name = "Use NNUE", .value = "TRUE" }, SetOption.parse("setoption     name   Use NNUE value TRUE"));
    try std.testing.expectError(error.InvalidSetOptionMissingName, SetOption.parse("setoption"));
    try std.testing.expectError(error.InvalidSetOptionMissingName, SetOption.parse("setoption name "));
    try std.testing.expectError(error.InvalidSetOptionMissingName, SetOption.parse("setoption name value"));
    try std.testing.expectError(error.InvalidSetOptionMissingName, SetOption.parse("setoption value 10"));

    try std.testing.expectEqual(null, SetOption.parse("not a setoption command"));
}
