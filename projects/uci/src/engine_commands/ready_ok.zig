const std = @import("std");

/// A response to the `isready` command
pub const ReadyOk = struct {
    /// Integrate with zig formatting api using `{f}` to write this command
    pub fn format(_: *const ReadyOk, w: *std.Io.Writer) std.Io.Writer.Error!void {
        std.debug.assert(try w.write("readyok") == 7);
    }

    test format {
        var buffer: [32]u8 = undefined;
        var stream = std.Io.fixedBufferStream(&buffer);
        var w = stream.writer();
        try w.print("{f}", .{ReadyOk{}});
        try std.testing.expectEqualStrings("readyok", stream.getWritten());
    }
};

test {
    std.testing.refAllDecls(@This());
}
