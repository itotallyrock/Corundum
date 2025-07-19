//! TODO

const std = @import("std");
const UciEngineManager = @import("./root.zig").UciEngineManager;

const maximum_command_length = 4096;
const maximum_response_length = 4096;

/// TODO
pub fn main() !void {
    var stdin_file = std.fs.File.stdin();
    defer stdin_file.close();
    var stdout_file = std.fs.File.stdout();
    defer stdout_file.close();

    var stdin_buffer: [maximum_command_length]u8 = undefined;
    var stdout_buffer: [maximum_response_length]u8 = undefined;

    const stdin_reader = stdin_file.reader(&stdin_buffer);
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    defer stdout_writer.interface.flush() catch {};

    var root_buffer: [8 * 1024 * 1024]u8 = undefined;
    var root_allocator = std.heap.FixedBufferAllocator.init(&root_buffer);

    var uci_engine_manager = UciEngineManager.init(stdin_reader.interface, stdout_writer.interface, root_allocator.allocator());
    try uci_engine_manager.run();
}

test {
    std.testing.refAllDecls(@This());
}
