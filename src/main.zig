//! TODO

const std = @import("std");
const UciEngineManager = @import("./root.zig").UciEngineManager;
const max_command_length = @import("corundum_build_options").max_command_length;
const response_buffer_size = 64;

/// TODO
pub fn main() !void {
    var stdin_file = std.fs.File.stdin();
    defer stdin_file.close();
    var stdout_file = std.fs.File.stdout();
    defer stdout_file.close();

    var stdin_buffer: [max_command_length]u8 = undefined;
    var stdout_buffer: [response_buffer_size]u8 = undefined;

    var stdin_reader = stdin_file.reader(&stdin_buffer);
    var stdout_writer = stdout_file.writer(&stdout_buffer);

    var root_buffer: [8 * 1024 * 1024]u8 = undefined;
    var root_allocator = std.heap.FixedBufferAllocator.init(&root_buffer);

    var uci_engine_manager = UciEngineManager.init(&stdin_reader.interface, &stdout_writer.interface, root_allocator.allocator());
    try uci_engine_manager.run();
}

test {
    std.testing.refAllDecls(@This());
}
