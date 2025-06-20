const std = @import("std");
const Uci = @import("./uci.zig").Uci;
const Quit = @import("./quit.zig").Quit;
const Stop = @import("./stop.zig").Stop;
const Debug = @import("./debug.zig").Debug;
const Position = @import("./position.zig").Position;
const IsReady = @import("./is_ready.zig").IsReady;
const PonderHit = @import("./ponder_hit.zig").PonderHit;
const SetOption = @import("./set_option.zig").SetOption;
const UciNewGame = @import("./uci_new_game.zig").UciNewGame;

/// Tagged union for all UCI commands.
pub const AnyUciCommand = union(enum) {
    const Self = @This();

    uci: Uci,
    quit: Quit,
    stop: Stop,
    ponder_hit: PonderHit,
    debug: Debug,
    is_ready: IsReady,
    uci_new_game: UciNewGame,
    position: Position,
    set_option: SetOption,

    /// Attempts to parse a UCI command from the given source string.
    pub fn parse(source: []const u8) !Self {
        const trimmed = std.mem.trim(u8, source, " ");
        if (try Uci.parse(trimmed)) |uci| {
            return AnyUciCommand{ .uci = uci };
        }
        if (try Quit.parse(trimmed)) |quit| {
            return AnyUciCommand{ .quit = quit };
        }
        if (try Stop.parse(trimmed)) |stop| {
            return AnyUciCommand{ .stop = stop };
        }
        if (try PonderHit.parse(trimmed)) |ponder_hit| {
            return AnyUciCommand{ .ponder_hit = ponder_hit };
        }
        if (try Debug.parse(trimmed)) |debug| {
            return AnyUciCommand{ .debug = debug };
        }
        if (try IsReady.parse(trimmed)) |is_ready| {
            return AnyUciCommand{ .is_ready = is_ready };
        }
        if (try UciNewGame.parse(trimmed)) |uci_new_game| {
            return AnyUciCommand{ .uci_new_game = uci_new_game };
        }
        if (try Position.parse(trimmed)) |position| {
            return AnyUciCommand{ .position = position };
        }
        if (try SetOption.parse(trimmed)) |set_option| {
            return AnyUciCommand{ .set_option = set_option };
        }
        // TODO: "go" and "register"

        return error.UnrecognizedCommand;
    }
};

test AnyUciCommand {
    try std.testing.expectEqualDeep(AnyUciCommand{ .uci = Uci{} }, AnyUciCommand.parse("uci"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .debug = Debug{ .enabled = true } }, AnyUciCommand.parse("debug on"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .debug = Debug{ .enabled = false } }, AnyUciCommand.parse("debug off"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .is_ready = IsReady{} }, AnyUciCommand.parse("isready"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .position = Position{ .position = .startpos } }, AnyUciCommand.parse("position startpos"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .uci_new_game = UciNewGame{} }, AnyUciCommand.parse("ucinewgame"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .quit = Quit{} }, AnyUciCommand.parse("quit"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .stop = Stop{} }, AnyUciCommand.parse("stop"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .ponder_hit = PonderHit{} }, AnyUciCommand.parse("ponderhit"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .set_option = SetOption{ .name = "option_name", .value = "option_value" } }, AnyUciCommand.parse("setoption name option_name value option_value"));
    try std.testing.expectEqualDeep(AnyUciCommand{ .set_option = SetOption{ .name = "option_name", .value = null } }, AnyUciCommand.parse("setoption name option_name"));

    // TODO: Test "go" and "register" commands
}
