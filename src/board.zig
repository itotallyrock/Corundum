const std = @import("std");
const Player = @import("players.zig").Player;
const ByPlayer = @import("players.zig").ByPlayer;
const CastleRights = @import("castles.zig").CastleRights;
const CastleDirection = @import("castles.zig").CastleDirection;
const Square = @import("square.zig").Square;
const Rank = @import("square.zig").Rank;
const File = @import("square.zig").File;
const EnPassantSquare = @import("square.zig").EnPassantSquare;
const Bitboard = @import("bitboard.zig").Bitboard;
const NonKingPiece = @import("pieces.zig").NonKingPiece;
const ByNonKingPiece = @import("pieces.zig").ByNonKingPiece;
const OwnedPiece = @import("pieces.zig").OwnedPiece;
const OwnedNonPawnPiece = @import("pieces.zig").OwnedNonPawnPiece;
const OwnedNonKingPiece = @import("pieces.zig").OwnedNonKingPiece;
const Piece = @import("pieces.zig").Piece;
const Direction = @import("square.zig").Direction;
const ZobristHash = @import("zobrist.zig").ZobristHash;
const BASE_ZOBRIST_KEY = @import("zobrist.zig").BASE_ZOBRIST_KEY;

pub const FullMoveCount = u8;

pub const HalfMoveCount = struct {
    const MAX_HALFMOVES_CLOCK = comptime_int(100);
    halfmoves: u8 = 0,

    pub fn increment(self: HalfMoveCount) HalfMoveCount {
        return HalfMoveCount { .halfmoves = self.halfmoves +| 1 };
    }

    pub fn decrement(self: HalfMoveCount) HalfMoveCount {
        return HalfMoveCount { .halfmoves = self.halfmoves -| 1 };
    }

    pub fn init(halfmoves: u8) HalfMoveCount {
        return HalfMoveCount { .halfmoves = halfmoves };
    }

    pub fn reset() HalfMoveCount {
        return HalfMoveCount { .halfmoves = 0 };
    }

    pub fn from_fullmoves(fullmoves: FullMoveCount, side_to_move: Player) HalfMoveCount {
        return fullmoves * 2 + @intFromBool(side_to_move == Player.black);
    }

    pub fn has_exceeded_move_clock(self: HalfMoveCount) bool {
        return self.halfmoves >= MAX_HALFMOVES_CLOCK;
    }
};

pub const PieceArrangement = struct {
    side_masks: ByPlayer(Bitboard) = ByPlayer(Bitboard).initFill(Bitboard.Empty),
    piece_masks: ByNonKingPiece(Bitboard) = ByNonKingPiece(Bitboard).initFill(Bitboard.Empty),
    kings: ByPlayer(Square),

    pub fn init(king_squares: ByPlayer(Square)) PieceArrangement {
        const side_masks = std.EnumArray(Player, Bitboard).init(.{.White = king_squares.get(.White).to_bitboard(), .Black = king_squares.get(.Black).to_bitboard()});
        return PieceArrangement {
            .side_masks = side_masks,
            .kings = king_squares,
        };
    }

    pub fn add_piece(self: PieceArrangement, comptime piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        var result = self;
        const square_bitboard = square.to_bitboard();
        // TODO: Debug assert empty square
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalOr(square_bitboard));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalOr(square_bitboard));
        return result;
    }

    pub fn remove_piece(self: PieceArrangement, comptime piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        var result = self;
        const square_bitboard = square.to_bitboard();
        std.debug.assert(result.side_on(square).? == piece.player);
        std.debug.assert(result.piece_on(square).? == piece.piece.to_piece());

        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalAnd(square_bitboard.logicalNot()));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalAnd(square_bitboard.logicalNot()));
        return result;
    }

    pub fn move_piece(self: PieceArrangement, comptime piece: OwnedPiece, from_square: Square, to_square: Square) PieceArrangement {
        var result = self;
        const from_square_bitboard = from_square.to_bitboard();
        const to_square_bitboard = to_square.to_bitboard();
        const from_to_square_bitboard = from_square_bitboard.logicalOr(to_square_bitboard);
        // TODO: Debug assert empty to square
        // TODO: Debug assert piece on from square
        set_piece_mask: {
            const non_king_piece = NonKingPiece.from_piece(piece.piece) catch {
                result.kings.set(piece.player, to_square);
                break :set_piece_mask;
            };
            result.piece_masks.set(non_king_piece, result.piece_masks.get(non_king_piece).logicalXor(from_to_square_bitboard));
        }
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalXor(from_to_square_bitboard));
        return result;
    }

    pub fn piece_on(self: PieceArrangement, square: Square) ?Piece {
        if ((self.kings.get(.White) == square) or (self.kings.get(.Black) == square)) {
            return .King;
        }

        const square_mask = square.to_bitboard();
        inline for (comptime std.enums.values(NonKingPiece)) |piece| {
            if (!self.piece_masks.get(piece).logicalAnd(square_mask).isEmpty()) {
                return piece.to_piece();
            }
        }
        return null;
    }

    pub fn side_on(self: PieceArrangement, square: Square) ?Player {
        const square_mask = square.to_bitboard();
        inline for (comptime std.enums.values(Player)) |player| {
            if (!self.side_masks.get(player).logicalAnd(square_mask).isEmpty()) {
                return player;
            }
        }
        return null;
    }

    pub fn sided_piece_on(self: PieceArrangement, square: Square) ?OwnedPiece {
        if (self.piece_on(square)) |piece| {
            return .{.piece = piece, .player = self.side_on(square).?};
        }
        return null;
    }
};

const PersistentBoardState = struct {
    // Non-recoverable state
    key: ZobristHash,
    halfmove_clock: HalfMoveCount = HalfMoveCount.reset(),
    // Move generation state to avoid recomputing
    checkers: Bitboard,
    pinners: ByPlayer(Bitboard),
    blockers: ByPlayer(Bitboard),
    check_squares: ByNonKingPiece(Bitboard),

    pub fn init(comptime side_to_move: Player, comptime en_passant_file: ?File, comptime rights: CastleRights, king_squares: ByPlayer(Square)) PersistentBoardState {
        const ep_square = if (en_passant_file) |*ep_file| ep_file.ep_square_for(side_to_move) else null;
        return PersistentBoardState {
            .key = ZobristHash.init(side_to_move, king_squares, rights, ep_square),
            // todo: compute move generation masks
            .checkers = Bitboard.Empty,
            .pinners = ByPlayer(Bitboard).initFill(Bitboard.Empty),
            .blockers = ByPlayer(Bitboard).initFill(Bitboard.Empty),
            .check_squares = ByNonKingPiece(Bitboard).initFill(Bitboard.Empty),
        };
    }

    fn add_piece(self: PersistentBoardState, comptime piece: OwnedNonKingPiece, square: Square) PersistentBoardState {
        var result = self;
        result.key = result.key.toggle_piece(piece.to_owned(), square);
        // todo: update move generation masks?
        return result;
    }

    fn remove_piece(self: PersistentBoardState, comptime piece: OwnedNonKingPiece, square: Square) PersistentBoardState {
       var result = self;
       result.key = result.key.toggle_piece(piece.to_owned(), square);
       // todo: update move generation masks?
       return result;
   }

    fn move_piece(self: PersistentBoardState, comptime piece: OwnedPiece, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;
        result.key = result.key.move(piece, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    // TODO: replace OwnedPiece with OwnedNonPawnPiece
    pub fn quiet_move(self: PersistentBoardState, comptime piece: OwnedNonPawnPiece, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self.move_piece(piece.to_owned(), from_square, to_square);
        result.halfmove_clock = result.halfmove_clock.increment();
        // todo: update move generation masks
        return result;
    }

    pub fn pawn_push(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square) PersistentBoardState {
        var result = self;
        const forward = Direction.forward(side_to_move);
        const to_square = from_square.shift(forward).?;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.move(.{ .player = side_to_move, .piece = .Pawn }, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    pub fn double_pawn_push(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square) PersistentBoardState {
        var result = self;
        const forward = Direction.forward(side_to_move);
        const to_square = from_square.shift(forward).?.shift(forward).?;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.move(.{ .player = side_to_move, .piece = .Pawn }, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    pub fn en_passant_capture(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.move(.{ .player = side_to_move, .piece = .Pawn }, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    // todo: add other move types, including those that reset the halfmove clock
    // todo: consider adding moves that could be used to more optimally compute move generation masks (capture?)
};

pub fn Board(comptime side_to_move: Player, comptime en_passant_file: ?File, comptime rights: CastleRights) type {
    return struct {
        pieces: PieceArrangement,
        halfmove_count: HalfMoveCount = HalfMoveCount.reset(),
        state: PersistentBoardState,

        fn with_kings(king_squares: ByPlayer(Square)) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights) {
                .pieces = PieceArrangement.init(king_squares),
                .state = PersistentBoardState.init(side_to_move, en_passant_file, rights, king_squares),
            };
        }

        fn add_piece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedNonKingPiece, square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.add_piece(piece, square),
                .state = self.state.add_piece(piece, square),
            };
        }

        fn remove_piece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedNonKingPiece, square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.remove_piece(piece, square),
                .state = self.state.remove_piece(piece, square),
            };
        }

        fn move_piece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedPiece, from_square: Square, to_square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.move_piece(piece, from_square, to_square),
                .state = self.state.move_piece(piece, from_square, to_square),
            };
        }

        pub fn attacked(_: Board(side_to_move, en_passant_file, rights)) Bitboard {
            @compileError("TODO: implement attacked mask");
        }

        fn next(self: Board(side_to_move, en_passant_file, rights), comptime next_en_passant_file: ?File, comptime next_rights: CastleRights) Board(side_to_move.opposite(), next_en_passant_file, next_rights) {
            return Board(side_to_move.opposite(), next_en_passant_file, next_rights) {
                .pieces = self.pieces,
                .state = self.state,
                .halfmove_count = self.halfmove_count,
            };
        }

        fn increment_halfmove_count(self: Board(side_to_move, en_passant_file, rights)) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights) {
                .pieces = self.pieces,
                .state = self.state,
                .halfmove_count = self.halfmove_count.increment(),
            };
        }

        pub fn player(_: Board(side_to_move, en_passant_file, rights)) Player {
            return side_to_move;
        }

        pub fn ep_square(_: Board(side_to_move, en_passant_file, rights)) ?EnPassantSquare {
            return if (en_passant_file) |*ep_file| ep_file.ep_square_for(side_to_move.opposite()) else null;
        }

        pub fn piece_on(self: Board(side_to_move, en_passant_file, rights), square: Square) ?Piece {
            return self.pieces.piece_on(square);
        }

        pub fn side_on(self: Board(side_to_move, en_passant_file, rights), square: Square) ?Player {
            return self.pieces.side_on(square);
        }

        pub fn sided_piece_on(self: Board(side_to_move, en_passant_file, rights), square: Square) ?OwnedPiece {
            return self.pieces.sided_piece_on(square);
        }

        pub fn pawn_push(self: Board(side_to_move, en_passant_file, rights), from_square: Square) Board(side_to_move.opposite(), null, rights) {
            const to_square = from_square.shift(Direction.forward(side_to_move)).?;
            var updated_board = self.move_piece(.{.piece = .Pawn, .player = side_to_move}, from_square, to_square);
            updated_board.state = updated_board.state.pawn_push(side_to_move, from_square);

            return updated_board.next(null, rights);
        }

        pub fn double_pawn_push(self: Board(side_to_move, en_passant_file, rights), comptime file: File) Board(side_to_move.opposite(), file, rights) {
            const next_ep_square = file.ep_square_for(side_to_move).to_square();
            const from_square = next_ep_square.shift(Direction.forward(side_to_move).opposite()).?;
            const to_square = next_ep_square.shift(Direction.forward(side_to_move)).?;
            var updated_board = self.move_piece(.{.piece = .Pawn, .player = side_to_move}, from_square, to_square);
            updated_board.state = updated_board.state.double_pawn_push(side_to_move, from_square);

            return updated_board.next(file, rights);
        }

        pub fn en_passant_capture(self: Board(side_to_move, en_passant_file, rights), comptime from_file: File) Board(side_to_move.opposite(), null, rights) {
            const to_square = self.ep_square().?.to_square();
            const from_square = from_file.ep_square_for(side_to_move.opposite()).to_square().shift(Direction.forward(side_to_move.opposite())).?;
            const captured_pawn_square = to_square.shift(Direction.forward(side_to_move.opposite())).?;
            var updated_board = self.remove_piece(.{.piece = .Pawn, .player = side_to_move.opposite()}, captured_pawn_square)
                .move_piece(.{.piece = .Pawn, .player = side_to_move}, from_square, to_square);
            updated_board.state = updated_board.state.en_passant_capture(side_to_move, from_square, to_square);
            return updated_board.next(null, rights);
        }

        pub fn debug_print(self: Board(side_to_move, en_passant_file, rights)) void {
            const line = "+---+---+---+---+---+---+---+---+";
            std.debug.print("{s}\n", .{line});
            inline for (comptime .{ Rank._8, Rank._7, Rank._6, Rank._5, Rank._4, Rank._3, Rank._2, Rank._1 }) |rank| {
                inline for (comptime std.enums.values(File)) |file| {
                    const square = Square.from_rank_and_file(rank, file);
                    const piece = self.sided_piece_on(square);
                    const pieceChar = if (piece) |p| @tagName(p.piece)[0] else ' ';
                    const sidedPieceChar = if (piece) |p| if (p.player == .White) std.ascii.toUpper(pieceChar) else std.ascii.toLower(pieceChar) else pieceChar;
                    std.debug.print("| {c} ", .{ sidedPieceChar });
                }
                switch (rank) {
                    ._8 => std.debug.print("|\n{s}\n", .{line}),
                    ._7 => std.debug.print("|    Side to Move: {s}\n{s}   Castle Rights: {s}\n", .{
                        @tagName(side_to_move),
                        line,
                        rights.get_uci_string(),
                    }),
                    ._6 => std.debug.print("|      En Passant: {s}\n{s}  Halfmove Clock: {d}\n", .{if (self.ep_square()) |sq| @tagName(sq) else "-", line, self.state.halfmove_clock.halfmoves}),
                    ._5 => std.debug.print("|\n{s}    Zobrist Hash: 0x{X}\n", .{line, self.state.key.key}),
                    ._4 => std.debug.print("|   Checkers Mask: 0x{X}\n{s}\n", .{self.state.checkers.mask, line}),
                    ._3 => std.debug.print("|\n{s}\n", .{line}),
                    ._2 => std.debug.print("|\n{s}\n", .{line}),
                    ._1 => std.debug.print("|\n{s}\n", .{line}),
                }
            }
        }
    };
}

pub const DefaultBoard = Board(.White, null, CastleRights.initFill(true))
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

test "some basic moves on the start board" {
    const board = DefaultBoard;

    try std.testing.expectEqual(board.pieces.piece_on(.E2), .Pawn);
    try std.testing.expectEqual(board.pieces.piece_on(.E3), null);
    try std.testing.expectEqualDeep(board.halfmove_count, HalfMoveCount.reset());
    const pawnE2E3 = board.pawn_push(.E2);
    try std.testing.expectEqual(pawnE2E3.pieces.piece_on(.E2), null);
    try std.testing.expectEqual(pawnE2E3.pieces.piece_on(.E3), .Pawn);
    try std.testing.expectEqual(pawnE2E3.halfmove_count, HalfMoveCount.reset());

    try std.testing.expectEqual(pawnE2E3.pieces.piece_on(.E7), .Pawn);
    try std.testing.expectEqual(pawnE2E3.pieces.piece_on(.E5), null);
    const pawnE7E5 = pawnE2E3.double_pawn_push(.E);
    try std.testing.expectEqual(pawnE7E5.pieces.piece_on(.E7), null);
    try std.testing.expectEqual(pawnE7E5.pieces.piece_on(.E5), .Pawn);
    try std.testing.expectEqual(pawnE7E5.halfmove_count, HalfMoveCount.reset());
    try std.testing.expectEqual(pawnE7E5.ep_square(), .E6);
}