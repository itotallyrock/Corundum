const std = @import("std");

const IdType = enum {
    name,
    author,
};

/// A response to the `uci` command indicating the name of the engine
pub const Id = union(IdType) {
    /// The name of the engine
    name: []const u8,
    /// The author of the engine
    author: []const u8,

    /// Integrate with zig formatting api using `{f}` to write this command
    pub fn format(self: *const Id, w: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self.*) {
            .name => |name| try w.print("id name {s}", .{name}),
            .author => |author| try w.print("id author {s}", .{author}),
        }
    }

    test format {
        var buffer: [64]u8 = undefined;
        var stream = std.Io.fixedBufferStream(&buffer);
        var w = stream.writer();
        try w.print("{f}\n", .{Id{ .name = "Corundum 0.420.69" }});
        try w.print("{f}\n", .{Id{ .author = "itotallyrock" }});
        try std.testing.expectEqualStrings("id name Corundum 0.420.69\nid author itotallyrock\n", stream.getWritten());
    }
};

test {
    std.testing.refAllDecls(@This());
}
