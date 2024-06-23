const Square = @import("square.zig").Square;
const File = @import("square.zig").File;
const Piece = @import("pieces.zig").Piece;
const PromotionPiece = @import("pieces.zig").PromotionPiece;
const NonPawnPiece = @import("pieces.zig").NonPawnPiece;
const NonKingPiece = @import("pieces.zig").NonKingPiece;
const PawnAttackDirection = @import("directions.zig").PawnAttackDirection;
const CastleDirection = @import("castles.zig").CastleDirection;

/// A move to be made on the board
pub const BoardMove = union(enum) {
    /// A basic non-pawn move that doesn't capture any pieces
    quiet: struct {
        from: Square,
        to: Square,
        piece: NonPawnPiece,
    },
    /// A pawn move that captures a piece
    pawn_capture: struct {
        from: Square,
        direction: PawnAttackDirection,
        captured_piece: NonKingPiece,
    },
    /// A single pawn forward move that doesn't capture or promote
    pawn_push: struct {
        from: Square,
    },
    /// A double pawn forward move from the starting rank
    double_pawn_push: struct {
        file: File,
    },
    /// A capture move that doesn't involve a pawn
    capture: struct {
        from: Square,
        to: Square,
        piece: NonPawnPiece,
        captured_piece: NonKingPiece,
    },
    /// A move that involves a pawn capturing a pawn that just moved two squares by attacking the jumped square (en passant)
    en_passant_capture: struct {
        from_file: File,
    },
    /// A king and rook where the rook moves to the king's side and the king moves two squares towards the rook (castling)
    castle: struct {
        direction: CastleDirection,
    },
    /// A pawn move that promote it into a better piece
    promotion: struct {
        from_file: File,
        promoted_piece: PromotionPiece,
    },
    /// A pawn move that captures a piece and promotes it into a better piece
    promotion_capture: struct {
        from_file: File,
        capture_direction: PawnAttackDirection,
        captured_piece: NonKingPiece,
        promoted_piece: PromotionPiece,
    },
};
