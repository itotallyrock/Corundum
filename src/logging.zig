const std = @import("std");
const build_options = @import("build_options");
const Chameleon = @import("chameleon");

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
    nosuspend stderr.print("[" ++ levelText(message_level) ++ "][" ++ scopeText(scope) ++ "] " ++ format ++ "\n", args) catch return;
}

inline fn levelText(comptime level: std.log.Level) []const u8 {
    var c = Chameleon.initComptime();
    return switch (level) {
        .err => c.bold().redBright().fmt("err"),
        .warn => c.yellow().fmt("wrn"),
        .info => c.cyan().fmt("inf"),
        .debug => c.magenta().fmt("dbg"),
    };
}

inline fn scopeText(comptime scope: @TypeOf(.enum_literal)) []const u8 {
    var c = Chameleon.initComptime();
    return c.white().fmt(@tagName(scope));
}
