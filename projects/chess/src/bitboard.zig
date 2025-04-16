const std = @import("std");
const Square = @import("./square.zig").Square;
const ByRank = @import("./square.zig").ByRank;
const ByFile = @import("./square.zig").ByFile;
const BoardDirection = @import("./direction.zig").BoardDirection;
const NonPawnPiece = @import("./piece.zig").NonPawnPiece;
const SlidingPieceRayDirections = @import("./direction.zig").SlidingPieceRayDirections;

/// A board mask that represents a set of squares on a chess board.
/// The mask is a 64-bit integer where each bit represents a square on the board.
/// Bits set to 1 represent squares that are part of the set.
/// Bits set to 0 represent squares that are not part of the set.
pub const Bitboard = struct {
    /// Essentially this is a u64, but we use a bit set to make it easier to work with and generic over any number of squares.
    const BitSet = std.bit_set.IntegerBitSet(std.enums.values(Square).len);
    /// Integer type used to represent a count of the number of squares in the bitboard.
    const SquareCount = std.meta.Int(.unsigned, std.math.log2(std.enums.values(Square).len) + 1);
    /// An empty bitboard with no squares set.
    pub const empty = Bitboard.initInt(0);
    /// A bitboard with all squares set.
    pub const all = empty.logicalNot();
    /// A bitboard with only the A1 square set.
    pub const a1 = Bitboard.initInt(1);

    /// Mask of each rank
    pub const ranks = ByRank(Bitboard).init(.{
        ._1 = Bitboard.initInt(0xFF),
        ._2 = Bitboard.initInt(0xFF00),
        ._3 = Bitboard.initInt(0x00FF_0000),
        ._4 = Bitboard.initInt(0xFF00_0000),
        ._5 = Bitboard.initInt(0x00FF_0000_0000),
        ._6 = Bitboard.initInt(0xFF00_0000_0000),
        ._7 = Bitboard.initInt(0x00FF_0000_0000_0000),
        ._8 = Bitboard.initInt(0xFF00_0000_0000_0000),
    });

    /// Mask of each file
    pub const files = ByFile(Bitboard).init(.{
        .a = Bitboard.initInt(0x0101_0101_0101_0101),
        .b = Bitboard.initInt(0x0202_0202_0202_0202),
        .c = Bitboard.initInt(0x0404_0404_0404_0404),
        .d = Bitboard.initInt(0x0808_0808_0808_0808),
        .e = Bitboard.initInt(0x1010_1010_1010_1010),
        .f = Bitboard.initInt(0x2020_2020_2020_2020),
        .g = Bitboard.initInt(0x4040_4040_4040_4040),
        .h = Bitboard.initInt(0x8080_8080_8080_8080),
    });

    /// The underlying mask that represents the set of squares.
    mask: BitSet = BitSet.initEmpty(),

    /// Create a new bitboard with the given integer mask.
    pub fn initInt(mask: BitSet.MaskInt) Bitboard {
        return Bitboard{ .mask = BitSet { .mask = mask } };
    }

    /// Combine two bitboards using a logical OR operation.
    /// This operation sets all bits that are set in **either bitboard**.
    pub fn logicalOr(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard{ .mask = self.mask.unionWith(other.mask) };
    }

    /// Combine two bitboards using a logical AND operation.
    /// This operation sets all bits that are set in **both bitboards**.
    pub fn logicalAnd(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard{ .mask = self.mask.intersectWith(other.mask) };
    }

    /// Combine two bitboards using a logical XOR operation.
    /// This operation sets all bits that are set in **either bitboard but not in both**.
    pub fn logicalXor(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard{ .mask = self.mask.xorWith(other.mask) };
    }

    /// Inverse the bits of the bitboard.
    /// This operation sets all bits that are not set and unsets all bits that were previously set.
    pub fn logicalNot(self: Bitboard) Bitboard {
        return Bitboard{ .mask = self.mask.complement() };
    }

    /// Shift the bits of the bitboard to the left or right.
    /// The `offset` is the number of squares to shift.
    /// Positive values shift left, negative values shift right.
    pub fn logicalShift(self: Bitboard, offset: i7) Bitboard {
        if (offset < 0) {
            return Bitboard.initInt(self.mask.mask >> @intCast(-offset));
        }
        return Bitboard.initInt(self.mask.mask << @intCast(offset));
    }

    /// If the bitboard is contains no squares.
    pub fn isEmpty(self: Bitboard) bool {
        return self.mask.eql(empty.mask);
    }

    /// The number of squares set in the bitboard.
    pub fn numSquares(self: Bitboard) SquareCount {
        return @intCast(self.mask.count());
    }

    /// Check if the bitboard contains a specific square.
    pub fn contains(self: Bitboard, square: Square) bool {
        return !self.logicalAnd(square.toBitboard()).isEmpty();
    }

    /// Get the lowest value `Square` (based on rank closest to 1, then by file cloest to A)
    /// Returns `null` if the bitboard is empty.
    pub fn getSquare(self: Bitboard) ?Square {
        if (self.mask.findFirstSet()) |first_set| {
            return @enumFromInt(first_set);
        }

        return null;
    }

    /// Get the lowest value `Square` (based on rank closest to 1, then by file cloest to A) and remove from the Bitboard (aka. remove the square from the set)
    /// Returns `null` if the bitboard is empty.
    pub fn popSquare(self: *Bitboard) ?Square {
        if (self.getSquare()) |square| {
            self.* = self.logicalXor(square.toBitboard());
            return square;
        }

        return null;
    }

    /// Shift all squares in the bitboard in a given direction.
    pub fn shift(self: Bitboard, direction: BoardDirection) Bitboard {
        const shiftable_squares_mask = switch (direction) {
            .north, .south => Bitboard.all,
            .east, .north_east, .south_east => Bitboard.files.get(.h).logicalNot(),
            .west, .north_west, .south_west => Bitboard.files.get(.a).logicalNot(),
        };
        return self
            .logicalAnd(shiftable_squares_mask)
            .logicalShift(@intFromEnum(direction));
    }

    /// Fill the bitboard in a given direction up to and including a non-empty square.
    pub fn occludedFill(self: Bitboard, occluded: Bitboard, direction: BoardDirection) Bitboard {
        if (self.isEmpty()) {
            return Bitboard.empty;
        }

        var filled = Bitboard.empty;
        var source = self;
        const empty_squares_mask = occluded.logicalNot().logicalAnd(switch (direction) {
            .north => ranks.get(._1).logicalNot(),
            .south => ranks.get(._8).logicalNot(),
            .east => files.get(.a).logicalNot(),
            .west => files.get(.h).logicalNot(),
            .north_west => ranks.get(._1).logicalOr(files.get(.h)).logicalNot(),
            .north_east => ranks.get(._8).logicalOr(files.get(.a)).logicalNot(),
            .south_east => ranks.get(._1).logicalOr(files.get(.h)).logicalNot(),
            .south_west => ranks.get(._8).logicalOr(files.get(.a)).logicalNot(),
        });

        while (!source.isEmpty()) {
            filled = filled.logicalOr(source);
            source = source.shift(direction).logicalAnd(empty_squares_mask);
        }

        return filled;
    }

    /// Get a single-direction ray attack from a starting bitboard
    fn rayAttack(self: Bitboard, occupied: Bitboard, direction: BoardDirection) Bitboard {
        return self.occludedFill(occupied, direction).shift(direction);
    }

    /// Get all 4 ray attacks from a starting bitboard
    /// When `direction` is `SlidingPieceRayDirections.cardinal`, the attacks are in the cardinal directions (north, south, east, west).
    /// When `direction` is `SlidingPieceRayDirections.diagonal`, the attacks are in the diagonal directions (north-east, north-west, south-east, south-west).
    pub fn rayAttacks(self: Bitboard, direction: SlidingPieceRayDirections, occupied: Bitboard) Bitboard {
        // TODO: Use comptime inspection to use pext/pdep based lookup at runtime
        if (direction == .cardinal) {
            return self.rayAttack(occupied, .north).logicalOr(self.rayAttack(occupied, .south)).logicalOr(self.rayAttack(occupied, .east)).logicalOr(self.rayAttack(occupied, .west));
        } else {
            return self.rayAttack(occupied, .north_west).logicalOr(self.rayAttack(occupied, .north_east)).logicalOr(self.rayAttack(occupied, .south_east)).logicalOr(self.rayAttack(occupied, .south_west));
        }
    }

    /// Get all squares attacked by a king from a starting bitboard
    fn kingAttacks(self: Bitboard) Bitboard {
        const eastWestAttacks = self.shift(.east).logicalOr(self.shift(.west));
        const kingRow = self.logicalOr(eastWestAttacks);

        return eastWestAttacks.logicalOr(kingRow.shift(.south)).logicalOr(kingRow.shift(.north));
    }

    /// Get all squares attacked by a knight from a starting bitboard
    fn knightAttacks(self: Bitboard) Bitboard {
        const right_one = self.logicalShift(1).logicalAnd(files.get(.a).logicalNot());
        const right_two = self.logicalShift(2).logicalAnd(files.get(.a).logicalOr(files.get(.b)).logicalNot());
        const left_one = self.logicalShift(-1).logicalAnd(files.get(.h).logicalNot()).logicalOr(right_one);
        const left_two = self.logicalShift(-2).logicalAnd(files.get(.h).logicalOr(files.get(.g)).logicalNot()).logicalOr(right_two);

        return left_one.logicalShift(16).logicalOr(left_one.logicalShift(-16)).logicalOr(left_two.logicalShift(8)).logicalOr(left_two.logicalShift(-8));
    }

    /// Get all squares attacked by a piece from a starting bitboard (an occluded bitboard is required for sliding pieces)
    pub fn attacks(self: Bitboard, piece: NonPawnPiece, occupied: Bitboard) Bitboard {
        switch (piece) {
            .king => return self.kingAttacks(),
            .knight => return self.knightAttacks(),
            .bishop => return self.rayAttacks(.diagonal, occupied),
            .rook => return self.rayAttacks(.cardinal, occupied),
            .queen => return self.rayAttacks(.cardinal, occupied).logicalOr(self.rayAttacks(.diagonal, occupied)),
        }
    }

    test isEmpty {
        try std.testing.expect(Bitboard.empty.isEmpty());
        try std.testing.expect(!Bitboard.all.isEmpty());
        try std.testing.expect(!(Bitboard.initInt(0x12300)).isEmpty());
        try std.testing.expect(!(Bitboard.initInt(0x8400400004000)).isEmpty());
        try std.testing.expect(!(Bitboard.initInt(0x22000812)).isEmpty());
    }

    test numSquares {
        try std.testing.expectEqual(Bitboard.empty.numSquares(), 0);
        try std.testing.expectEqual(Bitboard.all.numSquares(), 64);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).numSquares(), 4);
        try std.testing.expectEqual((Bitboard.initInt(0x8400400004000)).numSquares(), 4);
        try std.testing.expectEqual((Bitboard.initInt(0x22000812)).numSquares(), 5);
    }

    test contains {
        try std.testing.expect(!Bitboard.empty.contains(.a1));
        try std.testing.expect(!Bitboard.empty.contains(.h8));
        try std.testing.expect(!Bitboard.empty.contains(.d4));
        try std.testing.expect(!Bitboard.empty.contains(.g7));
        try std.testing.expect(Bitboard.all.contains(.a1));
        try std.testing.expect(Bitboard.all.contains(.h8));
        try std.testing.expect(Bitboard.all.contains(.d4));
        try std.testing.expect(Bitboard.all.contains(.g7));
        try std.testing.expect(!(Bitboard.initInt(0x12300)).contains(.a1));
        try std.testing.expect((Bitboard.initInt(0x12300)).contains(.a2));
        try std.testing.expect((Bitboard.initInt(0x12300)).contains(.a3));
        try std.testing.expect(!(Bitboard.initInt(0x12300)).contains(.g7));
        try std.testing.expect((Bitboard.initInt(0x8400400004000)).contains(.c5));
        try std.testing.expect((Bitboard.initInt(0x8400400004000)).contains(.d7));
        try std.testing.expect((Bitboard.initInt(0x8400400004000)).contains(.g6));
        try std.testing.expect((Bitboard.initInt(0x8400400004000)).contains(.g2));
        try std.testing.expect((Bitboard.initInt(0x400200000012200)).contains(.b2));
        try std.testing.expect((Bitboard.initInt(0x400200000012200)).contains(.f2));
        try std.testing.expect((Bitboard.initInt(0x400200000012200)).contains(.a3));
        try std.testing.expect((Bitboard.initInt(0x400200000012200)).contains(.f6));
        try std.testing.expect((Bitboard.initInt(0x400200000012200)).contains(.c8));
    }

    test ranks {
        const Rank = @import("square.zig").Rank;
        const File = @import("square.zig").File;
        inline for (comptime std.enums.values(Rank)) |rank| {
            const rankBitboard = Bitboard.ranks.get(rank);
            inline for (comptime std.enums.values(File)) |file| {
                const square = Square.fromFileAndRank(file, rank);
                try std.testing.expect(rankBitboard.contains(square));
            }
        }
    }

    test files {
        const Rank = @import("square.zig").Rank;
        const File = @import("square.zig").File;
        inline for (comptime std.enums.values(File)) |file| {
            const fileBitboard = Bitboard.files.get(file);
            inline for (comptime std.enums.values(Rank)) |rank| {
                const square = Square.fromFileAndRank(file, rank);
                try std.testing.expect(fileBitboard.contains(square));
            }
        }
    }

    test logicalAnd {
        try std.testing.expectEqual(Bitboard.empty.logicalAnd(Bitboard.empty), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.empty.logicalAnd(Bitboard.all), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.logicalAnd(Bitboard.empty), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.logicalAnd(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalAnd(Bitboard.all), Bitboard.initInt(0x12300));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalAnd(Bitboard.empty), Bitboard.empty);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalAnd(Bitboard.initInt(0x8400400004000)), Bitboard.empty);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalAnd(Bitboard.initInt(0x101010123010913)), Bitboard.initInt(0x10100));
    }

    test logicalOr {
        try std.testing.expectEqual(Bitboard.empty.logicalOr(Bitboard.empty), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.empty.logicalOr(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalOr(Bitboard.empty), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalOr(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalOr(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalOr(Bitboard.empty), Bitboard.initInt(0x12300));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalOr(Bitboard.initInt(0x8400400004000)), Bitboard.initInt(0x8400400016300));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalOr(Bitboard.initInt(0x101010123010913)), Bitboard.initInt(0x101010123012b13));
    }

    test logicalXor {
        try std.testing.expectEqual(Bitboard.empty.logicalXor(Bitboard.empty), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.empty.logicalXor(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalXor(Bitboard.empty), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalXor(Bitboard.all), Bitboard.empty);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalXor(Bitboard.all), Bitboard.initInt(0xfffffffffffedcff));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalXor(Bitboard.empty), Bitboard.initInt(0x12300));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalXor(Bitboard.initInt(0x8400400014000)), Bitboard.initInt(0x8400400006300));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalXor(Bitboard.initInt(0x101010123010913)), Bitboard.initInt(0x101010123002a13));
    }

    test logicalNot {
        try std.testing.expectEqual(Bitboard.empty.logicalNot(), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalNot(), Bitboard.empty);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalNot(), Bitboard.initInt(0xfffffffffffedcff));
        try std.testing.expectEqual((Bitboard.initInt(0x8400400004000)).logicalNot(), Bitboard.initInt(0xfff7bffbffffbfff));
        try std.testing.expectEqual((Bitboard.initInt(0x22000812)).logicalNot(), Bitboard.initInt(0xffffffffddfff7ed));
    }

    test logicalShift {
        // Left
        try std.testing.expectEqual(Bitboard.empty.logicalShift(0), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.logicalShift(0), Bitboard.all);
        try std.testing.expectEqual(Bitboard.empty.logicalShift(1), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.logicalShift(1), Bitboard.initInt(0xfffffffffffffffe));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(1), Bitboard.initInt(0x24600));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(2), Bitboard.initInt(0x48c00));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(3), Bitboard.initInt(0x91800));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(4), Bitboard.initInt(0x123000));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(5), Bitboard.initInt(0x246000));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(6), Bitboard.initInt(0x48c000));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(7), Bitboard.initInt(0x918000));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(8), Bitboard.initInt(0x1230000));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(9), Bitboard.initInt(0x2460000));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(10), Bitboard.initInt(0x48c0000));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(11), Bitboard.initInt(0x9180000));
        // Right
        try std.testing.expectEqual(Bitboard.empty.logicalShift(-1), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.logicalShift(-1), Bitboard.initInt(0x7fffffffffffffff));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-1), Bitboard.initInt(0x09180));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-2), Bitboard.initInt(0x048c0));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-3), Bitboard.initInt(0x02460));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-4), Bitboard.initInt(0x01230));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-5), Bitboard.initInt(0x00918));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-6), Bitboard.initInt(0x0048c));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-7), Bitboard.initInt(0x00246));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-8), Bitboard.initInt(0x00123));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-9), Bitboard.initInt(0x00091));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-10), Bitboard.initInt(0x00048));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).logicalShift(-11), Bitboard.initInt(0x00024));
    }

    test getSquare {
        try std.testing.expectEqual(Bitboard.empty.getSquare(), null);
        try std.testing.expectEqual(Bitboard.all.getSquare().?, .a1);
        try std.testing.expectEqual(Bitboard.a1.getSquare().?, .a1);
        try std.testing.expectEqual((Bitboard.initInt(0x400200000012200)).getSquare().?, .b2);
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).getSquare().?, .a2);
        try std.testing.expectEqual((Bitboard.initInt(0x100000000000000)).getSquare().?, .a8);
        try std.testing.expectEqual((Bitboard.initInt(0x8000000000000000)).getSquare().?, .h8);
        try std.testing.expectEqual((Bitboard.initInt(0x80)).getSquare().?, .h1);
        try std.testing.expectEqual((Bitboard.initInt(0x2000000400)).getSquare().?, .c2);
        try std.testing.expectEqual((Bitboard.initInt(0xfe00000000000000)).getSquare().?, .b8);
        try std.testing.expectEqual((Bitboard.initInt(0xfe28000000000000)).getSquare().?, .d7);
        try std.testing.expectEqual((Bitboard.initInt(0xf628022000000000)).getSquare().?, .f5);
    }

    test popSquare {
        var bb = Bitboard.initInt(0x400200000012200);
        try std.testing.expectEqual(bb.popSquare().?, .b2);
        try std.testing.expectEqual(bb.popSquare().?, .f2);
        try std.testing.expectEqual(bb.popSquare().?, .a3);
        try std.testing.expectEqual(bb.popSquare().?, .f6);
        try std.testing.expectEqual(bb.popSquare().?, .c8);
        try std.testing.expectEqual(bb.popSquare(), null);
    }

    test shift {
        try std.testing.expectEqual(Bitboard.empty.shift(.north), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.shift(.north), Bitboard.initInt(0xffffffffffffff00));
        try std.testing.expectEqual(Bitboard.empty.shift(.south), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.shift(.south), Bitboard.initInt(0xffffffffffffff));
        try std.testing.expectEqual(Bitboard.empty.shift(.east), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.shift(.east), Bitboard.initInt(0xfefefefefefefefe));
        try std.testing.expectEqual(Bitboard.empty.shift(.west), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.shift(.west), Bitboard.initInt(0x7f7f7f7f7f7f7f7f));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).shift(.north), Bitboard.initInt(0x1230000));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).shift(.south), Bitboard.initInt(0x123));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).shift(.east), Bitboard.initInt(0x24600));
        try std.testing.expectEqual((Bitboard.initInt(0x12300)).shift(.west), Bitboard.initInt(0x1100));
        try std.testing.expectEqual((Bitboard.initInt(0x8001d00400002208)).shift(.north_east), Bitboard.initInt(0x2a0080000441000));
        try std.testing.expectEqual((Bitboard.initInt(0x8001d00400002208)).shift(.north_west), Bitboard.initInt(0x68020000110400));
        try std.testing.expectEqual((Bitboard.initInt(0x8001d00400002208)).shift(.south_east), Bitboard.initInt(0x2a008000044));
        try std.testing.expectEqual((Bitboard.initInt(0x8001d00400002208)).shift(.south_west), Bitboard.initInt(0x40006802000011));
        // from re-design
        try std.testing.expectEqualDeep(Bitboard.initInt(0x040A_1024_4088_0000), (Bitboard.initInt(0x0304_0A10_2440_8800)).shift(.north));
        try std.testing.expectEqualDeep(Bitboard.initInt(0xFFFF_FFFF_FFFF_FF00), (Bitboard.initInt(0xFFFF_FFFF_FFFF_FFFF)).shift(.north));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).shift(.north));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0003_040A_1024_4088), (Bitboard.initInt(0x0304_0A10_2440_8800)).shift(.south));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x00FF_FFFF_FFFF_FFFF), (Bitboard.initInt(0xFFFF_FFFF_FFFF_FFFF)).shift(.south));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).shift(.south));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0608_1420_4880_1000), (Bitboard.initInt(0x0304_0A10_2440_8800)).shift(.east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0xFEFE_FEFE_FEFE_FEFE), (Bitboard.initInt(0xFFFF_FFFF_FFFF_FFFF)).shift(.east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).shift(.east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0508_1220_4400), (Bitboard.initInt(0x0304_0A10_2440_8800)).shift(.west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x7F7F_7F7F_7F7F_7F7F), (Bitboard.initInt(0xFFFF_FFFF_FFFF_FFFF)).shift(.west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).shift(.west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0814_2048_8010_0000), (Bitboard.initInt(0x0304_0A10_2440_8800)).shift(.north_east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0xFEFE_FEFE_FEFE_FE00), (Bitboard.initInt(0xFFFF_FFFF_FFFF_FFFF)).shift(.north_east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).shift(.north_east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0205_0812_2044_0000), (Bitboard.initInt(0x0304_0A10_2440_8800)).shift(.north_west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x7F7F_7F7F_7F7F_7F00), (Bitboard.initInt(0xFFFF_FFFF_FFFF_FFFF)).shift(.north_west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).shift(.north_west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0006_0814_2048_8010), (Bitboard.initInt(0x0304_0A10_2440_8800)).shift(.south_east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x00FE_FEFE_FEFE_FEFE), (Bitboard.initInt(0xFFFF_FFFF_FFFF_FFFF)).shift(.south_east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).shift(.south_east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0001_0205_0812_2044), (Bitboard.initInt(0x0304_0A10_2440_8800)).shift(.south_west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x007F_7F7F_7F7F_7F7F), (Bitboard.initInt(0xFFFF_FFFF_FFFF_FFFF)).shift(.south_west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).shift(.south_west));
    }

    test rayAttack {
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0200), Square.a1.toBitboard().rayAttack(Bitboard.empty, .north_east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x100), Square.a1.toBitboard().rayAttack(Bitboard.initInt(0xffff), .north));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8000), Square.h1.toBitboard().rayAttack(Bitboard.initInt(0xffff), .north));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x1010_1010_0000_0000), Square.e4.toBitboard().rayAttack(Square.e4.toBitboard(), .north));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0010_1010), Square.e4.toBitboard().rayAttack(Square.e4.toBitboard(), .south));
        try std.testing.expectEqualDeep(Bitboard.initInt(0xE000_0000), Square.e4.toBitboard().rayAttack(Square.e4.toBitboard(), .east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0F00_0000), Square.e4.toBitboard().rayAttack(Square.e4.toBitboard(), .west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0080_4020_0000_0000), Square.e4.toBitboard().rayAttack(Square.e4.toBitboard(), .north_east));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x80402), Square.e4.toBitboard().rayAttack(Square.e4.toBitboard(), .south_west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_0000_0000), Square.e4.toBitboard().rayAttack(Square.e4.toBitboard(), .north_west));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0020_4080), Square.e4.toBitboard().rayAttack(Square.e4.toBitboard(), .south_east));
    }

    test rayAttacks {
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0101_0101_0101_01FE), (Bitboard.initInt(0x1)).rayAttacks(.cardinal, Bitboard.initInt(0x1)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8080_8080_8080_807F), (Bitboard.initInt(0x80)).rayAttacks(.cardinal, Bitboard.initInt(0x80)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x2020_DF20_2020_2020), (Bitboard.initInt(0x2000_0000_0000)).rayAttacks(.cardinal, Bitboard.initInt(0x2000_0000_0000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x2424_DF24_24FB_2424), (Bitboard.initInt(0x2000_0004_0000)).rayAttacks(.cardinal, Bitboard.initInt(0x2000_0004_0000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0426_DF2D_3B26_2622), (Bitboard.initInt(0x2002_0400_0000)).rayAttacks(.cardinal, Bitboard.initInt(0x0022_200a_1400_0400)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x52BA_521D_122F_1212), (Bitboard.initInt(0x0040_0002_0010_0000)).rayAttacks(.cardinal, Bitboard.initInt(0x0048_400a_0130_0000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x2214_0014_2241_8000), (Bitboard.initInt(0x0800_0000_0000)).rayAttacks(.diagonal, Bitboard.initInt(0x0800_0000_0000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x2214_0814_A241_A010), (Bitboard.initInt(0x0800_0040_0000)).rayAttacks(.diagonal, Bitboard.initInt(0x0800_0040_0000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x158B_520E_D9D0_0050), (Bitboard.initInt(0x0420_0000_2000)).rayAttacks(.diagonal, Bitboard.initInt(0x0010_0420_1100_2020)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x2800_2D40_8528_4000), (Bitboard.initInt(0x0010_0002_0000_0080)).rayAttacks(.diagonal, Bitboard.initInt(0x2010_0c06_01a8_0080)));
    }

    test "Bitboard King attacks works" {
        try std.testing.expectEqualDeep(Bitboard.initInt(0x302), (Bitboard.initInt(1)).attacks(.king, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x7050_7000_0000), (Bitboard.initInt(0x0020_0000_0000)).attacks(.king, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0xC040_C000_0000_0000), (Bitboard.initInt(0x0080_0000_0000_0000)).attacks(.king, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0xe0a0e007050700), (Bitboard.initInt(0x400000020000)).attacks(.king, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x40c0000000000302), (Bitboard.initInt(0x8000000000000001)).attacks(.king, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x20300000000c040), (Bitboard.initInt(0x100000000000080)).attacks(.king, undefined));
    }

    test "Bitboard Knight attacks work" {
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0A11_0011_0A00_0000), (Bitboard.initInt(0x0400_0000_0000)).attacks(.knight, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0050_8800_8850_0000), (Bitboard.initInt(0x0020_0000_0000)).attacks(.knight, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0040_2000), (Bitboard.initInt(0x80)).attacks(.knight, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x24420000000000), (Bitboard.initInt(0x8100000000000000)).attacks(.knight, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8a119c735aaa1488), (Bitboard.initInt(0x20040008002000)).attacks(.knight, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x14226a7714756a00), (Bitboard.initInt(0x80094000000)).attacks(.knight, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0), (Bitboard.initInt(0x0)).attacks(.knight, undefined));
        try std.testing.expectEqualDeep(Bitboard.initInt(0xffffffffffffffff), (Bitboard.initInt(0xffffffffffffffff)).attacks(.knight, undefined));
    }

    test "Bitboard Rook attacks works" {
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0101_0101_0101_01FE), Square.a1.toBitboard().attacks(.rook, Bitboard.empty));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8080_8080_8080_807F), Square.h1.toBitboard().attacks(.rook, Bitboard.empty));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x102), Square.a1.toBitboard().attacks(.rook, Bitboard.initInt(0xFFFF)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8040), Square.h1.toBitboard().attacks(.rook, Bitboard.initInt(0xFFFF)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0202_1D02_0202), Square.b4.toBitboard().attacks(.rook, Bitboard.initInt(0x2200_3300_0802)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0008_1408_0000), Square.d4.toBitboard().attacks(.rook, Bitboard.all));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x2020_DF20_2020_2020), Square.f6.toBitboard().attacks(.rook, Bitboard.initInt(0x2000_0000_0000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8080_8080_8080_807F), Square.h1.toBitboard().attacks(.rook, Bitboard.initInt(0x80)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0004_3B04_0404), Square.c4.toBitboard().attacks(.rook, Bitboard.initInt(0x0004_2500_1000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x4040_BF40_4000_0000), Square.g6.toBitboard().attacks(.rook, Bitboard.initInt(0x4000_F800_0000)));
        // TODO: Test a lot more rook attacks
    }

    test "Bitboard Bishop attacks works" {
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0200), Square.a1.toBitboard().attacks(.bishop, Bitboard.empty));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0014_0014_0000), Square.d4.toBitboard().attacks(.bishop, Bitboard.all));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8850_0050_8804_0201), Square.f6.toBitboard().attacks(.bishop, Bitboard.initInt(0x2000_0000_0000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_1020_4000), Square.h1.toBitboard().attacks(.bishop, Bitboard.initInt(0x80)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0020_110A_000A_1020), Square.c4.toBitboard().attacks(.bishop, Bitboard.initInt(0x0020_0140_0402_4004)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x10A0_00A0_1000_0000), Square.g6.toBitboard().attacks(.bishop, Bitboard.initInt(0x4000_F800_0000)));
        // TODO: Test a lot more bishop attacks
    }

    test "Bitboard Queen attacks works" {
        try std.testing.expectEqualDeep(Bitboard.initInt(0x001C_141C_0000), Square.d4.toBitboard().attacks(.queen, Bitboard.all));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x0809_2A1C_F71C_2A49), Square.d4.toBitboard().attacks(.queen, Bitboard.initInt(0x2000_0000_0000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x8182_8488_90A0_C07F), Square.h1.toBitboard().attacks(.queen, Bitboard.initInt(0x80)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x00A8_705E_7088), Square.f3.toBitboard().attacks(.queen, Bitboard.initInt(0x0038_0062_2000)));
        try std.testing.expectEqualDeep(Bitboard.initInt(0x50E0_BFE0_5000_0000), Square.g6.toBitboard().attacks(.queen, Bitboard.initInt(0x4000_F800_0000)));
        // TODO: Test a lot more queen attacks
    }
};
