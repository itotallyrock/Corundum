//! TODO

const std = @import("std");
const UciEngineManager = @import("./root.zig").UciEngineManager;

/// TODO
pub fn main() !void {
    var stdin_stream = std.io.getStdIn();
    var stdin = std.io.bufferedReader(stdin_stream.reader());
    var stdout_stream = std.io.getStdOut();
    var stdout = std.io.bufferedWriter(stdout_stream.writer());
    var root_buffer: [8 * 1024 * 1024]u8 = undefined;
    var root_allocator = std.heap.FixedBufferAllocator.init(&root_buffer);

    var uci_engine_manager = UciEngineManager.init(stdin.reader().any(), stdout.writer().any(), root_allocator.allocator());
    try uci_engine_manager.run();
}

