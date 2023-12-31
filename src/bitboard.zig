
const Square = @import("square.zig").Square;

pub const Bitboard = struct {
    pub const Empty = Bitboard { .mask = 0 };
    pub const A1 = Bitboard { .mask = 1 };
    mask: u64 = 0,

    pub fn logicalOr(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard { .mask = self.mask | other.mask };
    }

    pub fn logicalAnd(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard { .mask = self.mask & other.mask };
    }

    pub fn logicalXor(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard { .mask = self.mask ^ other.mask };
    }

    pub fn logicalNot(self: Bitboard) Bitboard {
        return Bitboard { .mask = ~self.mask };
    }

    pub fn isEmpty(self: Bitboard) bool {
        return self.mask == Empty.mask;
    }

    pub fn num_squares(self: Bitboard) u6 {
        return @popCount(self.mask);
    }

    pub fn pop_square(self: *Bitboard) ?Square {
        if (self == Empty) {
            return null;
        }
        const square_offset = @ctz(self.mask);
        const square: Square = @enumFromInt(square_offset);
        self.mask ^= square.to_bitboard();

        return square;
    }
};