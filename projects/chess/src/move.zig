const std = @import("std");

const CastleDirection = @import("./castle.zig").CastleDirection;
const CastleConfig = @import("./castle.zig").CastleConfig;
const PawnAttackDirection = @import("./direction.zig").PawnAttackDirection;
const RelativeDirection = @import("./direction.zig").RelativeDirection;
const Piece = @import("./piece.zig").Piece;
const PromotionPiece = @import("./piece.zig").PromotionPiece;
const NonPawnPiece = @import("./piece.zig").NonPawnPiece;
const NonKingPiece = @import("./piece.zig").NonKingPiece;
const Player = @import("./player.zig").Player;
const Square = @import("./square.zig").Square;
const EnPassantSquare = @import("./square.zig").EnPassantSquare;
const File = @import("./square.zig").File;
const Rank = @import("./square.zig").Rank;

/// A move to be made on the board
pub const BoardMove = union(enum) {
    /// A basic non-pawn move that doesn't capture any pieces
    quiet: struct {
        /// The square the piece moves from
        from: Square,
        /// The square the piece moves to
        to: Square,
        /// The piece that is moving
        piece: NonPawnPiece,
    },
    /// A pawn move that captures a piece
    pawn_capture: struct {
        const Self = @This();
        /// The ending square of the pawn
        to: Square,
        /// The direction the pawn captures in
        direction: PawnAttackDirection,
        /// The piece that was captured
        captured_piece: NonKingPiece,

        /// Get the square the pawn moved from
        pub fn from(self: Self, side_to_move: Player) Square {
            return self.from.shift(self.direction.toRelativeDirection().toDirection(side_to_move).opposite());
        }
    },
    /// A single pawn forward move that doesn't capture or promote
    pawn_push: struct {
        const Self = @This();
        /// The target square the pawn ends on
        to: Square,

        /// Get the square the pawn movedW from
        pub fn from(self: Self, side_to_move: Player) Square {
            return self.to.shift(RelativeDirection.backward.toDirection(side_to_move));
        }
    },
    /// A double pawn forward move from the starting rank
    double_pawn_push: struct {
        const Self = @This();
        /// The file the pawn starts from
        file: File,

        /// Get the square the pawn moves from
        pub fn from(self: Self, side_to_move: Player) Square {
            return Square.fromFileAndRank(self.file, Rank.pawnRank(side_to_move));
        }

        /// Get the en passant square
        pub fn en_passant_square(self: Self, side_to_move: Player) EnPassantSquare {
            return self.file.epSquareFor(side_to_move);
        }

        /// Get the square the pawn moves to
        pub fn to(self: Self, side_to_move: Player) Square {
            return Square.fromFileAndRank(self.file, Rank.doublePushedRank(side_to_move));
        }
    },
    /// A capture move that doesn't involve a pawn
    capture: struct {
        /// The square the piece moves from
        from: Square,
        /// The square the piece moves to
        to: Square,
        /// The piece that is moving
        piece: NonPawnPiece,
        /// The piece that was captured
        captured_piece: NonKingPiece,
    },
    /// A move that involves a pawn capturing a pawn that just moved two squares by attacking the jumped square (en passant)
    en_passant_capture: struct {
        const Self = @This();
        /// The file the pawn starts from
        from_file: File,

        /// Get the square the pawn moves from
        pub fn from(self: Self, side_to_move: Player) Square {
            return Square.fromFileAndRank(self.from_file, Rank.doublePushedRank(side_to_move.opposite()));
        }

        /// Get the square the pawn moves to
        pub fn to(self: Self, side_to_move: Player, en_passant_file: File) Square {
            std.debug.assert(en_passant_file.isAdjacent(self.from_file));
            return Square.fromFileAndRank(en_passant_file, Rank.epRankFor(side_to_move.opposite()));
        }

        /// Get the square the other sides pawn should be removed from
        pub fn captured_square(self: Self, side_to_move: Player, en_passant_file: File) Square {
            std.debug.assert(en_passant_file.isAdjacent(self.from_file));
            return Square.fromFileAndRank(en_passant_file, Rank.doublePushedRank(side_to_move.opposite()));
        }
    },
    /// A king and rook where the rook moves to the king's side and the king moves two squares towards the rook (castling)
    castle: struct {
        const Self = @This();
        /// The direction the king moves towards
        direction: CastleDirection,

        /// Get the square the rook moves from
        pub fn rookFrom(self: Self, side_to_move: Player, castle_config: CastleConfig) Square {
            return Square.fromFileAndRank(castle_config.startingRookFiles().get(self.casle_direction), Rank.backRank(side_to_move));
        }

        /// Get the square the rook moves to
        pub fn rookTo(self: Self, side_to_move: Player) Square {
            return Square.fromFileAndRank(File.castlingRookTargetFile(self.casle_direction), Rank.backRank(side_to_move));
        }

        /// Get the square the king moves from
        pub fn kingFrom(_: Self, side_to_move: Player, castle_config: CastleConfig) Square {
            return Square.fromFileAndRank(castle_config.startingKingFile, Rank.backRank(side_to_move));
        }

        /// Get the square the king moves to
        pub fn kingTo(self: Self, side_to_move: Player) Square {
            return Square.fromFileAndRank(File.castlingKingTargetFile(self.casle_direction), Rank.backRank(side_to_move));
        }
    },
    /// A pawn move that promote it into a better piece
    promotion: struct {
        const Self = @This();
        from_file: File,
        promoted_piece: PromotionPiece,

        /// Get the square the pawn moves from
        pub fn from(self: Self, side_to_move: Player) Square {
            return Square.fromFileAndRank(self.from_file, Rank.promotionFromRank(side_to_move));
        }

        /// Get the square the pawn moves to
        pub fn to(self: Self, side_to_move: Player) Square {
            return Square.fromFileAndRank(self.from_file, Rank.promotionTargetRank(side_to_move));
        }
    },
    /// A pawn move that captures a piece and promotes it into a better piece
    promotion_capture: struct {
        const Self = @This();
        from_file: File,
        capture_direction: PawnAttackDirection,
        captured_piece: NonKingPiece,
        promoted_piece: PromotionPiece,

        /// Get the square the pawn moves from
        pub fn from(self: Self, side_to_move: Player) Square {
            return Square.fromFileAndRank(self.from_file, Rank.promotionFromRank(side_to_move));
        }

        /// Get the square the pawn moves to
        pub fn to(self: Self, side_to_move: Player) Square {
            return self.from(side_to_move).shift(self.capture_direction.toRelativeDirection().toDirection(side_to_move));
        }
    },

    fn from(self: BoardMove, comptime side_to_move: Player, castle_config: CastleConfig) Square {
        return switch (self) {
            .quiet => |s| s.from,
            .pawn_capture => |s| s.from(side_to_move),
            .pawn_push => |s| s.from(side_to_move),
            .double_pawn_push => |s| s.from(side_to_move),
            .capture => |s| s.from,
            .en_passant_capture => |s| s.from(side_to_move),
            .castle => |s| s.kingFrom(side_to_move, castle_config),
            .promotion => |s| s.from(side_to_move),
            .promotion_capture => |s| s.from(side_to_move),
        };
    }

    pub fn to(self: BoardMove, comptime side_to_move: Player) Square {
        return switch (self) {
            .quiet => |s| s.to,
            .pawn_capture => |s| s.to,
            .pawn_push => |s| s.to,
            .double_pawn_push => |s| s.to(side_to_move),
            .capture => |s| s.to,
            .en_passant_capture => |s| s.to(side_to_move, s.from_file),
            .castle => |s| s.kingTo(side_to_move),
            .promotion => |s| s.to(side_to_move),
            .promotion_capture => |s| s.to(side_to_move),
        };
    }
};

test "size of BoardMove" {
    try std.testing.expectEqual(5, @sizeOf(BoardMove));
}
