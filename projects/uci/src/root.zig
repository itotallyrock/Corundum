//! TODO: document this file

const std = @import("std");

pub const AnyGuiCommand = @import("./gui_commands/any.zig").AnyGuiCommand;

test {
    std.testing.refAllDeclsRecursive(@This());
}
