const std = @import("std");

pub const Register = union(enum) {
    later: struct {},
    user: struct {
        name: ?[]const u8 = null,
        code: ?[]const u8 = null,
    },

    pub fn parse(source: []const u8) !?Register {
        if (std.ascii.startsWithIgnoreCase(source, "register")) {
            const command = std.mem.trimLeft(u8, source[8..], " ");
            if (std.ascii.eqlIgnoreCase(command, "later")) {
                return Register{ .later = .{} };
            }

            const name_prefix_index = std.ascii.indexOfIgnoreCase(command, "name");
            const code_prefix_index = std.ascii.indexOfIgnoreCase(command, "code");

            const name, const code = if (name_prefix_index) |name_index|
                if (code_prefix_index) |code_index|
                    // Name and code
                    if (name_index > code_index)
                        // Code before name
                        .{ std.mem.trim(u8, command[name_index + 4 ..], " "), std.mem.trim(u8, command[code_index + 4 .. name_index], " ") }
                    else
                        .{ std.mem.trim(u8, command[name_index + 4 .. code_index], " "), std.mem.trim(u8, command[code_index + 4 ..], " ") }
                else
                    // Name only
                    .{ std.mem.trim(u8, command[name_index + 4 ..], " "), null }
            else if (code_prefix_index) |code_index|
                // Code only
                .{ null, std.mem.trim(u8, command[code_index + 4 ..], " ") }
            else
                return error.InvalidRegisterCommand;

            return Register{ .user = .{ .name = name, .code = code } };
        }

        return null;
    }
};

test Register {
    try std.testing.expectEqualDeep(Register{ .later = .{} }, Register.parse("register later"));
    try std.testing.expectEqualDeep(Register{ .later = .{} }, Register.parse("REGISTER LATER"));
    try std.testing.expectEqual(null, Register.parse("not a register command"));
    try std.testing.expectError(error.InvalidRegisterCommand, Register.parse("register invalid"));
    try std.testing.expectEqualDeep(Register{ .user = .{ .name = "Steve Vai", .code = "12345" } }, Register.parse("register name Steve Vai code 12345"));
    try std.testing.expectEqualDeep(Register{ .user = .{ .name = "Bob", .code = "Password" } }, Register.parse("register code Password NAME Bob"));
    try std.testing.expectEqualDeep(Register{ .user = .{ .name = "Stephen" } }, Register.parse("register name Stephen"));
    try std.testing.expectEqualDeep(Register{ .user = .{ .code = "9001" } }, Register.parse("register code 9001"));
}
