const std = @import("std");

/// A response to the `uci` command indicating that we've reported our identification and all options
pub const UciOk = struct {
    /// Integrate with zig formatting api using `{f}` to write this command
    pub fn format(_: *const UciOk, w: *std.Io.Writer) std.Io.Writer.Error!void {
        std.debug.assert(try w.write("uciok") == 5);
    }

    test format {
        var buffer: [32]u8 = undefined;
        var stream = std.Io.fixedBufferStream(&buffer);
        var w = stream.writer();
        try w.print("{f}", .{UciOk{}});
        try std.testing.expectEqualStrings("uciok", stream.getWritten());
    }
};

test {
    std.testing.refAllDecls(@This());
}
