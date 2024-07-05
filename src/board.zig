const std = @import("std");
const movesModule = @import("moves.zig");
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
const BoardMove = movesModule.BoardMove;
const LegalMove = movesModule.LegalMove;
const BoardStatusMove = movesModule.BoardStatusMove;
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
    pub fn addPiece(self: PieceArrangement, piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        // TODO: Enable this assertion once we've raised the eval branch quota for the compiler.
        // std.debug.assert(self.sideOn(square) == null and self.pieceOn(square) == null);

        var result = self;
        const square_bitboard = square.toBitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalOr(square_bitboard));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalOr(square_bitboard));
        return result;
    }

    /// Remove a non-king piece from the board from a given square
    pub fn removePiece(self: PieceArrangement, piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        std.debug.assert(self.sideOn(square).? == piece.player and self.pieceOn(square).? == piece.piece.toPiece());

        var result = self;
        const square_bitboard = square.toBitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalAnd(square_bitboard.logicalNot()));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalAnd(square_bitboard.logicalNot()));
        return result;
    }

    /// Move a piece from one square to another
    pub fn movePiece(self: PieceArrangement, piece: OwnedPiece, from_square: Square, to_square: Square) PieceArrangement {
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

    // TODO: Write unit tests for PieceArrangement
};

const PersistentBoardState = struct {
    // Non-recoverable state
    /// The Zobrist hash key for the current board state
    key: ZobristHash,
    /// The 50 move limit rule counter
    halfmove_clock: u8 = 0,
    /// The current castle rights for both players
    castle_rights: CastleRights,
    /// The square behind the pawn that just moved two squares forward, if any
    en_passant_square: ?EnPassantSquare,

    // Move generation state to avoid recomputing
    /// Bitboard of pieces that are currently giving check to the side to move
    checkers: Bitboard,
    /// Bitboard of pieces that are currently pinning pieces to the king of each side
    pinners: ByPlayer(Bitboard),
    /// Bitboard of pieces that are currently blocking check to the king of each side
    blockers: ByPlayer(Bitboard),
    /// Bitboards of squares that would give check if a given non-king piece were to move to them
    check_squares: ByNonKingPiece(Bitboard),

    pub fn init(comptime side_to_move: Player, ep_square: ?EnPassantSquare, castle_rights: CastleRights, king_squares: ByPlayer(Square)) PersistentBoardState {
        return PersistentBoardState{
            .key = ZobristHash.init(side_to_move, king_squares, castle_rights, ep_square),
            .castle_rights = castle_rights,
            .en_passant_square = ep_square,
            // todo: compute move generation masks
            .checkers = Bitboard.empty,
            .pinners = ByPlayer(Bitboard).initFill(Bitboard.empty),
            .blockers = ByPlayer(Bitboard).initFill(Bitboard.empty),
            .check_squares = ByNonKingPiece(Bitboard).initFill(Bitboard.empty),
        };
    }

    fn addPiece(self: PersistentBoardState, piece: OwnedNonKingPiece, square: Square) PersistentBoardState {
        var result = self;
        result.key = result.key.toggle_piece(piece.to_owned(), square);
        // todo: update move generation masks?
        return result;
    }

    fn removePiece(self: PersistentBoardState, piece: OwnedNonKingPiece, square: Square) PersistentBoardState {
        var result = self;
        result.key = result.key.toggle_piece(piece.to_owned(), square);
        return result;
    }

    fn movePiece(self: PersistentBoardState, piece: OwnedPiece, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;
        result.key = result.key.move(piece, from_square, to_square);
        // todo: update move generation masks?
        return result;
    }

    pub fn quietMove(self: PersistentBoardState, piece: OwnedNonPawnPiece, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;

        // Move the piece in the key
        result.key = result.key.move(piece, from_square, to_square);

        // Post move updates
        result.halfmove_clock = result.halfmove_clock.increment();
        result.en_passant_square = null;
        // todo: update move generation masks

        return result;
    }

    pub fn pawnPush(self: PersistentBoardState, side_to_move: Player, from_square: Square) PersistentBoardState {
        var result = self;

        // Move the piece in the key
        const to_square = from_square.shift(BoardDirection.forward(side_to_move)).?;
        result.key = result.key.move(.{ .player = side_to_move, .piece = .pawn }, from_square, to_square);

        // Post move updates
        result.halfmove_clock = 0;
        result.en_passant_square = null;
        // todo: update move generation masks

        return result;
    }

    pub fn doublePawnPush(self: PersistentBoardState, side_to_move: Player, en_passant_file: File) PersistentBoardState {
        var result = self;

        // Move the piece in the key
        result.key = result.key.doublePawnPush(side_to_move, en_passant_file);

        // Post move updates
        result.halfmove_clock = 0;
        result.en_passant_square = en_passant_file.epSquareFor(side_to_move);
        // todo: update move generation masks

        return result;
    }

    pub fn enPassantCapture(self: PersistentBoardState, side_to_move: Player, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;

        // Move the piece in the key
        result.key = result.key.enPassantCapture(side_to_move, self.en_passant_square.?, from_square, to_square);

        // Post move updates
        result.en_passant_square = null;
        result.halfmove_clock = 0;
        // todo: update move generation masks

        return result;
    }

    pub fn kingMove(self: PersistentBoardState, side_to_move: Player, from_square: Square, to_square: Square) PersistentBoardState {
        var result = self;

        // Move the piece in the key
        result.key = result.key.move(.{ .player = side_to_move, .piece = .king }, from_square, to_square);

        // Remove any existing rights (from rights and key)
        inline for (comptime std.enums.values(CastleDirection)) |castle_direction| {
            if (self.castle_rights.hasRights(side_to_move, castle_direction)) {
                result.key = result.key.toggle_castle_right(side_to_move, castle_direction);
                result.castle_rights = result.castle_rights.removeRight(side_to_move, castle_direction);
            }
        }

        // Post move updates
        result.en_passant_square = null;
        result.halfmove_clock = result.halfmove_clock + 1;
        // todo: update move generation masks

        return result;
    }

    // todo: add other move types, including those that reset the halfmove clock
    // todo: consider adding moves that could be used to more optimally compute move generation masks (capture?)
};

// TODO: Remove these comptime values and simply use them as fields & pass them as arguments to the constructor
pub const Board = struct {
    const Self = @This();
    pub const start_position = Board
        .init(.white, CastleRights.all, std.EnumArray(Player, Square).init(.{ .white = .e1, .black = .e8 }), null)
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

    /// The player whose turn it is to move.
    side_to_move: Player,
    /// The number of halfmoves since the last pawn move or capture.
    plies_played: u16 = 0,
    /// The arrangement of pieces on the board.
    pieces: PieceArrangement,
    /// The current state of the board (for maintaining move generation and similar functionality)
    state: PersistentBoardState,

    /// Create a new board with the given king positions.
    fn init(comptime starting_side: Player, comptime starting_rights: CastleRights, king_squares: ByPlayer(Square), en_passant_square: ?EnPassantSquare) Self {
        return Self{
            .side_to_move = starting_side,
            .pieces = PieceArrangement.init(king_squares),
            .state = PersistentBoardState.init(starting_side, en_passant_square, starting_rights, king_squares),
        };
    }

    /// Add a piece to the board.
    fn addPiece(self: Self, piece: OwnedNonKingPiece, square: Square) Self {
        return Self{
            .side_to_move = self.side_to_move,
            .plies_played = self.plies_played,
            .pieces = self.pieces.addPiece(piece, square),
            .state = self.state.addPiece(piece, square),
        };
    }

    /// Remove a piece from the board.
    fn removePiece(self: Self, piece: OwnedNonKingPiece, square: Square) Self {
        return Self{
            .side_to_move = self.side_to_move,
            .plies_played = self.plies_played,
            .pieces = self.pieces.removePiece(piece, square),
            .state = self.state.removePiece(piece, square),
        };
    }

    /// Move a piece on the board.
    fn movePiece(self: Self, piece: OwnedPiece, from_square: Square, to_square: Square) Self {
        return Self{
            .side_to_move = self.side_to_move,
            .plies_played = self.plies_played,
            .pieces = self.pieces.movePiece(piece, from_square, to_square),
            .state = self.state.movePiece(piece, from_square, to_square),
        };
    }

    /// Get the mask of squares attacked by the attacking side.
    pub fn attacked(_: Self) Bitboard {
        @panic("TODO: implement attacked mask");
    }

    fn make_move(self: Self, move: BoardMove) Self {
        _ = move;
        return self;
        // switch (board_status_move) {
        //     .quiet => @panic("TODO: implement make_move for quiet moves"),
        //     .castle => @panic("TODO: implement make_move for castling"),
        //     .castle_rook_capture_or_move => @panic("TODO: implement make_move for castle rook capture or move"),
        //     .double_pawn_push => |file| return self.doublePawnPush(file),
        // }
    }

    test make_move {
        var board = Board.start_position;
        board = board.make_move(.{ .pawn_push = .{ .from = .f2 } });
    }

    pub fn player(self: Self) Player {
        return self.side_to_move;
    }

    /// Get the square that can be captured en passant if any.
    pub fn epSquare(self: Self) ?EnPassantSquare {
        return self.state.en_passant_square;
    }

    /// Get the piece on the given square if any.
    pub fn pieceOn(self: Self, square: Square) ?Piece {
        return self.pieces.pieceOn(square);
    }

    /// Get the player of the piece on the given square if any.
    pub fn sideOn(self: Self, square: Square) ?Player {
        return self.pieces.sideOn(square);
    }

    /// Get the `OwnedPiece` (piece and player) on a given square, if any.
    pub fn sidedPieceOn(self: Self, square: Square) ?OwnedPiece {
        return self.pieces.sidedPieceOn(square);
    }

    pub fn pawnPush(self: Self, from_square: Square) Self {
        const to_square = from_square.shift(BoardDirection.forward(self.side_to_move)).?;
        var updated_board = self.movePiece(.{ .piece = .pawn, .player = self.side_to_move }, from_square, to_square);
        updated_board.state = updated_board.state.pawnPush(self.side_to_move, from_square);
        updated_board.side_to_move = self.side_to_move.opposite();
        updated_board.plies_played = updated_board.plies_played + 1;

        return updated_board;
    }

    pub fn doublePawnPush(self: Self, comptime file: File) Self {
        const next_ep_square = file.epSquareFor(self.side_to_move);
        const next_ep_square_square = next_ep_square.to_square();
        const from_square = next_ep_square_square.shift(BoardDirection.forward(self.side_to_move).opposite()).?;
        const to_square = next_ep_square_square.shift(BoardDirection.forward(self.side_to_move)).?;
        var updated_board = self.movePiece(.{ .piece = .pawn, .player = self.side_to_move }, from_square, to_square);
        updated_board.state = updated_board.state.doublePawnPush(self.side_to_move, file);
        updated_board.side_to_move = self.side_to_move.opposite();
        updated_board.plies_played = updated_board.plies_played + 1;

        return updated_board;
    }

    pub fn enPassantCapture(self: Self, from_file: File) Self {
        const to_square = self.epSquare().?.to_square();
        const from_square = from_file.epSquareFor(self.side_to_move.opposite()).to_square().shift(BoardDirection.forward(self.side_to_move.opposite())).?;
        const captured_pawn_square = to_square.shift(BoardDirection.forward(self.side_to_move.opposite())).?;
        var updated_board = self.removePiece(.{ .piece = .pawn, .player = self.side_to_move.opposite() }, captured_pawn_square)
            .movePiece(.{ .piece = .pawn, .player = self.side_to_move }, from_square, to_square);
        updated_board.state = updated_board.state.enPassantCapture(self.side_to_move, from_square, to_square);
        updated_board.side_to_move = self.side_to_move.opposite();
        updated_board.plies_played = updated_board.plies_played + 1;

        return updated_board;
    }

    pub fn kingMove(self: Self, from_square: Square, to_square: Square) Self {
        var updated_board = self.movePiece(.{ .piece = .king, .player = self.side_to_move }, from_square, to_square);
        updated_board.state = updated_board.state.kingMove(self.side_to_move, from_square, to_square);
        updated_board.side_to_move = self.side_to_move.opposite();
        updated_board.plies_played = updated_board.plies_played + 1;
        return updated_board;
    }

    pub fn debugPrint(self: Self) Self {
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
                    @tagName(self.side_to_move),
                    line,
                    self.state.castle_rights.getUciString(),
                }),
                ._6 => std.debug.print("|      En Passant: {s}\n{s}  Halfmove Clock: {d}\n", .{ if (self.epSquare()) |sq| @tagName(sq) else "-", line, self.state.halfmove_clock }),
                ._5 => std.debug.print("|\n{s}    Zobrist Hash: 0x{X}\n", .{ line, self.state.key.key }),
                ._4 => std.debug.print("|   Checkers Mask: 0x{X}\n{s}\n", .{ self.state.checkers.mask, line }),
                ._3 => std.debug.print("|\n{s}\n", .{line}),
                ._2 => std.debug.print("|\n{s}\n", .{line}),
                ._1 => std.debug.print("|\n{s}\n", .{line}),
            }
        }

        return self;
    }
};

test "some basic moves on the start board" {
    const board = Board.start_position;

    try std.testing.expectEqual(board.pieces.pieceOn(.e2), .pawn);
    try std.testing.expectEqual(board.pieces.pieceOn(.e3), null);
    try std.testing.expectEqual(board.plies_played, 0);
    try std.testing.expectEqualDeep(board.state.halfmove_clock, 0);
    const pawn_e2e3 = board.pawnPush(.e2);
    try std.testing.expectEqual(pawn_e2e3.pieces.pieceOn(.e2), null);
    try std.testing.expectEqual(pawn_e2e3.pieces.pieceOn(.e3), .pawn);
    try std.testing.expectEqual(pawn_e2e3.plies_played, 1);
    try std.testing.expectEqual(pawn_e2e3.state.halfmove_clock, 0);

    try std.testing.expectEqual(pawn_e2e3.pieces.pieceOn(.e7), .pawn);
    try std.testing.expectEqual(pawn_e2e3.pieces.pieceOn(.e5), null);
    const pawn_e7e5 = pawn_e2e3.doublePawnPush(.e);
    try std.testing.expectEqual(pawn_e7e5.pieces.pieceOn(.e7), null);
    try std.testing.expectEqual(pawn_e7e5.pieces.pieceOn(.e5), .pawn);
    try std.testing.expectEqual(pawn_e7e5.plies_played, 2);
    try std.testing.expectEqual(pawn_e7e5.state.halfmove_clock, 0);
    try std.testing.expectEqual(pawn_e7e5.epSquare(), .e6);
}
