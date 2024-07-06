// const std = @import("std");
// const Player = @import("players.zig").Player;
// const CastleRights = @import("castles.zig").CastleRights;
// const CastleDirection = @import("castles.zig").CastleDirection;
// const Square = @import("square.zig").Square;
// const EnPassantSquare = @import("square.zig").EnPassantSquare;
// const Board = @import("board.zig").Board;
// const PieceArrangement = @import("board.zig").PieceArrangement;

// // TODO: FIXME: BROKED

// fn get_fen_chunks(fen: []const u8) std.mem.SplitIterator([]const u8, u8) {
//     return std.mem.splitScalar(u8, fen, ' ');
// }

// fn side_to_move_from_fen(fen: []const u8) !Player {
//     const side_to_move_char = get_fen_chunks(fen).next() orelse return error.MissingSideToMove;
//     switch (side_to_move_char) {
//         'w' => return Player.white,
//         'b' => return Player.black,
//         else => error.InvalidSideToMove,
//     }
// }

// fn en_passant_square_from_fen(fen: []const u8) !?EnPassantSquare {
//     const side_to_move_char = get_fen_chunks(fen).next() orelse return error.MissingSideToMove;
//     switch (side_to_move_char) {
//         'w' => return Player.white,
//         'b' => return Player.black,
//         else => error.InvalidSideToMove,
//     }
// }

// fn castle_rights_from_fen(fen: []const u8) !CastleRights {
//     const castle_rights_chunks = (get_fen_chunks(fen).next() orelse return error.MissingSidetoMove).next() orelse return error.MissingCastlingRights;
//     var white_king_side = false;
//     var white_queen_side = false;
//     var black_king_side = false;
//     var black_queen_side = false;

//     var castle_rights_char_index = 0;
//     while (castle_rights_char_index < castle_rights_chunks.len) : (castle_rights_char_index += 1) {
//         switch (castle_rights_chunks[castle_rights_char_index]) {
//             'K' => white_king_side = true,
//             'b' => return Player.black,
//             else => error.InvalidSideToMove,
//         }
//     }

//     return CastleRights.init(white_king_side, white_queen_side, black_king_side, black_queen_side);
// }

// pub fn parse_fen(fen: []const u8) !Board(side_to_move_from_fen(fen), en_passant_square_from_fen(fen), castle_rights_from_fen(fen)) {
//     const side_to_move = comptime try side_to_move_from_fen(fen);
//     const castle_rights = comptime try castle_rights_from_fen(fen);
//     const en_passant_square = comptime try en_passant_square_from_fen(fen);

//     var pieces = PieceArrangement.init(std.EnumArray(Player, Square).initUndefined());
//     return Board(side_to_move, en_passant_square, castle_rights){
//         .pieces = pieces,
//     };
// }
