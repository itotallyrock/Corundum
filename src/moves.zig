
/// Move types that should have their own comptime functional impl for Zobirst to make/unmake them optimally (and safely/legally)
pub const ZobristMoveType = enum {
    Quiet,
    DoublePawnPush,
    Capture,
    Castle,
    Promotion,
    PromotionCapture,
};

/// Move types that should have their own comptime functional impl for a Board to make/unmake them optimally (and safely/legally)
pub const MakeMoveType = enum {
    Quiet,
    PawnPush,
    DoublePawnPush,
    Capture,
    EnPassantCapture,
    Castle,
    Promotion,
    PromotionCapture,

    pub fn to_zobrist_move_type(self: MakeMoveType) ZobristMoveType {
        return switch (self) {
            .Quiet, .pawnPush => .Quiet,
            .DoublePawnPush => .DoublePawnPush,
            .Capture, .EnPassantCapture => .Capture,
            .Castle => .Castle,
            .Promotion => .Promotion,
            .PromotionCapture => .PromotionCapture,
        };
    }
};

const todo = i32;
pub const BoardMove = union(enum) {
    quiet: todo,
    pawnCapture: todo,
    pawnPush: todo,
    doublePawnPush: todo,
    capture: todo,
    enPassantCapture: todo,
    castle: todo,
    promotion: todo,
    promotionCapture: todo,
};