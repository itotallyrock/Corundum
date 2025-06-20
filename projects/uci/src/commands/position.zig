const std = @import("std");

pub const StartingPosition = union(enum) {
    startpos,
    fen: []const u8,

    pub fn parse(source: []const u8) !StartingPosition {
        if (std.ascii.eqlIgnoreCase(source, "startpos")) {
            return .{ .startpos = {} };
        } else if (std.ascii.startsWithIgnoreCase(source, "fen")) {
            const fen_part = std.mem.trim(u8, source[3..], " ");
            if (fen_part.len == 0) {
                return error.InvalidPositionMissingFen;
            }
            return .{ .fen = fen_part };
        }

        return error.InvalidPositionMissingPosition;
    }
};

pub const Position = struct {
    const Self = @This();

    position: StartingPosition,
    moves: ?std.mem.TokenIterator(u8, .scalar) = null,

    pub fn parse(source: []const u8) !?Self {
        if (std.ascii.startsWithIgnoreCase(source, "position")) {
            const remaining_command = std.mem.trimLeft(u8, source[8..], " ");
            const moves_index = std.ascii.indexOfIgnoreCase(remaining_command, " moves");
            const position, const moves = if (moves_index) |index| .{ std.mem.trim(u8, remaining_command[0..index], " "), std.mem.trim(u8, remaining_command[index + 6 ..], " ") } else .{ remaining_command, null };
            return Self{
                .position = try StartingPosition.parse(position),
                .moves = if (moves) |m| if (m.len > 0) std.mem.tokenizeScalar(u8, m, ' ') else return error.InvalidPositionMissingMoves else null,
            };
        }
        return null;
    }
};

test Position {
    try std.testing.expectEqualDeep(Position{ .position = .startpos }, Position.parse("position startpos"));
    try std.testing.expectEqualDeep(Position{ .position = .startpos }, Position.parse("POSITION STARTPOS"));
    try std.testing.expectEqualDeep(Position{ .position = .startpos }, Position.parse("position     startpos"));
    try std.testing.expectEqualDeep(Position{ .position = .{ .fen = "8/8/8/8/8/8/8/8 w - - 0 1" } }, Position.parse("position fen 8/8/8/8/8/8/8/8 w - - 0 1"));
    try std.testing.expectEqualDeep(Position{ .position = .{ .fen = "8/8/8/8/8/8/8/8 w - - 0 1" }, .moves = std.mem.tokenizeScalar(u8, "A1H8", ' ') }, Position.parse("POSITION FEN 8/8/8/8/8/8/8/8 w - - 0 1 MOVES A1H8"));
    try std.testing.expectEqualDeep(Position{ .position = .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" } }, Position.parse("position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"));
    try std.testing.expectEqualDeep(Position{ .position = .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" }, .moves = std.mem.tokenizeScalar(u8, "e2e4 e7e5 d2d3 f7f6", ' ') }, Position.parse("position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 moves e2e4 e7e5 d2d3 f7f6"));
    try std.testing.expectEqualDeep(Position{ .position = .{ .fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" }, .moves = std.mem.tokenizeScalar(u8, "e2e4 e7e5 d2d3 f7f6", ' ') }, Position.parse("position       fen      rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1    moves     e2e4 e7e5 d2d3 f7f6"));
    try std.testing.expectError(error.InvalidPositionMissingPosition, Position.parse("position"));
    try std.testing.expectError(error.InvalidPositionMissingPosition, Position.parse("position "));
    try std.testing.expectError(error.InvalidPositionMissingFen, Position.parse("position fen"));
    try std.testing.expectError(error.InvalidPositionMissingFen, Position.parse("position fen moves e2e4"));
    try std.testing.expectError(error.InvalidPositionMissingPosition, Position.parse("position moves e2e4"));
    try std.testing.expectError(error.InvalidPositionMissingMoves, Position.parse("position startpos moves"));
    try std.testing.expectEqual(null, Position.parse("not a position command"));
}
