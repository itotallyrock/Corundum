const std = @import("std");
const Square = @import("square.zig").Square;
const ByRank = @import("square.zig").ByRank;
const ByFile = @import("square.zig").ByFile;
const BoardDirection = @import("directions.zig").BoardDirection;
const SlidingPieceRayDirections = @import("directions.zig").SlidingPieceRayDirections;

/// A board mask that represents a set of squares on a chess board.
/// The mask is a 64-bit integer where each bit represents a square on the board.
/// Bits set to 1 represent squares that are part of the set.
/// Bits set to 0 represent squares that are not part of the set.
pub const Bitboard = struct {
    /// An empty bitboard with no squares set.
    pub const empty = Bitboard{ .mask = 0 };
    /// A bitboard with all squares set.
    pub const all = empty.logicalNot();
    /// A bitboard with only the A1 square set.
    pub const a1 = Bitboard{ .mask = 1 };

    /// Mask of each rank
    pub const ranks = ByRank(Bitboard).init(.{
        ._1 = Bitboard{ .mask = 0xFF },
        ._2 = Bitboard{ .mask = 0xFF00 },
        ._3 = Bitboard{ .mask = 0x00FF_0000 },
        ._4 = Bitboard{ .mask = 0xFF00_0000 },
        ._5 = Bitboard{ .mask = 0x00FF_0000_0000 },
        ._6 = Bitboard{ .mask = 0xFF00_0000_0000 },
        ._7 = Bitboard{ .mask = 0x00FF_0000_0000_0000 },
        ._8 = Bitboard{ .mask = 0xFF00_0000_0000_0000 },
    });

    /// Mask of each file
    pub const files = ByFile(Bitboard).init(.{
        .a = Bitboard{ .mask = 0x0101_0101_0101_0101 },
        .b = Bitboard{ .mask = 0x0202_0202_0202_0202 },
        .c = Bitboard{ .mask = 0x0404_0404_0404_0404 },
        .d = Bitboard{ .mask = 0x0808_0808_0808_0808 },
        .e = Bitboard{ .mask = 0x1010_1010_1010_1010 },
        .f = Bitboard{ .mask = 0x2020_2020_2020_2020 },
        .g = Bitboard{ .mask = 0x4040_4040_4040_4040 },
        .h = Bitboard{ .mask = 0x8080_8080_8080_8080 },
    });

    /// Methods for dealing with line masks on the board
    /// Typically used for sliding piece attacks and move generation
    pub const lines = struct {
        /// Whether two squares are aligned with eachother in a given cardinal or diagonal direction
        pub fn alignedAlong(from: Square, to: Square, comptime alignment: SlidingPieceRayDirections) bool {
            if (from == to) return false;
            if (alignment == .cardinal) {
                return from.file() == to.file() or from.rank() == to.rank();
            } else {
                const rankDiff: u8 = @intFromFloat(@abs(@as(f32, @floatFromInt(@as(i32, @intFromEnum(from.rank())) - @as(i32, @intFromEnum(to.rank()))))));
                const fileDiff: u8 = @intFromFloat(@abs(@as(f32, @floatFromInt(@as(i32, @intFromEnum(from.file())) - @as(i32, @intFromEnum(to.file()))))));
                return rankDiff == fileDiff;
            }
        }

        /// Whether two squares are aligned with eachother in either a cardinal or diagonal direction
        pub fn aligned(from: Square, to: Square) bool {
            return alignedAlong(from, to, .cardinal) or alignedAlong(from, to, .diagonal);
        }

        /// Whether three squares are aligned with eachother in either a cardinal or diagonal direction
        pub fn areAligned(a: Square, b: Square, c: Square) bool {
            return !through(a, b).logicalAnd(c.toBitboard()).isEmpty();
        }

        /// Full board crossing line through two aligned squares
        const through_lookup = blk: {
            const squares = std.enums.values(Square);
            const num_squares = squares.len;
            var result: [num_squares][num_squares]Bitboard = undefined;
            for (squares, 0..) |a, i| {
                for (squares, 0..) |b, j| {
                    result[i][j] = through(a, b);
                }
            }

            break :blk result;
        };

        /// The full board-spanning line that crosses through two aligned squares
        /// If the squares are not aligned, the result is an empty bitboard.
        pub fn through(from: Square, to: Square) Bitboard {
            @setEvalBranchQuota(100000);
            if (!@inComptime()) {
                return through_lookup[@intFromEnum(from)][@intFromEnum(to)];
            }
            for (std.enums.values(SlidingPieceRayDirections)) |direction| {
                if (alignedAlong(from, to, direction)) {
                    return from.toBitboard()
                        .rayAttacks(Bitboard.empty, direction)
                        .logicalAnd(to.toBitboard().rayAttacks(Bitboard.empty, direction))
                    // Because each ray attack doesn't include its starting square, we need to add it back in
                        .logicalOr(to.toBitboard())
                        .logicalOr(from.toBitboard());
                }
            }

            return Bitboard.empty;
        }

        /// Lookup table for the squares between two aligned squares
        const between_lookup = blk: {
            const squares = std.enums.values(Square);
            const num_squares = squares.len;
            var result: [num_squares][numSquares]Bitboard = undefined;
            for (squares, 0..) |a, i| {
                for (squares, 0..) |b, j| {
                    result[i][j] = between(a, b);
                }
            }

            break :blk result;
        };

        /// The intersection *between* two aligned squares, i.e. the squares that a sliding piece would cross if it moved from `from` to `to`.
        /// If the squares are not aligned, the result is an empty bitboard.
        /// This does not include either end square (move gen should add the end piece's square to this mask for pin killing)
        pub fn between(from: Square, to: Square) Bitboard {
            @setEvalBranchQuota(1000000);
            if (!@inComptime()) {
                return between_lookup[@intFromEnum(from)][@intFromEnum(to)];
            }
            for (.{ .cardinal, .diagonal }) |direction| {
                if (alignedAlong(from, to, direction)) {
                    return from.toBitboard()
                        .rayAttacks(to.toBitboard(), direction)
                        .logicalAnd(to.toBitboard().rayAttacks(from.toBitboard(), direction));
                }
            }

            return Bitboard.empty;
        }
    };

    /// The underlying mask that represents the set of squares.
    mask: u64 = 0,

    /// Combine two bitboards using a logical OR operation.
    /// This operation sets all bits that are set in **either bitboard**.
    pub fn logicalOr(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard{ .mask = self.mask | other.mask };
    }

    /// Combine two bitboards using a logical AND operation.
    /// This operation sets all bits that are set in **both bitboards**.
    pub fn logicalAnd(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard{ .mask = self.mask & other.mask };
    }

    /// Combine two bitboards using a logical XOR operation.
    /// This operation sets all bits that are set in **either bitboard but not in both**.
    pub fn logicalXor(self: Bitboard, other: Bitboard) Bitboard {
        return Bitboard{ .mask = self.mask ^ other.mask };
    }

    /// Inverse the bits of the bitboard.
    /// This operation sets all bits that are not set and unsets all bits that were previously set.
    pub fn logicalNot(self: Bitboard) Bitboard {
        return Bitboard{ .mask = ~self.mask };
    }

    /// Shift the bits of the bitboard to the left or right.
    pub fn logicalShift(self: Bitboard, offset: i8) Bitboard {
        if (offset < 0) {
            return Bitboard{ .mask = self.mask >> @intCast(-offset) };
        }
        return Bitboard{ .mask = self.mask << @intCast(offset) };
    }

    /// If the bitboard is contains no squares.
    pub fn isEmpty(self: Bitboard) bool {
        return self.mask == empty.mask;
    }

    /// The number of squares set in the bitboard.
    pub fn numSquares(self: Bitboard) u7 {
        return @popCount(self.mask);
    }

    /// Check if the bitboard contains a specific square.
    pub fn contains(self: Bitboard, square: Square) bool {
        return !self.logicalAnd(square.toBitboard()).isEmpty();
    }

    /// Get the lowest value `Square` (based on rank closest to 1, then by file cloest to A)
    /// Returns `null` if the bitboard is empty.
    pub fn getSquare(self: Bitboard) ?Square {
        if (self.isEmpty()) {
            return null;
        }

        return @enumFromInt(@ctz(self.mask));
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

    pub fn shift(self: Bitboard, comptime direction: BoardDirection) Bitboard {
        const shiftable_squares_mask = comptime switch (direction) {
            .north, .south => Bitboard.all,
            .east, .north_east, .south_east => Bitboard.files.get(.h).logicalNot(),
            .west, .north_west, .south_west => Bitboard.files.get(.a).logicalNot(),
        };
        return self
            .logicalAnd(shiftable_squares_mask)
            .logicalShift(@intFromEnum(direction));
    }

    test isEmpty {
        try std.testing.expect(Bitboard.empty.isEmpty());
        try std.testing.expect(!Bitboard.all.isEmpty());
        try std.testing.expect(!(Bitboard{ .mask = 0x12300 }).isEmpty());
        try std.testing.expect(!(Bitboard{ .mask = 0x8400400004000 }).isEmpty());
        try std.testing.expect(!(Bitboard{ .mask = 0x22000812 }).isEmpty());
    }

    test numSquares {
        try std.testing.expectEqual(Bitboard.empty.numSquares(), 0);
        try std.testing.expectEqual(Bitboard.all.numSquares(), 64);
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).numSquares(), 4);
        try std.testing.expectEqual((Bitboard{ .mask = 0x8400400004000 }).numSquares(), 4);
        try std.testing.expectEqual((Bitboard{ .mask = 0x22000812 }).numSquares(), 5);
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
        try std.testing.expect(!(Bitboard{ .mask = 0x12300 }).contains(.a1));
        try std.testing.expect((Bitboard{ .mask = 0x12300 }).contains(.a2));
        try std.testing.expect((Bitboard{ .mask = 0x12300 }).contains(.a3));
        try std.testing.expect(!(Bitboard{ .mask = 0x12300 }).contains(.g7));
        try std.testing.expect((Bitboard{ .mask = 0x8400400004000 }).contains(.c5));
        try std.testing.expect((Bitboard{ .mask = 0x8400400004000 }).contains(.d7));
        try std.testing.expect((Bitboard{ .mask = 0x8400400004000 }).contains(.g6));
        try std.testing.expect((Bitboard{ .mask = 0x8400400004000 }).contains(.g2));
        try std.testing.expect((Bitboard{ .mask = 0x400200000012200 }).contains(.b2));
        try std.testing.expect((Bitboard{ .mask = 0x400200000012200 }).contains(.f2));
        try std.testing.expect((Bitboard{ .mask = 0x400200000012200 }).contains(.a3));
        try std.testing.expect((Bitboard{ .mask = 0x400200000012200 }).contains(.f6));
        try std.testing.expect((Bitboard{ .mask = 0x400200000012200 }).contains(.c8));
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
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalAnd(Bitboard.all), Bitboard{ .mask = 0x12300 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalAnd(Bitboard.empty), Bitboard.empty);
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalAnd(Bitboard{ .mask = 0x8400400004000 }), Bitboard.empty);
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalAnd(Bitboard{ .mask = 0x101010123010913 }), Bitboard{ .mask = 0x10100 });
    }

    test logicalOr {
        try std.testing.expectEqual(Bitboard.empty.logicalOr(Bitboard.empty), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.empty.logicalOr(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalOr(Bitboard.empty), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalOr(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalOr(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalOr(Bitboard.empty), Bitboard{ .mask = 0x12300 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalOr(Bitboard{ .mask = 0x8400400004000 }), Bitboard{ .mask = 0x8400400016300 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalOr(Bitboard{ .mask = 0x101010123010913 }), Bitboard{ .mask = 0x101010123012b13 });
    }

    test logicalXor {
        try std.testing.expectEqual(Bitboard.empty.logicalXor(Bitboard.empty), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.empty.logicalXor(Bitboard.all), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalXor(Bitboard.empty), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalXor(Bitboard.all), Bitboard.empty);
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalXor(Bitboard.all), Bitboard{ .mask = 0xfffffffffffedcff });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalXor(Bitboard.empty), Bitboard{ .mask = 0x12300 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalXor(Bitboard{ .mask = 0x8400400014000 }), Bitboard{ .mask = 0x8400400006300 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalXor(Bitboard{ .mask = 0x101010123010913 }), Bitboard{ .mask = 0x101010123002a13 });
    }

    test logicalNot {
        try std.testing.expectEqual(Bitboard.empty.logicalNot(), Bitboard.all);
        try std.testing.expectEqual(Bitboard.all.logicalNot(), Bitboard.empty);
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalNot(), Bitboard{ .mask = 0xfffffffffffedcff });
        try std.testing.expectEqual((Bitboard{ .mask = 0x8400400004000 }).logicalNot(), Bitboard{ .mask = 0xfff7bffbffffbfff });
        try std.testing.expectEqual((Bitboard{ .mask = 0x22000812 }).logicalNot(), Bitboard{ .mask = 0xffffffffddfff7ed });
    }

    test logicalShift {
        // Left
        try std.testing.expectEqual(Bitboard.empty.logicalShift(0), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.logicalShift(0), Bitboard.all);
        try std.testing.expectEqual(Bitboard.empty.logicalShift(1), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.logicalShift(1), Bitboard{ .mask = 0xfffffffffffffffe });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(1), Bitboard{ .mask = 0x24600 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(2), Bitboard{ .mask = 0x48c00 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(3), Bitboard{ .mask = 0x91800 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(4), Bitboard{ .mask = 0x123000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(5), Bitboard{ .mask = 0x246000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(6), Bitboard{ .mask = 0x48c000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(7), Bitboard{ .mask = 0x918000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(8), Bitboard{ .mask = 0x1230000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(9), Bitboard{ .mask = 0x2460000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(10), Bitboard{ .mask = 0x48c0000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(11), Bitboard{ .mask = 0x9180000 });
        // Right
        try std.testing.expectEqual(Bitboard.empty.logicalShift(-1), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.logicalShift(-1), Bitboard{ .mask = 0x7fffffffffffffff });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-1), Bitboard{ .mask = 0x09180 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-2), Bitboard{ .mask = 0x048c0 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-3), Bitboard{ .mask = 0x02460 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-4), Bitboard{ .mask = 0x01230 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-5), Bitboard{ .mask = 0x00918 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-6), Bitboard{ .mask = 0x0048c });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-7), Bitboard{ .mask = 0x00246 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-8), Bitboard{ .mask = 0x00123 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-9), Bitboard{ .mask = 0x00091 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-10), Bitboard{ .mask = 0x00048 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).logicalShift(-11), Bitboard{ .mask = 0x00024 });
    }

    test getSquare {
        try std.testing.expectEqual(Bitboard.empty.getSquare(), null);
        try std.testing.expectEqual(Bitboard.all.getSquare().?, .a1);
        try std.testing.expectEqual(Bitboard.a1.getSquare().?, .a1);
        try std.testing.expectEqual((Bitboard{ .mask = 0x400200000012200 }).getSquare().?, .b2);
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).getSquare().?, .a2);
        try std.testing.expectEqual((Bitboard{ .mask = 0x100000000000000 }).getSquare().?, .a8);
        try std.testing.expectEqual((Bitboard{ .mask = 0x8000000000000000 }).getSquare().?, .h8);
        try std.testing.expectEqual((Bitboard{ .mask = 0x80 }).getSquare().?, .h1);
        try std.testing.expectEqual((Bitboard{ .mask = 0x2000000400 }).getSquare().?, .c2);
        try std.testing.expectEqual((Bitboard{ .mask = 0xfe00000000000000 }).getSquare().?, .b8);
        try std.testing.expectEqual((Bitboard{ .mask = 0xfe28000000000000 }).getSquare().?, .d7);
        try std.testing.expectEqual((Bitboard{ .mask = 0xf628022000000000 }).getSquare().?, .f5);
    }

    test popSquare {
        var bb = Bitboard{ .mask = 0x400200000012200 };
        try std.testing.expectEqual(bb.popSquare().?, .b2);
        try std.testing.expectEqual(bb.popSquare().?, .f2);
        try std.testing.expectEqual(bb.popSquare().?, .a3);
        try std.testing.expectEqual(bb.popSquare().?, .f6);
        try std.testing.expectEqual(bb.popSquare().?, .c8);
        try std.testing.expectEqual(bb.popSquare(), null);
    }

    test shift {
        try std.testing.expectEqual(Bitboard.empty.shift(.north), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.shift(.north), Bitboard{ .mask = 0xffffffffffffff00 });
        try std.testing.expectEqual(Bitboard.empty.shift(.south), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.shift(.south), Bitboard{ .mask = 0xffffffffffffff });
        try std.testing.expectEqual(Bitboard.empty.shift(.east), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.shift(.east), Bitboard{ .mask = 0xfefefefefefefefe });
        try std.testing.expectEqual(Bitboard.empty.shift(.west), Bitboard.empty);
        try std.testing.expectEqual(Bitboard.all.shift(.west), Bitboard{ .mask = 0x7f7f7f7f7f7f7f7f });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).shift(.north), Bitboard{ .mask = 0x1230000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).shift(.south), Bitboard{ .mask = 0x123 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).shift(.east), Bitboard{ .mask = 0x24600 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x12300 }).shift(.west), Bitboard{ .mask = 0x1100 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x8001d00400002208 }).shift(.north_east), Bitboard{ .mask = 0x2a0080000441000 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x8001d00400002208 }).shift(.north_west), Bitboard{ .mask = 0x68020000110400 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x8001d00400002208 }).shift(.south_east), Bitboard{ .mask = 0x2a008000044 });
        try std.testing.expectEqual((Bitboard{ .mask = 0x8001d00400002208 }).shift(.south_west), Bitboard{ .mask = 0x40006802000011 });
    }
};
