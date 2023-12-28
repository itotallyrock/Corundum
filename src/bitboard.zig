
pub const Bitboard = struct { mask: u64 };
pub const EmptyBitboard: Bitboard = Bitboard { .mask = 0 };
pub const A1Bitboard: Bitboard = Bitboard { .mask = 1 };