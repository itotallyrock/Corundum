//! TODO

const std = @import("std");
const UciEngineManager = @import("./root.zig").UciEngineManager;
const max_command_length = @import("corundum_build_options").max_command_length;
const response_buffer_size = 64;

// TODO: Setup clap, another similar library, or some custom argument parsing
// - Support certain UCI options that don't make sense to change at runtime or have very little benefit
//   - Move overhead (constant offset to assume each move should take even if we report the bestmove instantly (to account for I/O and network latency)
//   - Syzygy path (this is a huge directory of solved endgames and shouldn't change once set, so makes sense as an argument not a UCI option)
//   - TT Size or "Hash" (GUIs typically only send this once at startup, so it makes more sense to make an argument)
//   - Threads (GUIs typically only send this once at startup (and the user rarely updates this in the GUI) and furthermore once a search has started (or in other words, the thread pool has be initialized) changing the thread count complicates things.
//     - Lastly, we can default to the best value, the core count. It's rare the user doesn't want the engine to utilize all their CPU (most users just want to see an analysis/score and list of PVs) and aren't dealing with engine vs. engine with pondering or other situations that warrant this value being anything other than the machine's core count.
//   - NNUE paths (if not embedded NNUE paths should be set by arugment for the same reason all paths should be)
// - Support redirecting to different inputs and outputs potentially?
// - Logging configuration? (we will probably want a build-time option to disable logging entirely and any options here with it)
//   - Like, using "debug on" to redirect Zig std library logs to "info string ..." commands for the GUI to capture

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
