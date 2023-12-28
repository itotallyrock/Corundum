const std = @import("std");

const Player = enum {
    White,
    Black,

    pub fn opposite(self: Player) Player {
        return if (self == .White) .Black else .White;
    }
};

const Piece = enum {
    Pawn,
    Rook,
    Knight,
    Bishop,
    Queen,
    King,
};

const NonKingPiece = enum {
    Pawn,
    Rook,
    Knight,
    Bishop,
    Queen,

    pub fn from_piece(piece: Piece) !NonKingPiece {
        return switch (piece) {
            .Pawn => .Pawn,
            .Rook => .Rook,
            .Knight => .Knight,
            .Bishop => .Bishop,
            .Queen => .Queen,
            .King => error.InvalidPiece,
        };
    }
};

const Square = enum(u6) {
    A1, B1, C1, D1, E1, F1, G1, H1,
    A2, B2, C2, D2, E2, F2, G2, H2,
    A3, B3, C3, D3, E3, F3, G3, H3,
    A4, B4, C4, D4, E4, F4, G4, H4,
    A5, B5, C5, D5, E5, F5, G5, H5,
    A6, B6, C6, D6, E6, F6, G6, H6,
    A7, B7, C7, D7, E7, F7, G7, H7,
    A8, B8, C8, D8, E8, F8, G8, H8,

    fn to_bitboard(self: Square) Bitboard {
        return @as(Bitboard, 1) << @intFromEnum(self);
    }
};

const EnPassantSquare = enum(u6) {
    A3, B3, C3, D3, E3, F3, G3, H3,
    A6, B6, C6, D6, E6, F6, G6, H6,
};

const CastleDirection = enum {
    KingSide,
    QueenSide,
};

const Bitboard = u64;
const EmptyBitboard: Bitboard = 0;

const OwnedPiece = struct {
    player: Player,
    piece: Piece,
};

const OwnedNonKingPiece = struct {
    player: Player,
    piece: NonKingPiece,
};

const PieceArrangement = struct {
    side_masks: std.EnumArray(Player, Bitboard) = std.EnumArray(Player, Bitboard).initFill(EmptyBitboard),
    piece_masks: std.EnumArray(NonKingPiece, Bitboard) = std.EnumArray(NonKingPiece, Bitboard).initFill(EmptyBitboard),
    kings: std.EnumArray(Player, Square),

    fn init(king_squares: std.EnumArray(Player, Square)) PieceArrangement {
        var side_masks = std.EnumArray(Player, Bitboard).init(.{.White = king_squares.get(.White).to_bitboard(), .Black = king_squares.get(.Black).to_bitboard()});
        return PieceArrangement {
            .side_masks = side_masks,
            .kings = king_squares,
        };
    }

    fn add_piece(self: PieceArrangement, comptime piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        var result = self;
        const square_bitboard = square.to_bitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player) | square_bitboard);
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece) | square_bitboard);
        return result;
    }

    fn remove_piece(self: PieceArrangement, comptime piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        var result = self;
        const square_bitboard = square.to_bitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player) & ~square_bitboard);
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece) & ~square_bitboard);
        return result;
    }

    fn move_piece(self: PieceArrangement, comptime piece: OwnedPiece, from_square: Square, to_square: Square) PieceArrangement {
        var result = self;
        const from_square_bitboard = from_square.to_bitboard();
        const to_square_bitboard = to_square.to_bitboard();
        const from_to_square_bitboard = from_square_bitboard | to_square_bitboard;
        set_piece_mask: {
            const non_king_piece = NonKingPiece.from_piece(piece.piece) catch {
                result.kings.set(piece.player, to_square);
                break :set_piece_mask;
            };
            result.piece_masks.set(non_king_piece, result.piece_masks.get(non_king_piece) ^ from_to_square_bitboard);
        }
        result.side_masks.set(piece.player, result.side_masks.get(piece.player) ^ from_to_square_bitboard);
        return result;
    }

    fn piece_on(self: PieceArrangement, square: Square) ?Piece {
        const square_mask = square.to_bitboard();
        inline for (comptime std.enums.values(NonKingPiece)) |piece| {
            if (self.piece_masks.get(piece) & square_mask != EmptyBitboard) {
                return piece;
            }
        }
        return null;
    }
};

const CastleRights = std.EnumArray(Player, std.EnumArray(CastleDirection, bool));

const ZobristKey = u64;

const HalfMoveCount = u8;

const BASE_ZOBRIST_KEY: ZobristKey = 0xF1DC_4349_4EA4_76CE;

fn Board(comptime side_to_move: Player, comptime en_passant_square: ?EnPassantSquare, comptime rights: CastleRights) type {
    return struct {
        pieces: PieceArrangement,
        key: ZobristKey = BASE_ZOBRIST_KEY,
        halfmove_clock: HalfMoveCount = 0,
        halfmove_count: HalfMoveCount = 0,

        fn with_kings(king_squares: std.EnumArray(Player, Square)) Board(side_to_move, en_passant_square, rights) {
            return Board(side_to_move, en_passant_square, rights) {
                .pieces = PieceArrangement.init(king_squares),
            };
        }

        fn add_piece(self: Board(side_to_move, en_passant_square, rights), comptime piece: OwnedNonKingPiece, square: Square) Board(side_to_move, en_passant_square, rights) {
            // todo: update zobrist key and other state
            return Board(side_to_move, en_passant_square, rights){
                .pieces = self.pieces.add_piece(piece, square),
            };
        }

        fn remove_piece(self: Board(side_to_move, en_passant_square, rights), comptime piece: OwnedNonKingPiece, square: Square) Board(side_to_move, en_passant_square, rights) {
            // todo: update zobrist key and other state
            return Board(side_to_move, en_passant_square, rights){
                .pieces = self.pieces.remove_piece(piece, square),
            };
        }

        fn move_piece(self: Board(side_to_move, en_passant_square, rights), comptime piece: OwnedPiece, from_square: Square, to_square: Square) Board(side_to_move, en_passant_square, rights) {
            // todo: update zobrist key and other state
            return Board(side_to_move, en_passant_square, rights){
                .pieces = self.pieces.move_piece(piece, from_square, to_square),
            };
        }

        fn attacked(_: Board(side_to_move, en_passant_square, rights)) Bitboard {
            @compileError("TODO: implement attacked mask");
        }

        pub fn piece_on(self: Board(side_to_move, en_passant_square, rights), square: Square) ?Piece {
            return self.pieces.piece_on(square);
        }

        pub fn quiet_move(self: Board(side_to_move, en_passant_square, rights), from_square: Square, to_square: Square) Board(side_to_move.opposite(), null, rights) {
            var board = Board(side_to_move.opposite(), null, rights) {
                .pieces = self.pieces,
                .key = self.key,
                .halfmove_clock = self.halfmove_clock + 1,
                .halfmove_count = self.halfmove_count + 1,
            };
            return board.move_piece(.{.piece = .Pawn, .player = side_to_move}, to_square, from_square);
        }
    };
}

const DefaultKingSquares = std.EnumArray(Player, Square).init(.{ .White = .E1, .Black = .E8});
const DefaultBoard = Board(.White, null, CastleRights.initFill(std.EnumArray(CastleDirection, bool).initFill(true)))
    .with_kings(std.EnumArray(Player, Square).init(.{.White = .E1, .Black = .E8}))
    .add_piece(.{.piece = .Rook, .player = .White}, .A1)
    .add_piece(.{.piece = .Pawn, .player = .White}, .A2)
    .add_piece(.{.piece = .Pawn, .player = .White}, .B2)
    .add_piece(.{.piece = .Pawn, .player = .White}, .C2)
    .add_piece(.{.piece = .Pawn, .player = .White}, .D2)
    .add_piece(.{.piece = .Pawn, .player = .White}, .E2)
    .add_piece(.{.piece = .Pawn, .player = .White}, .F2)
    .add_piece(.{.piece = .Pawn, .player = .White}, .G2)
    .add_piece(.{.piece = .Pawn, .player = .White}, .H2)
    .add_piece(.{.piece = .Rook, .player = .White}, .A1)
    .add_piece(.{.piece = .Knight, .player = .White}, .B1)
    .add_piece(.{.piece = .Bishop, .player = .White}, .C1)
    .add_piece(.{.piece = .Queen, .player = .White}, .D1)
    .add_piece(.{.piece = .Bishop, .player = .White}, .F1)
    .add_piece(.{.piece = .Knight, .player = .White}, .G1)
    .add_piece(.{.piece = .Rook, .player = .White}, .H1)
    // black pieces
    .add_piece(.{.piece = .Pawn, .player = .Black}, .A7)
    .add_piece(.{.piece = .Pawn, .player = .Black}, .B7)
    .add_piece(.{.piece = .Pawn, .player = .Black}, .C7)
    .add_piece(.{.piece = .Pawn, .player = .Black}, .D7)
    .add_piece(.{.piece = .Pawn, .player = .Black}, .E7)
    .add_piece(.{.piece = .Pawn, .player = .Black}, .F7)
    .add_piece(.{.piece = .Pawn, .player = .Black}, .G7)
    .add_piece(.{.piece = .Pawn, .player = .Black}, .H7)
    .add_piece(.{.piece = .Rook, .player = .Black}, .A8)
    .add_piece(.{.piece = .Knight, .player = .Black}, .B8)
    .add_piece(.{.piece = .Bishop, .player = .Black}, .C8)
    .add_piece(.{.piece = .Queen, .player = .Black}, .D8)
    .add_piece(.{.piece = .Bishop, .player = .Black}, .F8)
    .add_piece(.{.piece = .Knight, .player = .Black}, .G8)
    .add_piece(.{.piece = .Rook, .player = .Black}, .H8);

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
