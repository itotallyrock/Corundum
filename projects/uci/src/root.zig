//! TODO: document this file

const std = @import("std");

pub const AnyUciCommand = @import("./commands/any.zig").AnyUciCommand;

test {
    std.testing.refAllDeclsRecursive(@This());
}
