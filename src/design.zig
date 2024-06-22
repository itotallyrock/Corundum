
pub fn PlyCount(comptime T: type, comptime max: T) type {
    return struct {
        const DEFAULT = @This().init(0);
        plies: T,

        pub fn init(plies: T) @This() {
            return .{ .plies = plies };
        }
        pub fn increment(self: @This()) !@This() {
            if (self.plies >= max) {
                return error.IncrementPastMax;
            }

            return @This().init(self.plies +| 1);
        }
    };
}

pub const Player = enum(u1) {
    white,
    black,
};

pub const Square = enum(u6) {
    A1, B1, C1, D1, E1, F1, G1, H1,
    A2, B2, C2, D2, E2, F2, G2, H2,
    A3, B3, C3, D3, E3, F3, G3, H3,
    A4, B4, C4, D4, E4, F4, G4, H4,
    A5, B5, C5, D5, E5, F5, G5, H5,
    A6, B6, C6, D6, E6, F6, G6, H6,
    A7, B7, C7, D7, E7, F7, G7, H7,
    A8, B8, C8, D8, E8, F8, G8, H8,

    pub fn fromRankAndFile(r: Rank, f: File) Square {
        return @enumFromInt(@intFromEnum(r) * 8 + @intFromEnum(f));
    }

    pub fn toBitboard(self: Square) BoardMask {
        return BoardMask { .mask = BoardMask.A1.mask << @intFromEnum(self) };
    }

    pub fn rank(self: Square) Rank {
        return @enumFromInt(@intFromEnum(self) / 8);
    }

    pub fn file(self: Square) File {
        return @enumFromInt(@intFromEnum(self) % 8);
    }

    fn isShiftable(self: Square, comptime direction: BoardDirection) bool {
        return ((direction == .north or direction == .northEast or direction == .northWest) and self.rank() == ._8) and
               ((direction == .south or direction == .southEast or direction == .southWest) and self.rank() == ._1) and
               ((direction == .east or direction == .southEast or direction == .northEast) and self.file() == .H) and
               ((direction == .west or direction == .southWest or direction == .northWest) and self.file() == .A);
    }

    pub fn shift(self: Square, comptime direction: BoardDirection) !Square {
        if (!self.isShiftable(direction)) {
            return error.SquareShiftOutOfBounds;
        }
        return @enumFromInt(@intFromEnum(self) + @intFromEnum(direction));
    }
};

pub const Rank = enum(u3) {
    _1, _2, _3, _4, _5, _6, _7, _8,

    pub fn epRankFor(comptime player: Player) Rank {
        if (player == .white) {
            return ._3;
        } else {
            return ._6;
        }
    }

    pub fn promotionRankFor(comptime player: Player) Rank {
        if (player == .white) {
            return ._8;
        } else {
            return ._1;
        }
    }
};

pub const File = enum(u3) {
    A, B, C, D, E, F, G, H,

    pub fn promotionSquareFor(self: File, comptime player: Player) Square {
        return Square.fromRankAndFile(Rank.promotionRankFor(player), self);
    }

    pub fn epSquareFor(self: File, comptime player: Player) Square {
        return Square.fromRankAndFile(Rank.epRankFor(player), self);
    }
};

pub const Piece = enum(u3) {
    pawn,
    knight,
    bishop,
    rook,
    queen,
    king,
};


pub const NonPawnPiece = enum(u3) {
    knight,
    bishop,
    rook,
    queen,
    king,
};

pub const NonKingPiece = enum(u3) {
    pawn,
    knight,
    bishop,
    rook,
    queen,
};

pub const PromotablePiece = enum(u3) {
    knight,
    bishop,
    rook,
    queen,
};
pub const NonKingNonPawnPiece = PromotablePiece;

pub const SlidingPiece = enum(u2) {
    rook,
    bishop,
    queen,
};

pub const CardinalSlidingPiece = enum(u1) {
    rook,
    queen,
};

pub const DiagonalSlidingPiece = enum(u1) {
    bishop,
    queen,
};

pub const SlidingPieceRayDirections = enum {
    cardinal,
    diagonal,
};

/// A bitboard that can be used to mask out particular squares on a 8x8 chess board.
pub const BoardMask = struct {
    pub const EMPTY = BoardMask { .mask = 0x0 };
    pub const FULL = EMPTY.inverse();
    pub const A1 = BoardMask { .mask = 0x1 };
    pub const lines = struct {
        pub fn alignedAlong(comptime from: Square, comptime to: Square, comptime alignment: SlidingPieceRayDirections) bool {
            if (from == to) return false;
            if (alignment == .cardinal) {
                return from.file() == to.file() or from.rank() == to.rank();
            } else {
                const rankDiff: u8 = @intFromFloat(@fabs(@as(f32, @floatFromInt(@as(i32, @intFromEnum(from.rank())) - @as(i32, @intFromEnum(to.rank()))))));
                const fileDiff: u8 = @intFromFloat(@fabs(@as(f32, @floatFromInt(@as(i32, @intFromEnum(from.file())) - @as(i32, @intFromEnum(to.file()))))));
                return rankDiff == fileDiff;
            }
        }
        pub fn aligned(comptime from: Square, comptime to: Square) bool {
            return alignedAlong(from, to, .cardinal) or alignedAlong(from, to, .diagonal);
        }
        pub fn areAligned(comptime a: Square, comptime b: Square, comptime c: Square) bool {
            return !through(a, b).logicalAnd(c.toBitboard()).isEmpty();
        }

        /// Full board crossing line through two aligned squares
        const throughLookup = blk: {
            const SQUARES = @import("std").enums.values(Square);
            const NUM_SQUARES = SQUARES.len;
            var result: [NUM_SQUARES][NUM_SQUARES]BoardMask = undefined;
            inline for (SQUARES, 0..) |a, i| {
                inline for (SQUARES, 0..) |b, j| {
                    result[i][j] = through(a, b);
                }
            }

            break :blk result;
        };
        pub fn through(from: Square, to: Square) BoardMask {
            @setEvalBranchQuota(100000);
            if (!@inComptime()) {
                return throughLookup[@intFromEnum(from)][@intFromEnum(to)];
            }
            inline for (.{.cardinal, .diagonal}) |direction| {
                if (alignedAlong(from, to, direction)) {
                    return from.toBitboard()
                        .rayAttacks(BoardMask.EMPTY, direction)
                        .logicalAnd(to.toBitboard().rayAttacks(BoardMask.EMPTY, direction))
                        .logicalOr(to.toBitboard())
                        .logicalOr(from.toBitboard());
                }
            }

            return BoardMask.EMPTY;
        }
        /// The intersection between two aligned squares (not including the end square, move gen should add it to this mask for pin blocking/killing)
        const betweenLookup = blk: {
            const SQUARES = @import("std").enums.values(Square);
            const NUM_SQUARES = SQUARES.len;
            var result: [NUM_SQUARES][NUM_SQUARES]BoardMask = undefined;
            inline for (SQUARES, 0..) |a, i| {
                inline for (SQUARES, 0..) |b, j| {
                    result[i][j] = between(a, b);
                }
            }

            break :blk result;
        };
        pub fn between(from: Square, to: Square) BoardMask {
            @setEvalBranchQuota(1000000);
            if (!@inComptime()) {
                return betweenLookup[@intFromEnum(from)][@intFromEnum(to)];
            }
            inline for (.{.cardinal, .diagonal}) |direction| {
                if (alignedAlong(from, to, direction)) {
                    return from.toBitboard()
                        .rayAttacks(to.toBitboard(), direction)
                        .logicalAnd(to.toBitboard().rayAttacks(from.toBitboard(), direction));
                }
            }

            return BoardMask.EMPTY;
        }
    };
    mask: u64,

    pub fn shift(self: BoardMask, comptime direction: BoardDirection) BoardMask {
        const NOT_H_FILE = 0x7F7F_7F7F_7F7F_7F7F;
        const NOT_A_FILE = 0xFEFE_FEFE_FEFE_FEFE;
        const directionOffset = @intFromEnum(direction);
        const shiftMask = switch (direction) {
            .north, .south => FULL.mask,
            .east, .northEast, .southEast => NOT_H_FILE,
            .west, .northWest, .southWest => NOT_A_FILE,
        };
        const shiftableMask = self.mask & shiftMask;
        if (directionOffset < 0) {
            return BoardMask { .mask = shiftableMask >> -directionOffset };
        }
        return BoardMask { .mask = shiftableMask << directionOffset };
    }

    pub fn logicalOr(self: BoardMask, other: BoardMask) BoardMask {
        return BoardMask { .mask = self.mask | other.mask };
    }

    pub fn logicalAnd(self: BoardMask, other: BoardMask) BoardMask {
        return BoardMask { .mask = self.mask & other.mask };
    }

    pub fn logicalXor(self: BoardMask, other: BoardMask) BoardMask {
        return BoardMask { .mask = self.mask ^ other.mask };
    }

    pub fn inverse(self: BoardMask) BoardMask {
        return BoardMask { .mask = ~self.mask };
    }

    pub fn isEmpty(self: BoardMask) bool {
        return self.mask == 0;
    }

    pub fn numSquares(self: BoardMask) u6 {
        return @popCount(self.mask);
    }

    pub fn popSquare(self: *BoardMask) ?Square {
        if (self.isEmpty()) {
            return null;
        }
        const squareOffset = @ctz(self.mask);
        const square: Square = @enumFromInt(squareOffset);
        self.mask ^= square.toBitboard();

        return square;
    }

    pub fn occludedFill(self: BoardMask, occluded: BoardMask, comptime direction: BoardDirection) BoardMask {
        if (self.isEmpty()) {
            return EMPTY;
        }

        var filled = EMPTY;
        var source = self;
        var emptySquaresMask = occluded.inverse().logicalAnd(switch (direction) {
            .north => BoardMask { .mask = 0xFFFFFFFFFFFFFF00 },
            .south => BoardMask { .mask = 0x00FFFFFFFFFFFFFF },
            .east => BoardMask { .mask = 0xFEFEFEFEFEFEFEFE },
            .west => BoardMask { .mask = 0x7F7F7F7F7F7F7F7F },
            .northWest => BoardMask { .mask = 0x7F7F7F7F7F7F7F00 },
            .northEast => BoardMask { .mask = 0xFEFEFEFEFEFEFE00 },
            .southEast => BoardMask { .mask = 0x007F7F7F7F7F7F7F },
            .southWest => BoardMask { .mask = 0x00FEFEFEFEFEFEFE },
        });

        while (!source.isEmpty()) {
            filled = filled.logicalOr(source);
            source = source.shift(direction).logicalAnd(emptySquaresMask);
        }

        return filled;
    }

    fn rayAttack(self: BoardMask, occupied: BoardMask, comptime direction: BoardDirection) BoardMask {
        return self.occludedFill(occupied, direction).shift(direction);
    }

    fn rayAttacks(self: BoardMask, occupied: BoardMask, comptime direction: SlidingPieceRayDirections) BoardMask {
        if (direction == .cardinal) {
            return self.rayAttack(occupied, .north).logicalOr(self.rayAttack(occupied, .south)).logicalOr(self.rayAttack(occupied, .east)).logicalOr(self.rayAttack(occupied, .west));
        } else {
            return self.rayAttack(occupied, .northWest).logicalOr(self.rayAttack(occupied, .northEast)).logicalOr(self.rayAttack(occupied, .southEast)).logicalOr(self.rayAttack(occupied, .southWest));
        }
    }

    fn kingAttacks(self: BoardMask) BoardMask {
        const eastWestAttacks = self.shift(.east).logicalOr(self.shift(.west));
        const kingRow = self.logicalOr(eastWestAttacks);

        return eastWestAttacks.logicalOr(kingRow.shift(.south)).logicalOr(kingRow.shift(.north));
    }

    fn knightAttacks(self: BoardMask) BoardMask {
        const l1 = BoardMask { .mask = self.mask >> 1 & 0x7F7F_7F7F_7F7F_7F7F };
        const l2 = BoardMask { .mask = self.mask >> 2 & 0x3F3F_3F3F_3F3F_3F3F };
        const r1 = BoardMask { .mask = self.mask << 1 & 0xFEFE_FEFE_FEFE_FEFE };
        const r2 = BoardMask { .mask = self.mask << 2 & 0xFCFC_FCFC_FCFC_FCFC };
        const h1 = l1.logicalOr(r1);
        const h2 = l2.logicalOr(r2);

        return BoardMask { .mask = h1.mask << 16 | h1.mask >> 16 | h2.mask << 8 | h2.mask >> 8 };
    }

    pub fn attacks(self: BoardMask, occupied: BoardMask, comptime piece: NonPawnPiece) BoardMask {
        switch (piece) {
            .king => return self.kingAttacks(),
            .knight => return self.knightAttacks(),
            .bishop => return self.rayAttacks(occupied, .diagonal),
            .rook => return self.rayAttacks(occupied, .cardinal),
            .queen => return self.rayAttacks(occupied, .cardinal).logicalOr(self.rayAttacks(occupied, .diagonal)),
        }
    }
};

pub const BoardDirection = enum(i5) {
    north = 8,
    south = -8,
    east = 1,
    west = -1,
    northWest = 7,
    northEast = 9,
    southEast = -7,
    southWest = -9,
};

pub const RelativeDirection = enum {
    forward,
    backward,
    left,
    right,
    forwardLeft,
    forwardRight,
    backwardLeft,
    backwardRight,

    pub fn toDirection(self: RelativeDirection, comptime perspective: Player) BoardDirection {
        return switch (self) {
            .forward => if (perspective == .white) .north else .south,
            .backward => if (perspective == .white) .south else .north,
            .left => if (perspective == .white) .west else .east,
            .right => if (perspective == .white) .east else .west,
            .forwardLeft => if (perspective == .white) .northWest else .northEast,
            .forwardRight => if (perspective == .white) .northEast else .northWest,
            .backwardLeft => if (perspective == .white) .southWest else .southEast,
            .backwardRight => if (perspective == .white) .southEast else .southWest,
        };
    }
};

pub const PawnAttackDirection = enum {
    forwardLeft,
    forwardRight,
};

pub const PawnPushType = enum {
    single,
    double,
};

fn testSquareToBoardMask(comptime square: Square, comptime expected: BoardMask) !void {
    const expectEqual = @import("std").testing.expectEqual;
    try expectEqual(expected, square.toBitboard());
}
test "Square to BoardMask works" {
    try testSquareToBoardMask(.A1, .{ .mask = 0x1 });
    try testSquareToBoardMask(.A8, .{ .mask = 0x0100_0000_0000_0000 });
    try testSquareToBoardMask(.H1, .{ .mask = 0x80 });
    try testSquareToBoardMask(.H8, .{ .mask = 0x8000_0000_0000_0000 });
    try testSquareToBoardMask(.C4, .{ .mask = 0x0400_0000 });
    try testSquareToBoardMask(.E6, .{ .mask = 0x1000_0000_0000 });
    try testSquareToBoardMask(.F2, .{ .mask = 0x2000 });
    try testSquareToBoardMask(.B7, .{ .mask = 0x0002_0000_0000_0000 });
}

fn testBoardMaskShift(comptime mask: BoardMask, comptime direction: BoardDirection, comptime expected: BoardMask) !void {
    const expectEqualDeep = @import("std").testing.expectEqualDeep;
    try expectEqualDeep(expected, mask.shift(direction));
}
test "BoardMask shift works" {
    try testBoardMaskShift(.{ .mask = 0x0304_0A10_2440_8800 }, .north, .{ .mask = 0x040A_1024_4088_0000 });
    try testBoardMaskShift(.{ .mask = 0xFFFF_FFFF_FFFF_FFFF }, .north, .{ .mask = 0xFFFF_FFFF_FFFF_FF00 });
    try testBoardMaskShift(.{ .mask = 0x0 }, .north, .{ .mask = 0x0 });
    try testBoardMaskShift(.{ .mask = 0x0304_0A10_2440_8800 }, .south, .{ .mask = 0x0003_040A_1024_4088 });
    try testBoardMaskShift(.{ .mask = 0xFFFF_FFFF_FFFF_FFFF }, .south, .{ .mask = 0x00FF_FFFF_FFFF_FFFF });
    try testBoardMaskShift(.{ .mask = 0x0 }, .south, .{ .mask = 0x0 });
    try testBoardMaskShift(.{ .mask = 0x0304_0A10_2440_8800 }, .east, .{ .mask = 0x0608_1420_4880_1000 });
    try testBoardMaskShift(.{ .mask = 0xFFFF_FFFF_FFFF_FFFF }, .east, .{ .mask = 0xFEFE_FEFE_FEFE_FEFE });
    try testBoardMaskShift(.{ .mask = 0x0 }, .east, .{ .mask = 0x0 });
    try testBoardMaskShift(.{ .mask = 0x0304_0A10_2440_8800 }, .west, .{ .mask = 0x0102_0508_1220_4400 });
    try testBoardMaskShift(.{ .mask = 0xFFFF_FFFF_FFFF_FFFF }, .west, .{ .mask = 0x7F7F_7F7F_7F7F_7F7F });
    try testBoardMaskShift(.{ .mask = 0x0 }, .west, .{ .mask = 0x0 });
    try testBoardMaskShift(.{ .mask = 0x0304_0A10_2440_8800 }, .northEast, .{ .mask = 0x0814_2048_8010_0000 });
    try testBoardMaskShift(.{ .mask = 0xFFFF_FFFF_FFFF_FFFF }, .northEast, .{ .mask = 0xFEFE_FEFE_FEFE_FE00 });
    try testBoardMaskShift(.{ .mask = 0x0 }, .northEast, .{ .mask = 0x0 });
    try testBoardMaskShift(.{ .mask = 0x0304_0A10_2440_8800 }, .northWest, .{ .mask = 0x0205_0812_2044_0000 });
    try testBoardMaskShift(.{ .mask = 0xFFFF_FFFF_FFFF_FFFF }, .northWest, .{ .mask = 0x7F7F_7F7F_7F7F_7F00 });
    try testBoardMaskShift(.{ .mask = 0x0 }, .northWest, .{ .mask = 0x0 });
    try testBoardMaskShift(.{ .mask = 0x0304_0A10_2440_8800 }, .southEast, .{ .mask = 0x0006_0814_2048_8010 });
    try testBoardMaskShift(.{ .mask = 0xFFFF_FFFF_FFFF_FFFF }, .southEast, .{ .mask = 0x00FE_FEFE_FEFE_FEFE });
    try testBoardMaskShift(.{ .mask = 0x0 }, .southEast, .{ .mask = 0x0 });
    try testBoardMaskShift(.{ .mask = 0x0304_0A10_2440_8800 }, .southWest, .{ .mask = 0x0001_0205_0812_2044 });
    try testBoardMaskShift(.{ .mask = 0xFFFF_FFFF_FFFF_FFFF }, .southWest, .{ .mask = 0x007F_7F7F_7F7F_7F7F });
    try testBoardMaskShift(.{ .mask = 0x0 }, .southWest, .{ .mask = 0x0 });
}

fn testRayAttack(comptime direction: BoardDirection, sliders: BoardMask, occupied: BoardMask, comptime expected: BoardMask) !void {
    const expectEqualDeep = @import("std").testing.expectEqualDeep;
    try expectEqualDeep(expected, sliders.rayAttack(occupied, direction));
}
test "BoardMask ray attack works" {
    try testRayAttack(.northEast, Square.A1.toBitboard(), BoardMask.EMPTY, BoardMask { .mask = 0x8040_2010_0804_0200 });
    try testRayAttack(.north, Square.A1.toBitboard(), BoardMask { .mask = 0xffff }, BoardMask { .mask = 0x100 });
    try testRayAttack(.north, Square.H1.toBitboard(), BoardMask { .mask = 0xffff }, BoardMask { .mask = 0x8000 });
    try testRayAttack(.north, Square.E4.toBitboard(), Square.E4.toBitboard(), BoardMask { .mask = 0x1010_1010_0000_0000 });
    try testRayAttack(.south, Square.E4.toBitboard(), Square.E4.toBitboard(), BoardMask { .mask = 0x0010_1010 });
    try testRayAttack(.east, Square.E4.toBitboard(), Square.E4.toBitboard(), BoardMask { .mask = 0xE000_0000 });
    try testRayAttack(.west, Square.E4.toBitboard(), Square.E4.toBitboard(), BoardMask { .mask = 0x0F00_0000 });
    try testRayAttack(.northEast, Square.E4.toBitboard(), Square.E4.toBitboard(), BoardMask { .mask = 0x0080_4020_0000_0000 });
    try testRayAttack(.southWest, Square.E4.toBitboard(), Square.E4.toBitboard(), BoardMask { .mask = 0x80402 });
    try testRayAttack(.northWest, Square.E4.toBitboard(), Square.E4.toBitboard(), BoardMask { .mask = 0x0102_0408_0000_0000 });
    try testRayAttack(.southEast, Square.E4.toBitboard(), Square.E4.toBitboard(), BoardMask { .mask = 0x0020_4080 });
}

fn testRayAttacks(comptime direction: SlidingPieceRayDirections, sliders: BoardMask, occupied: BoardMask, comptime expected: BoardMask) !void {
    const expectEqualDeep = @import("std").testing.expectEqualDeep;
    try expectEqualDeep(expected, sliders.rayAttacks(occupied, direction));
}
test "BoardMask ray attacks works" {
    try testRayAttacks(.cardinal, .{ .mask = 0x1 }, .{ .mask = 0x1 }, .{ .mask = 0x0101_0101_0101_01FE });
    try testRayAttacks(.cardinal, .{ .mask = 0x80 }, .{ .mask = 0x80 }, .{ .mask = 0x8080_8080_8080_807F });
    try testRayAttacks(.cardinal, .{ .mask = 0x2000_0000_0000 }, .{ .mask = 0x2000_0000_0000 }, .{ .mask = 0x2020_DF20_2020_2020 });
    try testRayAttacks(.cardinal, .{ .mask = 0x2000_0004_0000 }, .{ .mask = 0x2000_0004_0000 }, .{ .mask = 0x2424_DF24_24FB_2424 });
    try testRayAttacks(.cardinal, .{ .mask = 0x2002_0400_0000 }, .{ .mask = 0x0022_200a_1400_0400 }, .{ .mask = 0x0426_DF2D_3B26_2622 });
    try testRayAttacks(.cardinal, .{ .mask = 0x0040_0002_0010_0000 }, .{ .mask = 0x0048_400a_0130_0000 }, .{ .mask = 0x52BA_521D_122F_1212 });
    try testRayAttacks(.diagonal, .{ .mask = 0x0800_0000_0000 }, .{ .mask = 0x0800_0000_0000 }, .{ .mask = 0x2214_0014_2241_8000 });
    try testRayAttacks(.diagonal, .{ .mask = 0x0800_0040_0000 }, .{ .mask = 0x0800_0040_0000 }, .{ .mask = 0x2214_0814_A241_A010 });
    try testRayAttacks(.diagonal, .{ .mask = 0x0420_0000_2000 }, .{ .mask = 0x0010_0420_1100_2020 }, .{ .mask = 0x158B_520E_D9D0_0050 });
    try testRayAttacks(.diagonal, .{ .mask = 0x0010_0002_0000_0080 }, .{ .mask = 0x2010_0c06_01a8_0080 }, .{ .mask = 0x2800_2D40_8528_4000 });
}

fn testAttacks(comptime piece: NonPawnPiece, attackers: BoardMask, occupied: BoardMask, comptime expected: BoardMask) !void {
    const expectEqualDeep = @import("std").testing.expectEqualDeep;
    try expectEqualDeep(expected, attackers.attacks(occupied, piece));
}
test "BoardMask King attacks works" {
    try testAttacks(.king, .{ .mask = 1 }, undefined, .{ .mask = 0x302 });
    try testAttacks(.king, .{ .mask = 0x0020_0000_0000 }, undefined, .{ .mask = 0x7050_7000_0000 });
    try testAttacks(.king, .{ .mask = 0x0080_0000_0000_0000 }, undefined, .{ .mask = 0xC040_C000_0000_0000 });
}

test "BoardMask Knight attacks work" {
    try testAttacks(.knight, .{ .mask = 0x0400_0000_0000 }, undefined, .{ .mask = 0x0A11_0011_0A00_0000 });
    try testAttacks(.knight, .{ .mask = 0x0020_0000_0000 }, undefined, .{ .mask = 0x0050_8800_8850_0000 });
    try testAttacks(.knight, .{ .mask = 0x80 }, undefined, .{ .mask = 0x0040_2000 });
}

test "BoardMask Rook attacks works" {
    try testAttacks(.rook, Square.A1.toBitboard(), BoardMask.EMPTY, .{ .mask = 0x0101_0101_0101_01FE });
    try testAttacks(.rook, Square.H1.toBitboard(), BoardMask.EMPTY, .{ .mask = 0x8080_8080_8080_807F });
    try testAttacks(.rook, Square.A1.toBitboard(), .{ .mask = 0xFFFF }, .{ .mask = 0x102 });
    try testAttacks(.rook, Square.H1.toBitboard(), .{ .mask = 0xFFFF }, .{ .mask = 0x8040 });
    try testAttacks(.rook, Square.B4.toBitboard(), .{ .mask = 0x2200_3300_0802 }, .{ .mask = 0x0202_1D02_0202 });
    try testAttacks(.rook, Square.D4.toBitboard(), BoardMask.FULL, .{ .mask = 0x0008_1408_0000 });
    try testAttacks(.rook, Square.F6.toBitboard(), .{ .mask = 0x2000_0000_0000 }, .{ .mask = 0x2020_DF20_2020_2020 });
    try testAttacks(.rook, Square.H1.toBitboard(), .{ .mask = 0x80 }, .{ .mask = 0x8080_8080_8080_807F });
    try testAttacks(.rook, Square.C4.toBitboard(), .{ .mask = 0x0004_2500_1000 }, .{ .mask = 0x0004_3B04_0404 });
    try testAttacks(.rook, Square.G6.toBitboard(), .{ .mask = 0x4000_F800_0000 }, .{ .mask = 0x4040_BF40_4000_0000 });
}

test "BoardMask Bishop attacks works" {
    try testAttacks(.bishop, Square.A1.toBitboard(), BoardMask.EMPTY, .{ .mask = 0x8040_2010_0804_0200 });
    try testAttacks(.bishop, Square.D4.toBitboard(), BoardMask.FULL, .{ .mask = 0x0014_0014_0000 });
    try testAttacks(.bishop, Square.F6.toBitboard(), .{ .mask = 0x2000_0000_0000 }, .{ .mask = 0x8850_0050_8804_0201 });
    try testAttacks(.bishop, Square.H1.toBitboard(), .{ .mask = 0x80 }, .{ .mask = 0x0102_0408_1020_4000 });
    try testAttacks(.bishop, Square.C4.toBitboard(), .{ .mask = 0x0020_0140_0402_4004 }, .{ .mask = 0x0020_110A_000A_1020 });
    try testAttacks(.bishop, Square.G6.toBitboard(), .{ .mask = 0x4000_F800_0000 }, .{ .mask = 0x10A0_00A0_1000_0000 });
}

test "BoardMask Queen attacks works" {
    try testAttacks(.queen, Square.D4.toBitboard(), BoardMask.FULL, .{ .mask = 0x001C_141C_0000 });
    try testAttacks(.queen, Square.D4.toBitboard(), .{ .mask = 0x2000_0000_0000 }, .{ .mask = 0x0809_2A1C_F71C_2A49 });
    try testAttacks(.queen, Square.H1.toBitboard(), .{ .mask = 0x80 }, .{ .mask = 0x8182_8488_90A0_C07F });
    try testAttacks(.queen, Square.F3.toBitboard(), .{ .mask = 0x0038_0062_2000 }, .{ .mask = 0x00A8_705E_7088 });
    try testAttacks(.queen, Square.G6.toBitboard(), .{ .mask = 0x4000_F800_0000 }, .{ .mask = 0x50E0_BFE0_5000_0000 });
}

test "BoardMask lines areAligned works" {
    const expectEqual = @import("std").testing.expectEqual;
    try expectEqual(true, BoardMask.lines.areAligned(.A2, .A4, .A6));
    try expectEqual(true, BoardMask.lines.areAligned(.A2, .A4, .A8));
    try expectEqual(false, BoardMask.lines.areAligned(.B2, .A4, .A8));
    try expectEqual(false, BoardMask.lines.areAligned(.A2, .B4, .A8));
    try expectEqual(false, BoardMask.lines.areAligned(.A2, .A4, .B8));
    try expectEqual(false, BoardMask.lines.areAligned(.A2, .B4, .B8));
    try expectEqual(true, BoardMask.lines.areAligned(.B2, .B4, .B8));
    try expectEqual(true, BoardMask.lines.areAligned(.H1, .A1, .C1));
    try expectEqual(false, BoardMask.lines.areAligned(.H1, .A1, .C2));
    try expectEqual(true, BoardMask.lines.areAligned(.H8, .A1, .D4));
}

test "BoardMask lines aligned works" {
    const expectEqual = @import("std").testing.expectEqual;
    try expectEqual(true, BoardMask.lines.areAligned(.A2, .A4, .A6));
    try expectEqual(true, BoardMask.lines.areAligned(.A2, .A4, .A8));
    try expectEqual(false, BoardMask.lines.areAligned(.B2, .A4, .A8));
    try expectEqual(false, BoardMask.lines.areAligned(.A2, .B4, .A8));
    try expectEqual(false, BoardMask.lines.areAligned(.A2, .A4, .B8));
    try expectEqual(false, BoardMask.lines.areAligned(.A2, .B4, .B8));
    try expectEqual(true, BoardMask.lines.areAligned(.B2, .B4, .B8));
    try expectEqual(true, BoardMask.lines.areAligned(.H1, .A1, .C1));
    try expectEqual(false, BoardMask.lines.areAligned(.H1, .A1, .C2));
    try expectEqual(true, BoardMask.lines.areAligned(.H8, .A1, .D4));
}

fn testLineBetween(comptime from: Square, comptime to: Square, comptime expected: BoardMask) !void {
    const expectEqualDeep = @import("std").testing.expectEqualDeep;
    try expectEqualDeep(expected, BoardMask.lines.between(from, to));
}
test "BoardMask lines between works" {
    try testLineBetween(.C4, .F7, .{.mask=0x100800000000});
    try testLineBetween(.E6, .F8, BoardMask.EMPTY);
    // A1-H8 diagonal
    try testLineBetween(.A1, .H8, .{.mask=0x40201008040200});
    try testLineBetween(.A1, .G7, .{.mask=0x201008040200});
    try testLineBetween(.A1, .F6, .{.mask=0x1008040200});
    try testLineBetween(.A1, .E5, .{.mask=0x8040200});
    try testLineBetween(.B2, .E5, .{.mask=0x8040000});
    try testLineBetween(.B2, .D4, .{.mask=0x40000});
    try testLineBetween(.B3, .D4, BoardMask.EMPTY);
    // G2-G6 vertical
    try testLineBetween(.G2, .G6, .{.mask=0x4040400000});
    try testLineBetween(.G3, .G6, .{.mask=0x4040000000});
    try testLineBetween(.G4, .G6, .{.mask=0x4000000000});
    try testLineBetween(.G4, .G5, BoardMask.EMPTY);
    // F5-A5 horizontal
    try testLineBetween(.F5, .A5, .{.mask=0x1e00000000});
    try testLineBetween(.E5, .A5, .{.mask=0xe00000000});
    try testLineBetween(.D5, .A5, .{.mask=0x600000000});
    try testLineBetween(.D5, .B5, .{.mask=0x400000000});
    try testLineBetween(.D5, .C5, BoardMask.EMPTY);
    // Non aligned between
    try testLineBetween(.A5, .B7, BoardMask.EMPTY);
    try testLineBetween(.H1, .C8, BoardMask.EMPTY);
    try testLineBetween(.E4, .C1, BoardMask.EMPTY);
    try testLineBetween(.E4, .D1, BoardMask.EMPTY);
    try testLineBetween(.E4, .F1, BoardMask.EMPTY);
    try testLineBetween(.E4, .G1, BoardMask.EMPTY);
    try testLineBetween(.E4, .E4, BoardMask.EMPTY);
    try testLineBetween(.H8, .H8, BoardMask.EMPTY);
}


fn testLineThrough(comptime from: Square, comptime to: Square, comptime expected: BoardMask) !void {
    const expectEqualDeep = @import("std").testing.expectEqualDeep;
    try expectEqualDeep(expected, BoardMask.lines.through(from, to));
}
test "BoardMask lines through works" {
    // Non aligned
    try testLineThrough(.A1, .B5, .{.mask = 0x0});
    try testLineThrough(.A1, .B4, .{.mask = 0x0});
    try testLineThrough(.A1, .C4, .{.mask = 0x0});
    // Diagonal A1-H8
    try testLineThrough(.A1, .D4, .{.mask = 0x8040_2010_0804_0201});
    try testLineThrough(.B2, .D4, .{.mask = 0x8040_2010_0804_0201});
    try testLineThrough(.C3, .D4, .{.mask = 0x8040_2010_0804_0201});
    try testLineThrough(.D4, .C3, .{.mask = 0x8040_2010_0804_0201});
    try testLineThrough(.D4, .E5, .{.mask = 0x8040_2010_0804_0201});
    try testLineThrough(.D4, .H8, .{.mask = 0x8040_2010_0804_0201});
    try testLineThrough(.A1, .H8, .{.mask = 0x8040_2010_0804_0201});
    // Diagonal A8-H1
    try testLineThrough(.A8, .D5, .{.mask = 0x0102_0408_1020_4080});
    try testLineThrough(.B7, .D5, .{.mask = 0x0102_0408_1020_4080});
    try testLineThrough(.C6, .D5, .{.mask = 0x0102_0408_1020_4080});
    try testLineThrough(.D5, .C6, .{.mask = 0x0102_0408_1020_4080});
    try testLineThrough(.D5, .E4, .{.mask = 0x0102_0408_1020_4080});
    try testLineThrough(.D5, .H1, .{.mask = 0x0102_0408_1020_4080});
    try testLineThrough(.A8, .H1, .{.mask = 0x0102_0408_1020_4080});
    // Non-major diagonal D8-H4
    try testLineThrough(.E7, .G5, .{.mask = 0x0810_2040_8000_0000});
    try testLineThrough(.G5, .E7, .{.mask = 0x0810_2040_8000_0000});
    try testLineThrough(.G5, .H4, .{.mask = 0x0810_2040_8000_0000});
    try testLineThrough(.D8, .H4, .{.mask = 0x0810_2040_8000_0000});
    // Vertical G1-G4
    try testLineThrough(.G1, .G4, .{.mask = 0x4040_4040_4040_4040});
    try testLineThrough(.G1, .G3, .{.mask = 0x4040_4040_4040_4040});
    try testLineThrough(.G1, .G2, .{.mask = 0x4040_4040_4040_4040});
    try testLineThrough(.G4, .G1, .{.mask = 0x4040_4040_4040_4040});
    // Horizontal A5-F5
    try testLineThrough(.A5, .F5, .{.mask = 0x00FF_0000_0000});
    try testLineThrough(.A5, .E5, .{.mask = 0x00FF_0000_0000});
    try testLineThrough(.A5, .D5, .{.mask = 0x00FF_0000_0000});
    try testLineThrough(.A5, .C5, .{.mask = 0x00FF_0000_0000});
    try testLineThrough(.B5, .C5, .{.mask = 0x00FF_0000_0000});
    try testLineThrough(.C5, .F5, .{.mask = 0x00FF_0000_0000});
}

