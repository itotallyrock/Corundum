const std = @import("std");
const build_options = @import("build_options");

pub fn corundumLogger(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (comptime !build_options.enable_logging) return;

    var buffer: [64]u8 = undefined;
    const stderr = std.debug.lockStderrWriter(&buffer);
    defer std.debug.unlockStderrWriter();
    // TODO: Use "Chameleon" or simple ANSI color codes when writing to stderr
    // TODO: Potentially somehow access a "UCI debug info 'Writer'" that when set will redirect or split/'tee' logs into "info string ..." commands
    // TODO: Consider outputting structured args or even using otlp
    // nosuspend stderr.print("{{ \"level\": \"" ++ @tagName(message_level) ++ "\", \"scope\": \"" ++ @tagName(scope) ++ "\", \"message\": \"" ++ format ++ "\" }}\n", args) catch return;
    nosuspend stderr.print("[" ++ levelText(message_level) ++ "][" ++ @tagName(scope) ++ "] " ++ format ++ "\n", args) catch return;
}

pub fn levelText(comptime self: std.log.Level) []const u8 {
    return switch (self) {
        .err => "err",
        .warn => "wrn",
        .info => "inf",
        .debug => "dbg",
    };
}
