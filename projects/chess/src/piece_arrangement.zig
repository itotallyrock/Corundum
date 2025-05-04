const std = @import("std");

const Bitboard = @import("./bitboard.zig").Bitboard;
const ByNonKingPiece = @import("./piece.zig").ByNonKingPiece;
const OwnedNonKingPiece = @import("./piece.zig").OwnedNonKingPiece;
const OwnedPiece = @import("./piece.zig").OwnedPiece;
const NonKingPiece = @import("./piece.zig").NonKingPiece;
const Piece = @import("./piece.zig").Piece;
const PromotionPiece = @import("./piece.zig").PromotionPiece;
const NonPawnPiece = @import("./piece.zig").NonPawnPiece;
const Player = @import("./player.zig").Player;
const ByPlayer = @import("./player.zig").ByPlayer;
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

    /// Try to add a non-king piece to the board on a given square
    pub fn tryAddPiece(self: PieceArrangement, piece: OwnedNonKingPiece, square: Square) !PieceArrangement {
        if (self.sideOn(square) != null or self.pieceOn(square) != null) {
            return error.SquareOccupied;
        }
        return self.addPiece(piece, square);
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
        inline for (comptime .{ Square.a1, Square.a4, Square.a8, Square.h1, Square.h8, Square.e4, Square.e5, Square.g7 }) |target_square| {
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
        inline for (comptime .{ Square.a1, Square.a4, Square.a8, Square.h1, Square.h8, Square.e4, Square.e5, Square.g7 }) |target_square| {
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
        inline for (comptime .{ Square.a1, Square.a4, Square.a8, Square.h1, Square.h8, Square.e4, Square.e5, Square.g7 }) |target_square| {
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
        inline for (comptime .{ Square.a1, Square.a4, Square.a8, Square.h1, Square.h8, Square.e4, Square.e5, Square.g7, Square.b2 }) |target_square| {
            inline for (comptime std.enums.values(NonKingPiece)) |piece| {
                inline for (comptime std.enums.values(Player)) |player| {
                    const arrangement = PieceArrangement.init(king_squares);
                    const piece_arrangement = arrangement.addPiece(.{ .player = player, .piece = piece }, target_square);
                    try std.testing.expectEqual(piece_arrangement.sidedPieceOn(target_square), OwnedPiece{ .piece = piece.toPiece(), .player = player });
                }
            }
        }
    }

    /// Get the mask of all pieces on the board (both sides)
    pub fn occupied(self: PieceArrangement) Bitboard {
        return self.side_masks.get(.white).logicalOr(self.side_masks.get(.black));
    }

    test occupied {
        const king_squares = ByPlayer(Square).init(.{
            .white = Square.e1,
            .black = Square.e8,
        });
        var arrangement = PieceArrangement.init(king_squares);
        try std.testing.expectEqual(arrangement.occupied(), Square.e1.toBitboard().logicalOr(Square.e8.toBitboard()));
        arrangement = arrangement.addPiece(.{ .player = .white, .piece = NonKingPiece.rook }, Square.b2);
        try std.testing.expectEqual(arrangement.occupied(), Square.e1.toBitboard().logicalOr(Square.e8.toBitboard()).logicalOr(Square.b2.toBitboard()));
        arrangement = arrangement.addPiece(.{ .player = .black, .piece = NonKingPiece.rook }, Square.c3);
        try std.testing.expectEqual(arrangement.occupied(), Square.e1.toBitboard().logicalOr(Square.e8.toBitboard()).logicalOr(Square.b2.toBitboard()).logicalOr(Square.c3.toBitboard()));
    }

    /// Get a mask of all attackers to a given square (both sides)
    /// This is used for checking if a square is attacked by any piece
    /// Comptime include_kings is used to determine if king attacks should be included
    pub fn attackersTo(self: PieceArrangement, square: Square, comptime include_kings: bool) Bitboard {
        return self.attackersToWithOccupied(square, self.occupied(), include_kings);
    }

    /// Get a mask of all attackers to a given square (both sides) for a given occupied mask
    pub fn attackersToWithOccupied(self: PieceArrangement, square: Square, occupied_mask: Bitboard, comptime include_kings: bool) Bitboard {
        const from_mask = square.toBitboard();
        var result = Bitboard.empty;

        // Add attacks for non-pawn & non-king pieces
        inline for (comptime std.enums.values(PromotionPiece)) |piece| {
            const piece_mask = self.piece_masks.get(NonKingPiece.fromPiece(piece.toPiece()) catch unreachable);
            const piece_attacks_from_square = from_mask.attacks(NonPawnPiece.fromPiece(piece.toPiece()) catch unreachable, occupied_mask);
            const piece_attacks = piece_mask.logicalAnd(piece_attacks_from_square);
            result = result.logicalOr(piece_attacks);
        }

        // Add pawn attacks separately (since pawn moves are perspective based)
        inline for (comptime std.enums.values(Player)) |player| {
            const pawns_mask = self.piece_masks.get(.pawn).logicalAnd(self.side_masks.get(player));
            const pawn_attacks_from_square = from_mask.pawnAttacks(player.opposite());
            const pawn_attacks = pawns_mask.logicalAnd(pawn_attacks_from_square);
            result = result.logicalOr(pawn_attacks);
        }

        // Sometimes we don't care about the king attacks (like when checking for check since king can't give check)
        if (include_kings) {
            inline for (comptime std.enums.values(Player)) |player| {
                const king_mask = self.kings.get(player).toBitboard();
                const king_attacks_from_square = from_mask.attacks(.king, occupied_mask);
                const king_attacks = king_mask.logicalAnd(king_attacks_from_square);
                result = result.logicalOr(king_attacks);
            }
        }

        return result;
    }

    test attackersToWithOccupied {
        var arrangement = PieceArrangement.init(.init(.{
            .white = Square.c1,
            .black = Square.e8,
        }))
            .addPiece(.{ .player = .white, .piece = NonKingPiece.rook }, Square.b2)
            .addPiece(.{ .player = .black, .piece = NonKingPiece.bishop }, Square.c3)
            .addPiece(.{ .player = .black, .piece = NonKingPiece.rook }, Square.b5);
        const occupied_mask = arrangement.occupied();
        try std.testing.expectEqual(Bitboard.initInt(0x200040000), arrangement.attackersToWithOccupied(Square.b2, occupied_mask, false));
        try std.testing.expectEqual(Bitboard.initInt(0x200040004), arrangement.attackersToWithOccupied(Square.b2, occupied_mask, true));
    }
};
