
const Square = @import("square.zig").Square;

/// A board mask that represents a set of squares on a chess board.
/// The mask is a 64-bit integer where each bit represents a square on the board.
/// Bits set to 1 represent squares that are part of the set.
/// Bits set to 0 represent squares that are not part of the set.
pub const Bitboard = struct {
    /// An empty bitboard with no squares set.
    pub const Empty = Bitboard { .mask = 0 };
    /// A bitboard with all squares set.
    pub const All = Empty.logicalNot();
    /// A bitboard with only the A1 square set.
    pub const A1 = Bitboard { .mask = 1 };

    /// The underlying mask that represents the set of squares.
    mask: u64 = 0,

    /// Combine two bitboards using a logical OR operation.
    /// This operation sets all bits that are set in **either bitboard**.
    pub fn logicalOr(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard { .mask = self.mask | other.mask };
    }

    /// Combine two bitboards using a logical AND operation.
    /// This operation sets all bits that are set in **both bitboards**.
    pub fn logicalAnd(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard { .mask = self.mask & other.mask };
    }

    /// Combine two bitboards using a logical XOR operation.
    /// This operation sets all bits that are set in **either bitboard but not in both**.
    pub fn logicalXor(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard { .mask = self.mask ^ other.mask };
    }

    /// Inverse the bits of the bitboard.
    /// This operation sets all bits that are not set and unsets all bits that were previously set.
    pub fn logicalNot(self: Bitboard) Bitboard {
        return Bitboard { .mask = ~self.mask };
    }

    /// If the bitboard is contains no squares.
    pub fn isEmpty(self: Bitboard) bool {
        return self.mask == Empty.mask;
    }

    /// The number of squares set in the bitboard.
    pub fn num_squares(self: Bitboard) u6 {
        return @popCount(self.mask);
    }

    /// Get the lowest value `Square` (based on rank closest to 1, then by file cloest to A) and remove from the Bitboard (aka. remove the square from the set)
    /// Returns `null` if the bitboard is empty.
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
