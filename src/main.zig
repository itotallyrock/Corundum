const std = @import("std");

pub const UciParser = @import("uci_parser.zig").UciParser;

pub const CliManager = @import("uci.zig").CliManager;
pub const Square = @import("square.zig").Square;
pub const EnPassantSquare = @import("square.zig").EnPassantSquare;
pub const Board = @import("board.zig").Board;
pub const PieceArrangement = @import("board.zig").PieceArrangement;
pub const Player = @import("players.zig").Player;
pub const CastleConfig = @import("castles.zig").CastleConfig;
pub const CastleAbilities = @import("castles.zig").CastleAbilities;
pub const CastleDirection = @import("castles.zig").CastleDirection;
pub const Piece = @import("pieces.zig").Piece;
pub const NonKingPiece = @import("pieces.zig").NonKingPiece;
pub const OwnedPiece = @import("pieces.zig").OwnedPiece;
pub const OwnedNonKingPiece = @import("pieces.zig").OwnedNonKingPiece;
pub const ByPlayer = @import("players.zig").ByPlayer;
pub const BoardMove = @import("moves.zig").BoardMove;
pub const lines = @import("lines.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}

pub fn main() !void {
    _ = @import("board.zig")
        .Board.start_position
        .doublePawnPush(.e)
        .pawnPush(.e7)
        .pawnPush(.e4)
        .doublePawnPush(.f)
        .enPassantCapture(.e)
        .kingMove(.e8, .e7)
        .debugPrint();

    var stdin = std.io.getStdIn();
    defer stdin.close();
    var stdout = std.io.getStdOut();
    defer stdout.close();

    var buffered_stdin = std.io.bufferedReader(stdin.reader());

    var cli_manager = CliManager.init(buffered_stdin.reader().any(), stdout.writer().any());
    try cli_manager.run();
}
