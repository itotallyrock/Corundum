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
const Direction = directionsModule.Direction;
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

    pub fn from_fullmoves(fullmoves: FullMoveCount, side_to_move: Player) HalfMoveCount {
        return fullmoves * 2 + @intFromBool(side_to_move == Player.black);
    }

    pub fn has_exceeded_move_clock(self: HalfMoveCount) bool {
        return self.halfmoves >= MAX_HALFMOVES_CLOCK;
    }
};

/// The state of the game board.
pub const PieceArrangement = struct {
    /// The bitboard for each side, where each bit represents the presence of a piece.
    side_masks: ByPlayer(Bitboard) = ByPlayer(Bitboard).initFill(Bitboard.Empty),
    /// The bitboard for each piece type, where each bit represents the presence of a piece.
    piece_masks: ByNonKingPiece(Bitboard) = ByNonKingPiece(Bitboard).initFill(Bitboard.Empty),
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
    pub fn add_piece(self: PieceArrangement, comptime piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        // TODO: Enable this assertion once we've raised the eval branch quota for the compiler.
        // std.debug.assert(self.side_on(square) == null and self.piece_on(square) == null);

        var result = self;
        const square_bitboard = square.toBitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalOr(square_bitboard));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalOr(square_bitboard));
        return result;
    }

    /// Remove a non-king piece from the board from a given square
    pub fn remove_piece(self: PieceArrangement, comptime piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        std.debug.assert(self.side_on(square).? == piece.player and self.piece_on(square).? == piece.piece.to_piece());

        var result = self;
        const square_bitboard = square.toBitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalAnd(square_bitboard.logicalNot()));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalAnd(square_bitboard.logicalNot()));
        return result;
    }

    /// Move a piece from one square to another
    pub fn move_piece(self: PieceArrangement, comptime piece: OwnedPiece, from_square: Square, to_square: Square) PieceArrangement {
        std.debug.assert(self.side_on(from_square).? == piece.player and self.piece_on(from_square).? == piece.piece);
        std.debug.assert(self.side_on(to_square) == null and self.piece_on(to_square) == null);

        var result = self;
        const from_square_bitboard = from_square.toBitboard();
        const to_square_bitboard = to_square.toBitboard();
        const from_to_square_bitboard = from_square_bitboard.logicalOr(to_square_bitboard);
        const non_king_piece = NonKingPiece.from_piece(piece.piece) catch null;

        if (non_king_piece) |p| {
            result.piece_masks.set(p, result.piece_masks.get(p).logicalXor(from_to_square_bitboard));
        } else {
            result.kings.set(piece.player, to_square);
        }

        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalXor(from_to_square_bitboard));
        return result;
    }

    /// Get the piece on a given square if any
    pub fn piece_on(self: PieceArrangement, square: Square) ?Piece {
        // Check if piece is a king
        inline for (comptime std.enums.values(Player)) |player| {
            if (self.kings.get(player) == square) {
                return .King;
            }
        }

        // Check if piece is a non-king piece
        const square_mask = square.toBitboard();
        inline for (comptime std.enums.values(NonKingPiece)) |piece| {
            if (!self.piece_masks.get(piece).logicalAnd(square_mask).isEmpty()) {
                return piece.to_piece();
            }
        }

        // No piece on square
        return null;
    }

    /// Get the side of the piece on a given square if any
    pub fn side_on(self: PieceArrangement, square: Square) ?Player {
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
    pub fn sided_piece_on(self: PieceArrangement, square: Square) ?OwnedPiece {
        if (self.piece_on(square)) |piece| {
            return .{ .piece = piece, .player = self.side_on(square).? };
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
        var result = self;

        result.key = result.key.move(piece, from_square, to_square);
        result.halfmove_clock = result.halfmove_clock.increment();
        // todo: update move generation masks
        return result;
    }

    pub fn pawn_push(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square) PersistentBoardState {
        var result = self;
        const forward = comptime Direction.forward(side_to_move);
        const to_square = from_square.shift(forward).?;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.move(.{ .player = side_to_move, .piece = .Pawn }, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    pub fn double_pawn_push(self: PersistentBoardState, comptime side_to_move: Player, comptime en_passant_file: File) PersistentBoardState {
        var result = self;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.double_pawn_push(side_to_move, en_passant_file);
        // todo: update move generation masks
        return result;
    }

    pub fn en_passant_capture(self: PersistentBoardState, comptime side_to_move: Player, comptime en_passant_file: File, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;
        result.halfmove_clock = HalfMoveCount.reset();
        result.key = result.key.en_passant_capture(side_to_move, en_passant_file, from_square, to_square);
        // todo: update move generation masks
        return result;
    }

    pub fn king_move_with_rights(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self.move_piece(.{ .player = side_to_move, .piece = .King }, from_square, to_square);
        result.key = result.key.toggle_rights(side_to_move, CastleRights.forSide(side_to_move));
        // todo: update move generation masks
        return result;
    }

    pub fn king_move(self: PersistentBoardState, comptime side_to_move: Player, from_square: Square, to_square: Square) PersistentBoardState {
        return self.move_piece(.{ .player = side_to_move, .piece = .King }, from_square, to_square);
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
        fn with_kings(king_squares: ByPlayer(Square)) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = PieceArrangement.init(king_squares),
                .state = PersistentBoardState.init(side_to_move, en_passant_file, rights, king_squares),
            };
        }

        /// Add a piece to the board.
        fn add_piece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedNonKingPiece, square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.add_piece(piece, square),
                .state = self.state.add_piece(piece, square),
            };
        }

        /// Remove a piece from the board.
        fn remove_piece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedNonKingPiece, square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.remove_piece(piece, square),
                .state = self.state.remove_piece(piece, square),
            };
        }

        /// Move a piece on the board.
        fn move_piece(self: Board(side_to_move, en_passant_file, rights), comptime piece: OwnedPiece, from_square: Square, to_square: Square) Board(side_to_move, en_passant_file, rights) {
            return Board(side_to_move, en_passant_file, rights){
                .pieces = self.pieces.move_piece(piece, from_square, to_square),
                .state = self.state.move_piece(piece, from_square, to_square),
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

        fn increment_halfmove_count(self: Board(side_to_move, en_passant_file, rights)) Board(side_to_move, en_passant_file, rights) {
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
        pub fn ep_square(_: Board(side_to_move, en_passant_file, rights)) ?EnPassantSquare {
            return if (en_passant_file) |*ep_file| ep_file.epSquareFor(side_to_move.opposite()) else null;
        }

        /// Get the piece on the given square if any.
        pub fn piece_on(self: Board(side_to_move, en_passant_file, rights), square: Square) ?Piece {
            return self.pieces.piece_on(square);
        }

        /// Get the player of the piece on the given square if any.
        pub fn side_on(self: Board(side_to_move, en_passant_file, rights), square: Square) ?Player {
            return self.pieces.side_on(square);
        }

        /// Get the `OwnedPiece` (piece and player) on a given square, if any.
        pub fn sided_piece_on(self: Board(side_to_move, en_passant_file, rights), square: Square) ?OwnedPiece {
            return self.pieces.sided_piece_on(square);
        }

        pub fn pawn_push(self: Board(side_to_move, en_passant_file, rights), from_square: Square) Board(side_to_move.opposite(), null, rights) {
            const to_square = from_square.shift(Direction.forward(side_to_move)).?;
            var updated_board = self.move_piece(.{ .piece = .Pawn, .player = side_to_move }, from_square, to_square);
            updated_board.state = updated_board.state.pawn_push(side_to_move, from_square);

            return updated_board.next(null, rights);
        }

        pub fn double_pawn_push(self: Board(side_to_move, en_passant_file, rights), comptime file: File) Board(side_to_move.opposite(), file, rights) {
            const next_ep_square = file.epSquareFor(side_to_move).to_square();
            const from_square = next_ep_square.shift(Direction.forward(side_to_move).opposite()).?;
            const to_square = next_ep_square.shift(Direction.forward(side_to_move)).?;
            var updated_board = self.move_piece(.{ .piece = .Pawn, .player = side_to_move }, from_square, to_square);
            updated_board.state = updated_board.state.double_pawn_push(side_to_move, file);

            return updated_board.next(file, rights);
        }

        pub fn en_passant_capture(self: Board(side_to_move, en_passant_file, rights), from_file: File) Board(side_to_move.opposite(), null, rights) {
            const to_square = self.ep_square().?.to_square();
            const from_square = from_file.epSquareFor(side_to_move.opposite()).to_square().shift(Direction.forward(side_to_move.opposite())).?;
            const captured_pawn_square = to_square.shift(Direction.forward(side_to_move.opposite())).?;
            var updated_board = self.remove_piece(.{ .piece = .Pawn, .player = side_to_move.opposite() }, captured_pawn_square)
                .move_piece(.{ .piece = .Pawn, .player = side_to_move }, from_square, to_square);
            updated_board.state = updated_board.state.en_passant_capture(side_to_move, en_passant_file.?, from_square, to_square);
            return updated_board.next(null, rights);
        }

        pub fn king_move(self: Board(side_to_move, en_passant_file, rights), from_square: Square, to_square: Square) Board(side_to_move.opposite(), null, rights.kingMove(side_to_move)) {
            var updated_board = self.move_piece(.{ .piece = .King, .player = side_to_move }, from_square, to_square);
            updated_board.state = updated_board.state.king_move(side_to_move, from_square, to_square);
            return updated_board.next(null, rights.kingMove(side_to_move));
        }

        pub fn debug_print(self: Board(side_to_move, en_passant_file, rights)) void {
            const line = "  +---+---+---+---+---+---+---+---+";
            std.debug.print("    A   B   C   D   E   F   G   H\n{s}\n", .{line});
            inline for (comptime .{ Rank._8, Rank._7, Rank._6, Rank._5, Rank._4, Rank._3, Rank._2, Rank._1 }) |rank| {
                std.debug.print("{d} ", .{@as(u8, @intFromEnum(rank)) + 1});
                inline for (comptime std.enums.values(File)) |file| {
                    const square = Square.fromFileAndRank(file, rank);
                    const piece = self.sided_piece_on(square);
                    const pieceChar = if (piece) |p| @tagName(p.piece)[0] else ' ';
                    const sidedPieceChar = if (piece) |p| if (p.player == .white) std.ascii.toUpper(pieceChar) else std.ascii.toLower(pieceChar) else pieceChar;
                    std.debug.print("| {c} ", .{sidedPieceChar});
                }
                switch (rank) {
                    ._8 => std.debug.print("|\n{s}\n", .{line}),
                    ._7 => std.debug.print("|    Side to Move: {s}\n{s}   Castle Rights: {s}\n", .{
                        @tagName(side_to_move),
                        line,
                        rights.getUciString(),
                    }),
                    ._6 => std.debug.print("|      En Passant: {s}\n{s}  Halfmove Clock: {d}\n", .{ if (self.ep_square()) |sq| @tagName(sq) else "-", line, self.state.halfmove_clock.halfmoves }),
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
    .with_kings(std.EnumArray(Player, Square).init(.{ .white = .E1, .black = .E8 }))
    .add_piece(.{ .piece = .Pawn, .player = .white }, .A2)
    .add_piece(.{ .piece = .Pawn, .player = .white }, .B2)
    .add_piece(.{ .piece = .Pawn, .player = .white }, .C2)
    .add_piece(.{ .piece = .Pawn, .player = .white }, .D2)
    .add_piece(.{ .piece = .Pawn, .player = .white }, .E2)
    .add_piece(.{ .piece = .Pawn, .player = .white }, .F2)
    .add_piece(.{ .piece = .Pawn, .player = .white }, .G2)
    .add_piece(.{ .piece = .Pawn, .player = .white }, .H2)
    .add_piece(.{ .piece = .Rook, .player = .white }, .A1)
    .add_piece(.{ .piece = .Knight, .player = .white }, .B1)
    .add_piece(.{ .piece = .Bishop, .player = .white }, .C1)
    .add_piece(.{ .piece = .Queen, .player = .white }, .D1)
    .add_piece(.{ .piece = .Bishop, .player = .white }, .F1)
    .add_piece(.{ .piece = .Knight, .player = .white }, .G1)
    .add_piece(.{ .piece = .Rook, .player = .white }, .H1)
// black pieces
    .add_piece(.{ .piece = .Pawn, .player = .black }, .A7)
    .add_piece(.{ .piece = .Pawn, .player = .black }, .B7)
    .add_piece(.{ .piece = .Pawn, .player = .black }, .C7)
    .add_piece(.{ .piece = .Pawn, .player = .black }, .D7)
    .add_piece(.{ .piece = .Pawn, .player = .black }, .E7)
    .add_piece(.{ .piece = .Pawn, .player = .black }, .F7)
    .add_piece(.{ .piece = .Pawn, .player = .black }, .G7)
    .add_piece(.{ .piece = .Pawn, .player = .black }, .H7)
    .add_piece(.{ .piece = .Rook, .player = .black }, .A8)
    .add_piece(.{ .piece = .Knight, .player = .black }, .B8)
    .add_piece(.{ .piece = .Bishop, .player = .black }, .C8)
    .add_piece(.{ .piece = .Queen, .player = .black }, .D8)
    .add_piece(.{ .piece = .Bishop, .player = .black }, .F8)
    .add_piece(.{ .piece = .Knight, .player = .black }, .G8)
    .add_piece(.{ .piece = .Rook, .player = .black }, .H8);

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
