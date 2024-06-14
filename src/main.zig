comptime { @setEvalBranchQuota(2000); }

const std = @import("std");

pub const Square = @import("square.zig").Square;
pub const EnPassantSquare = @import("square.zig").EnPassantSquare;
pub const Board = @import("board.zig").Board;
pub const PieceArrangement = @import("board.zig").PieceArrangement;
pub const Player = @import("players.zig").Player;
pub const CastleRights = @import("castles.zig").CastleRights;
pub const CastleDirection = @import("castles.zig").CastleDirection;
pub const Piece = @import("pieces.zig").Piece;
pub const NonKingPiece = @import("pieces.zig").NonKingPiece;
pub const OwnedPiece = @import("pieces.zig").OwnedPiece;
pub const OwnedNonKingPiece = @import("pieces.zig").OwnedNonKingPiece;
pub const ByPlayer = @import("players.zig").ByPlayer;
// pub const parse_fen = @import("fen.zig").parse_fen;

test {
    std.testing.refAllDecls(@import("board.zig"));
    std.testing.refAllDecls(@import("zobrist.zig"));
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

// test "from fen" {
//     const fen = "rnbq1rk1/ppp2ppp/1b1p1n2/4N3/2BPP3/8/PPP2PPP/RNBQ1RK1 w - - 0 1";
//     try parse_fen(fen);
// }

pub fn main() !void {
    // const board = Board(Player.White, null, CastleRights.initFill(true))
    //     .with_kings(ByPlayer(Square).init(.{.White = .E1, .Black = .E8}));
    @import("board.zig")
        .DefaultBoard
        // .quiet_move(.E2, .E3)
        .double_pawn_push(.E)
        .pawn_push(.E7)
        .pawn_push(.E4)
        .double_pawn_push(.F)
        .en_passant_capture(.E)
        .debug_print();
}

// pub const testing = @import("std").testing;
// pub const _ = @import("design.zig");
// test {
//     testing.refAllDecls(@import("design.zig"));
// }