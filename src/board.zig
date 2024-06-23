const std = @import("std");
const playerModule = @import("players.zig");
const bitboardModule = @import("bitboard.zig");
const castlesModule = @import("castles.zig");
const piecesModule = @import("pieces.zig");
const squareModule = @import("square.zig");
const directionsModule = @import("directions.zig");
const zobristModule = @import("zobrist.zig");

const Bitboard = bitboardModule.Bitboard;
const Player = playerModule.Player;
const ByPlayer = playerModule.ByPlayer;
const CastleRights = castlesModule.CastleRights;
const CastleDirection = castlesModule.CastleDirection;
const Square = squareModule.Square;
const Rank = squareModule.Rank;
const File = squareModule.File;
const BoardDirection = directionsModule.BoardDirection;
const EnPassantSquare = squareModule.EnPassantSquare;
const NonKingPiece = piecesModule.NonKingPiece;
const ByNonKingPiece = piecesModule.ByNonKingPiece;
const OwnedPiece = piecesModule.OwnedPiece;
const OwnedNonPawnPiece = piecesModule.OwnedNonPawnPiece;
const OwnedNonKingPiece = piecesModule.OwnedNonKingPiece;
const Piece = piecesModule.Piece;
const ZobristHash = zobristModule.ZobristHash;
const BASE_ZOBRIST_KEY = zobristModule.BASE_ZOBRIST_KEY;

pub const FullMoveCount = u8;

pub const HalfMoveCount = struct {
    const MAX_HALFMOVES_CLOCK = comptime_int(100);
    halfmoves: u8 = 0,

    pub fn increment(self: HalfMoveCount) HalfMoveCount {
        return HalfMoveCount{ .halfmoves = self.halfmoves +| 1 };
    }

    pub fn decrement(self: HalfMoveCount) HalfMoveCount {
        return HalfMoveCount{ .halfmoves = self.halfmoves -| 1 };
    }

    pub fn init(halfmoves: u8) HalfMoveCount {
        return HalfMoveCount{ .halfmoves = halfmoves };
    }

    pub fn reset() HalfMoveCount {
        return HalfMoveCount{ .halfmoves = 0 };
    }

    pub fn fromFullmoves(fullmoves: FullMoveCount, side_to_move: Player) HalfMoveCount {
        return fullmoves * 2 + @intFromBool(side_to_move == Player.black);
    }

    pub fn hasExceededMoveClock(self: HalfMoveCount) bool {
        return self.halfmoves >= MAX_HALFMOVES_CLOCK;
    }
};

/// The state of the game board.
pub const PieceArrangement = struct {
    /// The bitboard for each side, where each bit represents the presence of a piece.
    side_masks: ByPlayer(Bitboard) = ByPlayer(Bitboard).initFill(Bitboard.empty),
    /// The bitboard for each piece type, where each bit represents the presence of a piece.
    piece_masks: ByNonKingPiece(Bitboard) = ByNonKingPiece(Bitboard).initFill(Bitboard.empty),
    /// The squares of the kings for each side.
    kings: ByPlayer(Square),

    /// Create a new `PieceArrangement` with a king square for each side.
    pub fn init(king_squares: ByPlayer(Square)) PieceArrangement {
        return PieceArrangement{
            // The side masks are initialized with the king squares since they are the only pieces on the board.
            .side_masks = std.EnumArray(Player, Bitboard).init(.{
                .white = king_squares.get(.white).toBitboard(),
                .black = king_squares.get(.black).toBitboard(),
            }),
            .kings = king_squares,
        };
    }

    /// Add a non-king piece to the board on a given square
    pub fn addPiece(self: PieceArrangement, comptime piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        // TODO: Enable this assertion once we've raised the eval branch quota for the compiler.
        // std.debug.assert(self.sideOn(square) == null and self.pieceOn(square) == null);

        var result = self;
        const square_bitboard = square.toBitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalOr(square_bitboard));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalOr(square_bitboard));
        return result;
    }

    /// Remove a non-king piece from the board from a given square
    pub fn removePiece(self: PieceArrangement, comptime piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        std.debug.assert(self.sideOn(square).? == piece.player and self.pieceOn(square).? == piece.piece.toPiece());

        var result = self;
        const square_bitboard = square.toBitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalAnd(square_bitboard.logicalNot()));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalAnd(square_bitboard.logicalNot()));
        return result;
    }

    /// Move a piece from one square to another
    pub fn movePiece(self: PieceArrangement, comptime piece: OwnedPiece, from_square: Square, to_square: Square) PieceArrangement {
        std.debug.assert(self.sideOn(from_square).? == piece.player and self.pieceOn(from_square).? == piece.piece);
        std.debug.assert(self.sideOn(to_square) == null and self.pieceOn(to_square) == null);

        var result = self;
        const from_square_bitboard = from_square.toBitboard();
        const to_square_bitboard = to_square.toBitboard();
        const from_to_square_bitboard = from_square_bitboard.logicalOr(to_square_bitboard);
        const non_king_piece = NonKingPiece.fromPiece(piece.piece) catch null;

        if (non_king_piece) |p| {
            result.piece_masks.set(p, result.piece_masks.get(p).logicalXor(from_to_square_bitboard));
        } else {
            result.kings.set(piece.player, to_square);
        }

        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalXor(from_to_square_bitboard));
        return result;
    }

    /// Get the piece on a given square if any
    pub fn pieceOn(self: PieceArrangement, square: Square) ?Piece {
        // Check if piece is a king
        inline for (comptime std.enums.values(Player)) |player| {
            if (self.kings.get(player) == square) {
                return .king;
            }
        }

        // Check if piece is a non-king piece
        const square_mask = square.toBitboard();
        inline for (comptime std.enums.values(NonKingPiece)) |piece| {
            if (!self.piece_masks.get(piece).logicalAnd(square_mask).isEmpty()) {
                return piece.toPiece();
            }
        }

        // No piece on square
        return null;
    }

    /// Get the side of the piece on a given square if any
    pub fn sideOn(self: PieceArrangement, square: Square) ?Player {
        // Check each side mask for the square
        const square_mask = square.toBitboard();
        inline for (comptime std.enums.values(Player)) |player| {
            if (!self.side_masks.get(player).logicalAnd(square_mask).isEmpty()) {
                return player;
            }
        }

        // No piece on square
        return null;
    }

    /// Get the `OwnedPiece` (piece and side) on a given square if any
    pub fn sidedPieceOn(self: PieceArrangement, square: Square) ?OwnedPiece {
        if (self.pieceOn(square)) |piece| {
            return .{ .piece = piece, .player = self.sideOn(square).? };
        }

        // No piece on square
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
        const ep_square = if (en_passant_file) |*ep_file| ep_file.epSquareFor(side_to_move) else null;
        return PersistentBoardState{
            .key = ZobristHash.init(side_to_move, king_squares, rights, ep_square),
            // todo: compute move generation masks
            .checkers = Bitboard.empty,
            .pinners = ByPlayer(Bitboard).initFill(Bitboard.empty),
            .blockers = ByPlayer(Bitboard).initFill(Bitboard.empty),
            .check_squares = ByNonKingPiece(Bitboard).initFill(Bitboard.empty),
        };
    }

    fn addPiece(self: PersistentBoardState, comptime piece: OwnedNonKingPiece, square: Square) PersistentBoardState {
        var result = self;
        result.key = result.key.toggle_piece(piece.to_owned(), square);
        // todo: update move generation masks?
        return result;
    }

    fn removePiece(self: PersistentBoardState, comptime piece: OwnedNonKingPiece, square: Square) PersistentBoardState {
        var result = self;
        result.key = result.key.toggle_piece(piece.to_owned(), square);
        // todo: update move generation masks?
        return result;
    }

    fn movePiece(self: PersistentBoardState, comptime piece: OwnedPiece, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;
        result.key = result.key.move(piece, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    // TODO: replace OwnedPiece with OwnedNonPawnPiece
    pub fn quietMove(self: PersistentBoardState, comptime piece: OwnedNonPawnPiece, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;

        result.key = result.key.move(piece, from_square, to_square);
        result.halfmove_clock = result.halfmove_clock.increment();
        // todo: update move generation masks
        return result;
    }

    pub fn pawnPush(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square) PersistentBoardState {
        var result = self;
        const forward = comptime BoardDirection.forward(side_to_move);
        const to_square = from_square.shift(forward).?;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.move(.{ .player = side_to_move, .piece = .pawn }, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    pub fn doublePawnPush(self: PersistentBoardState, comptime side_to_move: Player, comptime en_passant_file: File) PersistentBoardState {
        var result = self;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.doublePawnPush(side_to_move, en_passant_file);
        // todo: update move generation masks
        return result;
    }

    pub fn enPassantCapture(self: PersistentBoardState, comptime side_to_move: Player, comptime en_passant_file: File, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.enPassantCapture(side_to_move, en_passant_file, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    pub fn kingMoveWithRights(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self.movePiece(.{ .player = side_to_move, .piece = .king }, from_square, to_square);
        result.key = result.key.toggle_rights(side_to_move, CastleRights.forSide(side_to_move));
        // todo: update move generation masks
        return result;
    }

    pub fn kingMove(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square, to_square: Square) PersistentBoardState {
        return self.movePiece(.{ .player = side_to_move, .piece = .king }, from_square, to_square);
        // todo: update move generation masks
    }

    // todo: add other move types, including those that reset the halfmove clock
    // todo: consider adding moves that could be used to more optimally compute move generation masks (capture?)
};

pub fn Board(comptime side_to_move: Player, comptime en_passant_file: ?File, comptime rights: CastleRights) type {
    return struct {
        /// The arrangement of pieces on the board.
        pieces: PieceArrangement,
        /// The number of halfmoves since the last pawn move or capture.
        halfmove_count: HalfMoveCount = HalfMoveCount.reset(),
        /// The current state of the board (for maintaining move generation and similar functionality)
        state: PersistentBoardState,

        /// Create a new board with the given king positions.
        fn withKings(king_squares: ByPlayer(Square)) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = PieceArrangement.init(king_squares),
                .state = PersistentBoardState.init(side_to_move, en_passant_file, rights, king_squares),
            };
        }

        /// Add a piece to the board.
        fn addPiece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedNonKingPiece, square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.addPiece(piece, square),
                .state = self.state.addPiece(piece, square),
            };
        }

        /// Remove a piece from the board.
        fn removePiece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedNonKingPiece, square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.removePiece(piece, square),
                .state = self.state.removePiece(piece, square),
            };
        }

        /// Move a piece on the board.
        fn movePiece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedPiece, from_square: Square, to_square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.movePiece(piece, from_square, to_square),
                .state = self.state.movePiece(piece, from_square, to_square),
            };
        }

        /// Get the mask of squares attacked by the attacking side.
        pub fn attacked(_: Board(side_to_move, en_passant_file, rights)) Bitboard {
            @compileError("TODO: implement attacked mask");
        }

        /// Finish applying a move to the board and goto the next player's turn.
        fn next(self: Board(side_to_move, en_passant_file, rights), comptime next_en_passant_file: ?File, comptime next_rights: CastleRights) Board(side_to_move.opposite(), next_en_passant_file, next_rights) {
            return Board(side_to_move.opposite(), next_en_passant_file, next_rights){
                .pieces = self.pieces,
                .state = self.state,
                .halfmove_count = self.halfmove_count,
            };
        }

        fn incrementHalfmoveCount(self: Board(side_to_move, en_passant_file, rights)) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces,
                .state = self.state,
                .halfmove_count = self.halfmove_count.increment(),
            };
        }

        pub fn player(_: Board(side_to_move, en_passant_file, rights)) Player {
            return side_to_move;
        }

        /// Get the square that can be captured en passant if any.
        pub fn epSquare(_: Board(side_to_move, en_passant_file, rights)) ?EnPassantSquare {
            return if (en_passant_file) |*ep_file| ep_file.epSquareFor(side_to_move.opposite()) else null;
        }

        /// Get the piece on the given square if any.
        pub fn pieceOn(self: Board(side_to_move, en_passant_file, rights), square: Square) ?Piece {
            return self.pieces.pieceOn(square);
        }

        /// Get the player of the piece on the given square if any.
        pub fn sideOn(self: Board(side_to_move, en_passant_file, rights), square: Square) ?Player {
            return self.pieces.sideOn(square);
        }

        /// Get the `OwnedPiece` (piece and player) on a given square, if any.
        pub fn sidedPieceOn(self: Board(side_to_move, en_passant_file, rights), square: Square) ?OwnedPiece {
            return self.pieces.sidedPieceOn(square);
        }

        pub fn pawnPush(self: Board(side_to_move, en_passant_file, rights), from_square: Square) Board(side_to_move.opposite(), null, rights) {
            const to_square = from_square.shift(BoardDirection.forward(side_to_move)).?;
            var updated_board = self.movePiece(.{ .piece = .pawn, .player = side_to_move }, from_square, to_square);
            updated_board.state = updated_board.state.pawnPush(side_to_move, from_square);

            return updated_board.next(null, rights);
        }

        pub fn doublePawnPush(self: Board(side_to_move, en_passant_file, rights), comptime file: File) Board(side_to_move.opposite(), file, rights) {
            const next_ep_square = file.epSquareFor(side_to_move).to_square();
            const from_square = next_ep_square.shift(BoardDirection.forward(side_to_move).opposite()).?;
            const to_square = next_ep_square.shift(BoardDirection.forward(side_to_move)).?;
            var updated_board = self.movePiece(.{ .piece = .pawn, .player = side_to_move }, from_square, to_square);
            updated_board.state = updated_board.state.doublePawnPush(side_to_move, file);

            return updated_board.next(file, rights);
        }

        pub fn enPassantCapture(self: Board(side_to_move, en_passant_file, rights), from_file: File) Board(side_to_move.opposite(), null, rights) {
            const to_square = self.epSquare().?.to_square();
            const from_square = from_file.epSquareFor(side_to_move.opposite()).to_square().shift(BoardDirection.forward(side_to_move.opposite())).?;
            const captured_pawn_square = to_square.shift(BoardDirection.forward(side_to_move.opposite())).?;
            var updated_board = self.removePiece(.{ .piece = .pawn, .player = side_to_move.opposite() }, captured_pawn_square)
                .movePiece(.{ .piece = .pawn, .player = side_to_move }, from_square, to_square);
            updated_board.state = updated_board.state.enPassantCapture(side_to_move, en_passant_file.?, from_square, to_square);
            return updated_board.next(null, rights);
        }

        pub fn kingMove(self: Board(side_to_move, en_passant_file, rights), from_square: Square, to_square: Square) Board(side_to_move.opposite(), null, rights.kingMove(side_to_move)) {
            var updated_board = self.movePiece(.{ .piece = .king, .player = side_to_move }, from_square, to_square);
            updated_board.state = updated_board.state.kingMove(side_to_move, from_square, to_square);
            return updated_board.next(null, rights.kingMove(side_to_move));
        }

        pub fn debugPrint(self: Board(side_to_move, en_passant_file, rights)) void {
            const line = "  +---+---+---+---+---+---+---+---+";
            std.debug.print("    A   B   C   D   E   F   G   H\n{s}\n", .{line});
            inline for (comptime .{ Rank._8, Rank._7, Rank._6, Rank._5, Rank._4, Rank._3, Rank._2, Rank._1 }) |rank| {
                std.debug.print("{d} ", .{@as(u8, @intFromEnum(rank)) + 1});
                inline for (comptime std.enums.values(File)) |file| {
                    const square = Square.fromFileAndRank(file, rank);
                    const piece = self.sidedPieceOn(square);
                    const piece_char = if (piece) |p| @tagName(p.piece)[0] else ' ';
                    const sided_piece_char = if (piece) |p| if (p.player == .white) std.ascii.toUpper(piece_char) else std.ascii.toLower(piece_char) else piece_char;
                    std.debug.print("| {c} ", .{sided_piece_char});
                }
                switch (rank) {
                    ._8 => std.debug.print("|\n{s}\n", .{line}),
                    ._7 => std.debug.print("|    Side to Move: {s}\n{s}   Castle Rights: {s}\n", .{
                        @tagName(side_to_move),
                        line,
                        rights.getUciString(),
                    }),
                    ._6 => std.debug.print("|      En Passant: {s}\n{s}  Halfmove Clock: {d}\n", .{ if (self.epSquare()) |sq| @tagName(sq) else "-", line, self.state.halfmove_clock.halfmoves }),
                    ._5 => std.debug.print("|\n{s}    Zobrist Hash: 0x{X}\n", .{ line, self.state.key.key }),
                    ._4 => std.debug.print("|   Checkers Mask: 0x{X}\n{s}\n", .{ self.state.checkers.mask, line }),
                    ._3 => std.debug.print("|\n{s}\n", .{line}),
                    ._2 => std.debug.print("|\n{s}\n", .{line}),
                    ._1 => std.debug.print("|\n{s}\n", .{line}),
                }
            }
        }
    };
}

pub const DefaultBoard = Board(.white, null, CastleRights.initFill(true))
    .withKings(std.EnumArray(Player, Square).init(.{ .white = .e1, .black = .e8 }))
    .addPiece(.{ .piece = .pawn, .player = .white }, .a2)
    .addPiece(.{ .piece = .pawn, .player = .white }, .b2)
    .addPiece(.{ .piece = .pawn, .player = .white }, .c2)
    .addPiece(.{ .piece = .pawn, .player = .white }, .d2)
    .addPiece(.{ .piece = .pawn, .player = .white }, .e2)
    .addPiece(.{ .piece = .pawn, .player = .white }, .f2)
    .addPiece(.{ .piece = .pawn, .player = .white }, .g2)
    .addPiece(.{ .piece = .pawn, .player = .white }, .h2)
    .addPiece(.{ .piece = .rook, .player = .white }, .a1)
    .addPiece(.{ .piece = .knight, .player = .white }, .b1)
    .addPiece(.{ .piece = .bishop, .player = .white }, .c1)
    .addPiece(.{ .piece = .queen, .player = .white }, .d1)
    .addPiece(.{ .piece = .bishop, .player = .white }, .f1)
    .addPiece(.{ .piece = .knight, .player = .white }, .g1)
    .addPiece(.{ .piece = .rook, .player = .white }, .h1)
// black pieces
    .addPiece(.{ .piece = .pawn, .player = .black }, .a7)
    .addPiece(.{ .piece = .pawn, .player = .black }, .b7)
    .addPiece(.{ .piece = .pawn, .player = .black }, .c7)
    .addPiece(.{ .piece = .pawn, .player = .black }, .d7)
    .addPiece(.{ .piece = .pawn, .player = .black }, .e7)
    .addPiece(.{ .piece = .pawn, .player = .black }, .f7)
    .addPiece(.{ .piece = .pawn, .player = .black }, .g7)
    .addPiece(.{ .piece = .pawn, .player = .black }, .h7)
    .addPiece(.{ .piece = .rook, .player = .black }, .a8)
    .addPiece(.{ .piece = .knight, .player = .black }, .b8)
    .addPiece(.{ .piece = .bishop, .player = .black }, .c8)
    .addPiece(.{ .piece = .queen, .player = .black }, .d8)
    .addPiece(.{ .piece = .bishop, .player = .black }, .f8)
    .addPiece(.{ .piece = .knight, .player = .black }, .g8)
    .addPiece(.{ .piece = .rook, .player = .black }, .h8);

test "some basic moves on the start board" {
    const board = DefaultBoard;

    try std.testing.expectEqual(board.pieces.pieceOn(.e2), .pawn);
    try std.testing.expectEqual(board.pieces.pieceOn(.e3), null);
    try std.testing.expectEqualDeep(board.halfmove_count, HalfMoveCount.reset());
    const pawn_e2e3 = board.pawnPush(.e2);
    try std.testing.expectEqual(pawn_e2e3.pieces.pieceOn(.e2), null);
    try std.testing.expectEqual(pawn_e2e3.pieces.pieceOn(.e3), .pawn);
    try std.testing.expectEqual(pawn_e2e3.halfmove_count, HalfMoveCount.reset());

    try std.testing.expectEqual(pawn_e2e3.pieces.pieceOn(.e7), .pawn);
    try std.testing.expectEqual(pawn_e2e3.pieces.pieceOn(.e5), null);
    const pawn_e7e5 = pawn_e2e3.doublePawnPush(.e);
    try std.testing.expectEqual(pawn_e7e5.pieces.pieceOn(.e7), null);
    try std.testing.expectEqual(pawn_e7e5.pieces.pieceOn(.e5), .pawn);
    try std.testing.expectEqual(pawn_e7e5.halfmove_count, HalfMoveCount.reset());
    try std.testing.expectEqual(pawn_e7e5.epSquare(), .e6);
}
