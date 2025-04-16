
const std = @import("std");
const Bitboard = @import("./bitboard.zig").Bitboard;
const Player = @import("./player.zig").Player;
const ByPlayer = @import("./player.zig").ByPlayer;
const ByNonKingPiece = @import("./piece.zig").ByNonKingPiece;
const OwnedNonKingPiece = @import("./piece.zig").OwnedNonKingPiece;
const OwnedPiece = @import("./piece.zig").OwnedPiece;
const NonKingPiece = @import("./piece.zig").NonKingPiece;
const Piece = @import("./piece.zig").Piece;
const Square = @import("./square.zig").Square;

/// The state of the pieces on the game board as a snapshot.
/// Contains the information obtained from only looking at a single legal chess position knowing nothing about how it got there.
///
/// So this is missing significant board state: castle rights, en passant squares, side to move, etc.
pub const PieceArrangement = struct {
    /// The bitboard for each side, where each bit represents the presence of a piece.
    side_masks: ByPlayer(Bitboard) = ByPlayer(Bitboard).initFill(Bitboard.empty),
    /// The bitboard for each piece type, where each bit represents the presence of a piece.
    piece_masks: ByNonKingPiece(Bitboard) = ByNonKingPiece(Bitboard).initFill(Bitboard.empty),
    /// The squares of the kings for each side.
    kings: ByPlayer(Square),

    /// Create a new `PieceArrangement` with a king square for each side.
    pub fn init(king_squares: ByPlayer(Square)) PieceArrangement {
        std.debug.assert(king_squares.get(.white) != king_squares.get(.black));

        return PieceArrangement{
            // The side masks are initialized with the king squares since they are the only pieces on the board.
            .side_masks = ByPlayer(Bitboard).init(.{
                .white = king_squares.get(.white).toBitboard(),
                .black = king_squares.get(.black).toBitboard(),
            }),
            .kings = king_squares,
        };
    }

    test init {
        const king_squares = ByPlayer(Square).init(.{
            .white = Square.a1,
            .black = Square.a8,
        });
        const arrangement = PieceArrangement.init(king_squares);
        try std.testing.expectEqual(arrangement.kings.get(.white), Square.a1);
        try std.testing.expectEqual(arrangement.kings.get(.black), Square.a8);
        try std.testing.expectEqual(arrangement.side_masks.get(.white), Square.a1.toBitboard());
        try std.testing.expectEqual(arrangement.side_masks.get(.black), Square.a8.toBitboard());
    }

    /// Add a non-king piece to the board on a given square
    pub fn addPiece(self: PieceArrangement, piece: OwnedNonKingPiece, square: Square) PieceArrangement {
        std.debug.assert(self.sideOn(square) == null and self.pieceOn(square) == null);

        var result = self;
        const square_bitboard = square.toBitboard();
        result.side_masks.set(piece.player, result.side_masks.get(piece.player).logicalOr(square_bitboard));
        result.piece_masks.set(piece.piece, result.piece_masks.get(piece.piece).logicalOr(square_bitboard));
        return result;
    }

    test addPiece {
        const king_squares = ByPlayer(Square).init(.{
            .white = Square.e1,
            .black = Square.e8,
        });
        const target_square = Square.b2;
        var arrangement = PieceArrangement.init(king_squares);
        arrangement = arrangement.addPiece(.{ .player = .white, .piece = NonKingPiece.rook }, target_square);
        try std.testing.expectEqual(arrangement.pieceOn(target_square), NonKingPiece.rook.toPiece());
        try std.testing.expectEqual(arrangement.sideOn(target_square), .white);
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

    test removePiece {
        const king_squares = ByPlayer(Square).init(.{
            .white = Square.e1,
            .black = Square.e8,
        });
        inline for (comptime .{Square.a1, Square.a4, Square.a8, Square.h1, Square.h8, Square.e4, Square.e5, Square.g7}) |target_square| {
            inline for (comptime std.enums.values(NonKingPiece)) |piece| {
                inline for (comptime std.enums.values(Player)) |player| {
                    var arrangement = PieceArrangement.init(king_squares);
                    arrangement = arrangement.addPiece(.{ .player = player, .piece = piece }, target_square);
                    arrangement = arrangement.removePiece(.{ .player = player, .piece = piece }, target_square);
                    try std.testing.expectEqual(arrangement.pieceOn(target_square), null);
                    try std.testing.expectEqual(arrangement.sideOn(target_square), null);
                }
            }
        }
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

    test movePiece {
        const king_squares = ByPlayer(Square).init(.{
            .white = Square.e1,
            .black = Square.e8,
        });
        const from_square = Square.b2;
        const to_square = Square.c3;
        var arrangement = PieceArrangement.init(king_squares);
        arrangement = arrangement.addPiece(.{ .player = .white, .piece = NonKingPiece.rook }, from_square);
        arrangement = arrangement.movePiece(.{ .player = .white, .piece = NonKingPiece.rook.toPiece() }, from_square, to_square);
        try std.testing.expectEqual(arrangement.pieceOn(to_square), NonKingPiece.rook.toPiece());
        try std.testing.expectEqual(arrangement.sideOn(to_square), .white);

        // Move each king
        arrangement = arrangement.movePiece(.{ .player = .white, .piece = Piece.king }, Square.e1, Square.e2);
        try std.testing.expectEqual(arrangement.pieceOn(Square.e2), Piece.king);
        try std.testing.expectEqual(arrangement.sideOn(Square.e2), .white);
        try std.testing.expectEqual(arrangement.pieceOn(Square.e1), null);
        try std.testing.expectEqual(arrangement.sideOn(Square.e1), null);
        arrangement = arrangement.movePiece(.{ .player = .black, .piece = Piece.king }, Square.e8, Square.e7);
        try std.testing.expectEqual(arrangement.pieceOn(Square.e7), Piece.king);
        try std.testing.expectEqual(arrangement.sideOn(Square.e7), .black);
        try std.testing.expectEqual(arrangement.pieceOn(Square.e8), null);
        try std.testing.expectEqual(arrangement.sideOn(Square.e8), null);
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

    test pieceOn {
        const king_squares = ByPlayer(Square).init(.{
            .white = Square.e1,
            .black = Square.e8,
        });
        inline for (comptime .{Square.a1, Square.a4, Square.a8, Square.h1, Square.h8, Square.e4, Square.e5, Square.g7}) |target_square| {
            inline for (comptime std.enums.values(NonKingPiece)) |piece| {
                inline for (comptime std.enums.values(Player)) |player| {
                    const arrangement = PieceArrangement.init(king_squares);
                    const piece_arrangement = arrangement.addPiece(.{ .player = player, .piece = piece }, target_square);
                    try std.testing.expectEqual(piece_arrangement.pieceOn(target_square), piece.toPiece());
                }
            }
        }
        // Test kings
        inline for (comptime std.enums.values(Player)) |player| {
            const arrangement = PieceArrangement.init(king_squares);
            try std.testing.expectEqual(arrangement.pieceOn(king_squares.get(player)), Piece.king);
        }
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

    test sideOn {
        const king_squares = ByPlayer(Square).init(.{
            .white = Square.e1,
            .black = Square.e8,
        });
        inline for (comptime .{Square.a1, Square.a4, Square.a8, Square.h1, Square.h8, Square.e4, Square.e5, Square.g7}) |target_square| {
            inline for (comptime std.enums.values(NonKingPiece)) |piece| {
                inline for (comptime std.enums.values(Player)) |player| {
                    const arrangement = PieceArrangement.init(king_squares);
                    const piece_arrangement = arrangement.addPiece(.{ .player = player, .piece = piece }, target_square);
                    try std.testing.expectEqual(piece_arrangement.sideOn(target_square), player);
                }
            }
        }
        // Test kings
        inline for (comptime std.enums.values(Player)) |player| {
            const arrangement = PieceArrangement.init(king_squares);
            try std.testing.expectEqual(arrangement.sideOn(king_squares.get(player)), player);
        }
    }

    /// Get the `OwnedPiece` (piece and side) on a given square if any
    pub fn sidedPieceOn(self: PieceArrangement, square: Square) ?OwnedPiece {
        if (self.pieceOn(square)) |piece| {
            return .{ .piece = piece, .player = self.sideOn(square).? };
        }

        // No piece on square
        return null;
    }

    test sidedPieceOn {
        const king_squares = ByPlayer(Square).init(.{
            .white = Square.e1,
            .black = Square.e8,
        });
        inline for (comptime .{Square.a1, Square.a4, Square.a8, Square.h1, Square.h8, Square.e4, Square.e5, Square.g7, Square.b2}) |target_square| {
            inline for (comptime std.enums.values(NonKingPiece)) |piece| {
                inline for (comptime std.enums.values(Player)) |player| {
                    const arrangement = PieceArrangement.init(king_squares);
                    const piece_arrangement = arrangement.addPiece(.{ .player = player, .piece = piece }, target_square);
                    try std.testing.expectEqual(piece_arrangement.sidedPieceOn(target_square), OwnedPiece{ .piece = piece.toPiece(), .player = player });
                }
            }
        }
    }
};