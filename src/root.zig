const std = @import("std");
const uci = @import("corundum_uci");

/// The potential states of the UCI engine_commands
pub const UciEngineState = union(enum) {
    /// The engine_commands is not initialized (we have not received the "isready" command)
    uninitialized: struct {},

    /// We've sent the "isready" command but aren't searching yet
    ready: struct {},

    /// The engine_commands is searching
    thinking: struct {},
};

const logger = std.log.scoped(.engine_manager);

/// The manager for the UCI engine_commands
pub const UciEngineManager = struct {
    const Self = @This();
    /// The input stream for the engine_commands
    input_stream: *std.io.Reader,
    /// The output stream for the engine_commands
    output_stream: *std.io.Writer,
    /// Root allocator for the engine_commands, used to allocate memory inside of child searchers
    allocator: std.mem.Allocator,
    /// The current state of the engine_commands
    state: UciEngineState = .uninitialized,

    pub fn init(input_stream: *std.io.Reader, output_stream: *std.io.Writer, allocator: std.mem.Allocator) Self {
        return .{
            .input_stream = input_stream,
            .output_stream = output_stream,
            .allocator = allocator,
        };
    }

    pub fn run(self: *Self) !void {
        while (true) {
            const command = self.input_stream.takeDelimiterExclusive('\n') catch |err| switch (err) {
                error.StreamTooLong => {
                    logger.err("command too long", .{});
                    continue;
                },
                error.EndOfStream => {
                    logger.warn("input stream closed", .{});
                    break;
                },
                error.ReadFailed => {
                    logger.err("failed to read from input stream", .{});
                    return err;
                },
            };

            logger.debug("received command: {s}", .{command});

            const trimmed_command = std.mem.trim(u8, command, " \r\n\t");
            if (trimmed_command.len == 0) {
                continue;
            }

            const parsed_command = uci.AnyGuiCommand.parse(trimmed_command) catch |err| {
                std.debug.print("TODO: Handle parse command error {any}\n", .{err});
                continue;
            };

            switch (parsed_command) {
                .quit => {
                    logger.info("quitting", .{});
                    break;
                },
                .uci => {
                    try self.output_stream.print("{f}\n", .{uci.Id{ .name = "Corundum 0.420.69" }});
                    try self.output_stream.print("{f}\n", .{uci.Id{ .author = "Jeffrey <itotallyrock> Meyer" }});
                    // TODO: print available options
                    try self.output_stream.print("{f}\n", .{uci.UciOk{}});
                },
                .is_ready => {
                    // TODO: initiailize if we're not already initialized, etc
                    try self.output_stream.print("{f}\n", .{uci.ReadyOk{}});
                },
                else => {
                    std.debug.print("TODO: Handle command {any}\n", .{parsed_command});
                    continue;
                },
            }
        }

        // Quit or stop called, cleanup all resources
        self.deinit();
    }

    fn deinit(self: *Self) void {
        // TODO: cleanup any resources, free allocations, join threads, flush/close streams etc
        self.output_stream.flush() catch {};
    }
};

test "adheres to basic startup uci protocol" {
    var input_buffer: [256]u8 = undefined;
    var output_buffer: [1024]u8 = undefined;
    var adapter_buffer: [256]u8 = undefined;
    var test_reader = std.testing.Reader.init(&input_buffer, &.{ .{ .buffer = "uci\n" }, .{ .buffer = "isready\n" }, .{ .buffer = "quit\n" } });
    var output_stream = std.Io.fixedBufferStream(&output_buffer);
    var writer = output_stream.writer().adaptToNewApi(&adapter_buffer);
    var engine_manager = UciEngineManager.init(&test_reader.interface, &writer.new_interface, std.testing.allocator);

    try engine_manager.run();

    var responses = std.mem.tokenizeScalar(u8, output_stream.getWritten(), '\n');
    try std.testing.expectStringStartsWith(responses.next().?, "id name ");
    try std.testing.expectStringStartsWith(responses.next().?, "id author ");
    try std.testing.expectEqualStrings("uciok", responses.next().?);
    try std.testing.expectEqualStrings("readyok", responses.next().?);
    try std.testing.expectEqual(null, responses.next());
}

test {
    std.testing.refAllDecls(@This());
}
