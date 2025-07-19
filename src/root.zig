const std = @import("std");
const AnyUciCommand = @import("corundum_uci").AnyUciCommand;

/// The potential states of the UCI engine
pub const UciEngineState = union(enum) {
    /// The engine is not initialized (we have not received the "isready" command)
    uninitialized: struct {},

    /// We've sent the "isready" command but aren't searching yet
    ready: struct {},

    /// The engine is searching
    thinking: struct {},
};

const logger = std.log.scoped(.engine_manager);

/// The manager for the UCI engine
pub const UciEngineManager = struct {
    const Self = @This();
    /// The input stream for the engine
    input_stream: std.io.Reader,
    /// The output stream for the engine
    output_stream: std.io.Writer,
    /// Root allocator for the engine, used to allocate memory inside of child searchers
    allocator: std.mem.Allocator,
    /// The current state of the engine
    state: UciEngineState = .uninitialized,

    pub fn init(input_stream: std.io.Reader, output_stream: std.io.Writer, allocator: std.mem.Allocator) Self {
        return .{
            .input_stream = input_stream,
            .output_stream = output_stream,
            .allocator = allocator,
        };
    }

    pub fn run(self: *Self) !void {
        while (true) {
            const command = self.input_stream.takeDelimiterExclusive('\n')  catch |err| switch (err) {
                error.StreamTooLong => {
                    logger.err("command too long", .{});
                    continue;
                },
                error.EndOfStream => {
                    logger.warn("input stream closed", .{});
                    return;
                },
                error.ReadFailed => {
                    logger.err("failed to read from input stream", .{});
                    return err;
                },
            };

            logger.debug("received command: {s}", .{command});

            const parsed_command = AnyUciCommand.parse(std.mem.trim(u8, command, " \r\n\t")) catch |err| switch (err) {
                else => @panic("TODO: Handle error"),
            };

            // TODO: Probably abstract this since at this point we can call "try self.handleCommand(parsed_command)"
            switch (parsed_command) {
                .quit => {
                    logger.info("quitting", .{});
                    return;
                },
                else => {
                    std.debug.print("TODO: Handle command {any}", .{parsed_command});
                    continue;
                },
            }
            // TODO: execute the command based on the current state and the parsed command
        }
    }
};
