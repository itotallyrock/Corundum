const std = @import("std");
const Go = @import("./go.zig").Go;
const Uci = @import("./uci.zig").Uci;
const Quit = @import("./quit.zig").Quit;
const Stop = @import("./stop.zig").Stop;
const Debug = @import("./debug.zig").Debug;
const Position = @import("./position.zig").Position;
const IsReady = @import("./is_ready.zig").IsReady;
const PonderHit = @import("./ponder_hit.zig").PonderHit;
const Register = @import("./register.zig").Register;
const SetOption = @import("./set_option.zig").SetOption;
const UciNewGame = @import("./uci_new_game.zig").UciNewGame;

/// Tagged union for all UCI gui_commands.
pub const AnyGuiCommand = union(enum) {
    const Self = @This();

    go: Go,
    uci: Uci,
    quit: Quit,
    stop: Stop,
    ponder_hit: PonderHit,
    debug: Debug,
    is_ready: IsReady,
    uci_new_game: UciNewGame,
    position: Position,
    register: Register,
    set_option: SetOption,

    /// Attempts to parse a UCI command from the given source string.
    pub fn parse(source: []const u8) !Self {
        const trimmed = std.mem.trim(u8, source, " ");
        if (try Uci.parse(trimmed)) |uci| {
            return AnyGuiCommand{ .uci = uci };
        }
        if (try Quit.parse(trimmed)) |quit| {
            return AnyGuiCommand{ .quit = quit };
        }
        if (try Stop.parse(trimmed)) |stop| {
            return AnyGuiCommand{ .stop = stop };
        }
        if (try PonderHit.parse(trimmed)) |ponder_hit| {
            return AnyGuiCommand{ .ponder_hit = ponder_hit };
        }
        if (try Debug.parse(trimmed)) |debug| {
            return AnyGuiCommand{ .debug = debug };
        }
        if (try IsReady.parse(trimmed)) |is_ready| {
            return AnyGuiCommand{ .is_ready = is_ready };
        }
        if (try UciNewGame.parse(trimmed)) |uci_new_game| {
            return AnyGuiCommand{ .uci_new_game = uci_new_game };
        }
        if (try Position.parse(trimmed)) |position| {
            return AnyGuiCommand{ .position = position };
        }
        if (try SetOption.parse(trimmed)) |set_option| {
            return AnyGuiCommand{ .set_option = set_option };
        }
        if (try Register.parse(trimmed)) |register| {
            return AnyGuiCommand{ .register = register };
        }
        if (try Go.parse(trimmed)) |go| {
            return AnyGuiCommand{ .go = go };
        }

        return error.UnrecognizedCommand;
    }
};

test AnyGuiCommand {
    try std.testing.expectEqualDeep(AnyGuiCommand{ .uci = Uci{} }, AnyGuiCommand.parse("uci"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .debug = Debug{ .enabled = true } }, AnyGuiCommand.parse("debug on"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .debug = Debug{ .enabled = false } }, AnyGuiCommand.parse("debug off"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .is_ready = IsReady{} }, AnyGuiCommand.parse("isready"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .position = Position{ .position = .startpos } }, AnyGuiCommand.parse("position startpos"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .uci_new_game = UciNewGame{} }, AnyGuiCommand.parse("ucinewgame"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .quit = Quit{} }, AnyGuiCommand.parse("quit"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .stop = Stop{} }, AnyGuiCommand.parse("stop"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .ponder_hit = PonderHit{} }, AnyGuiCommand.parse("ponderhit"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .set_option = SetOption{ .name = "option_name", .value = "option_value" } }, AnyGuiCommand.parse("setoption name option_name value option_value"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .set_option = SetOption{ .name = "option_name", .value = null } }, AnyGuiCommand.parse("setoption name option_name"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .register = Register{ .user = .{ .name = "engine_name", .code = "engine_code" } } }, AnyGuiCommand.parse("register name engine_name code engine_code"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .register = Register{ .later = .{} } }, AnyGuiCommand.parse("register later"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .go = Go{} }, AnyGuiCommand.parse("go infinite"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .go = Go{ .depth = 10 } }, AnyGuiCommand.parse("go depth 10"));
    try std.testing.expectEqualDeep(AnyGuiCommand{ .go = Go{ .time_controls = .{ .search_time_ms = 1000 } } }, AnyGuiCommand.parse("go movetime 1000"));
}
