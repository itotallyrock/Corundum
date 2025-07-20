const std = @import("std");

pub const score = @import("./score.zig");

test {
    std.testing.refAllDecls(@This());
}
