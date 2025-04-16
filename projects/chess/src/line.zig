///! Methods for dealing with line masks on the board
///! Typically used for sliding piece attacks and move generation
const std = @import("std");
const Bitboard = @import("./bitboard.zig").Bitboard;
const Square = @import("./square.zig").Square;
const SlidingPieceRayDirections = @import("./direction.zig").SlidingPieceRayDirections;

/// Whether two squares are aligned with eachother in a given cardinal or diagonal direction
pub fn alignedAlong(from: Square, to: Square, comptime alignment: SlidingPieceRayDirections) bool {
    if (from == to) return false;
    if (alignment == .cardinal) {
        return from.fileOf() == to.fileOf() or from.rankOf() == to.rankOf();
    } else {
        const rankDiff: u8 = @intFromFloat(@abs(@as(f32, @floatFromInt(@as(i32, @intFromEnum(from.rankOf())) - @as(i32, @intFromEnum(to.rankOf()))))));
        const fileDiff: u8 = @intFromFloat(@abs(@as(f32, @floatFromInt(@as(i32, @intFromEnum(from.fileOf())) - @as(i32, @intFromEnum(to.fileOf()))))));
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
    @setEvalBranchQuota(10_000_000);
    if (!@inComptime()) {
        return through_lookup[@intFromEnum(from)][@intFromEnum(to)];
    }
    for (std.enums.values(SlidingPieceRayDirections)) |direction| {
        if (alignedAlong(from, to, direction)) {
            return from.toBitboard()
                .rayAttacks(direction, Bitboard.empty)
                .logicalAnd(to.toBitboard().rayAttacks(direction, Bitboard.empty))
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
    var result: [num_squares][num_squares]Bitboard = undefined;
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
    @setEvalBranchQuota(10_000_000);
    if (!@inComptime()) {
        return between_lookup[@intFromEnum(from)][@intFromEnum(to)];
    }
    for (std.enums.values(SlidingPieceRayDirections)) |direction| {
        if (alignedAlong(from, to, direction)) {
            return from.toBitboard()
                .rayAttacks(direction, to.toBitboard())
                .logicalAnd(to.toBitboard().rayAttacks(direction, from.toBitboard()));
        }
    }

    return Bitboard.empty;
}

test alignedAlong {
    try std.testing.expectEqual(true, alignedAlong(.a2, .a4, .cardinal));
    try std.testing.expectEqual(false, alignedAlong(.a2, .a4, .diagonal));
    try std.testing.expectEqual(false, alignedAlong(.b3, .a4, .cardinal));
    try std.testing.expectEqual(true, alignedAlong(.b3, .a4, .diagonal));
    try std.testing.expectEqual(false, alignedAlong(.b2, .a4, .cardinal));
    try std.testing.expectEqual(false, alignedAlong(.a2, .b4, .cardinal));
    try std.testing.expectEqual(true, alignedAlong(.a2, .a4, .cardinal));
    try std.testing.expectEqual(false, alignedAlong(.b4, .b4, .diagonal));
    try std.testing.expectEqual(false, alignedAlong(.b4, .b4, .cardinal));
    try std.testing.expectEqual(true, alignedAlong(.b2, .b4, .cardinal));
    try std.testing.expectEqual(false, alignedAlong(.b2, .b4, .diagonal));
    try std.testing.expectEqual(true, alignedAlong(.h1, .a1, .cardinal));
    try std.testing.expectEqual(true, alignedAlong(.a1, .h1, .cardinal));
    try std.testing.expectEqual(true, alignedAlong(.h8, .a1, .diagonal));
}

test aligned {
    try std.testing.expectEqual(true, aligned(.a2, .a4));
    try std.testing.expectEqual(true, aligned(.a2, .a4));
    try std.testing.expectEqual(true, aligned(.b3, .a4));
    try std.testing.expectEqual(false, aligned(.b2, .a4));
    try std.testing.expectEqual(false, aligned(.a2, .b4));
    try std.testing.expectEqual(true, aligned(.a2, .a4));
    try std.testing.expectEqual(false, aligned(.b4, .b4));
    try std.testing.expectEqual(true, aligned(.b2, .b4));
    try std.testing.expectEqual(true, aligned(.h1, .a1));
    try std.testing.expectEqual(true, aligned(.a1, .h1));
    try std.testing.expectEqual(true, aligned(.h8, .a1));
}

test areAligned {
    try std.testing.expectEqual(true, areAligned(.a2, .a4, .a6));
    try std.testing.expectEqual(true, areAligned(.a2, .a4, .a8));
    try std.testing.expectEqual(false, areAligned(.b2, .a4, .a8));
    try std.testing.expectEqual(false, areAligned(.a2, .b4, .a8));
    try std.testing.expectEqual(false, areAligned(.a2, .a4, .b8));
    try std.testing.expectEqual(false, areAligned(.a2, .b4, .b8));
    try std.testing.expectEqual(true, areAligned(.b2, .b4, .b8));
    try std.testing.expectEqual(true, areAligned(.h1, .a1, .c1));
    try std.testing.expectEqual(false, areAligned(.h1, .a1, .c2));
    try std.testing.expectEqual(true, areAligned(.h8, .a1, .d4));
}

test between {
    try std.testing.expectEqualDeep(Bitboard.initInt(0x100800000000), between(.c4, .f7));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.e6, .f8));
    // A1-H8 diagonal
    try std.testing.expectEqualDeep(Bitboard.initInt(0x40201008040200), between(.a1, .h8));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x201008040200), between(.a1, .g7));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x1008040200), between(.a1, .f6));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040200), between(.a1, .e5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040000), between(.b2, .e5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x40000), between(.b2, .d4));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.b3, .d4));
    // G2-G6 vertical
    try std.testing.expectEqualDeep(Bitboard.initInt(0x4040400000), between(.g2, .g6));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x4040000000), between(.g3, .g6));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x4000000000), between(.g4, .g6));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.g4, .g5));
    // F5-A5 horizontal
    try std.testing.expectEqualDeep(Bitboard.initInt(0x1e00000000), between(.f5, .a5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0xe00000000), between(.e5, .a5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x600000000), between(.d5, .a5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x400000000), between(.d5, .b5));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.d5, .c5));
    // Non aligned between
    try std.testing.expectEqualDeep(Bitboard.empty, between(.a5, .b7));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.h1, .c8));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.e4, .c1));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.e4, .d1));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.e4, .f1));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.e4, .g1));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.e4, .e4));
    try std.testing.expectEqualDeep(Bitboard.empty, between(.h8, .h8));
}

test through {
    // Non aligned
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0), through(.a1, .b5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0), through(.a1, .b4));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0), through(.a1, .c4));
    // Diagonal A1-H8
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0201), through(.a1, .d4));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0201), through(.b2, .d4));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0201), through(.c3, .d4));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0201), through(.d4, .c3));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0201), through(.d4, .e5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0201), through(.d4, .h8));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x8040_2010_0804_0201), through(.a1, .h8));
    // Diagonal A8-H1
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_1020_4080), through(.a8, .d5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_1020_4080), through(.b7, .d5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_1020_4080), through(.c6, .d5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_1020_4080), through(.d5, .c6));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_1020_4080), through(.d5, .e4));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_1020_4080), through(.d5, .h1));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0102_0408_1020_4080), through(.a8, .h1));
    // Non-major diagonal D8-H4
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0810_2040_8000_0000), through(.e7, .g5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0810_2040_8000_0000), through(.g5, .e7));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0810_2040_8000_0000), through(.g5, .h4));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x0810_2040_8000_0000), through(.d8, .h4));
    // Vertical G1-G4
    try std.testing.expectEqualDeep(Bitboard.initInt(0x4040_4040_4040_4040), through(.g1, .g4));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x4040_4040_4040_4040), through(.g1, .g3));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x4040_4040_4040_4040), through(.g1, .g2));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x4040_4040_4040_4040), through(.g4, .g1));
    // Horizontal A5-F5
    try std.testing.expectEqualDeep(Bitboard.initInt(0x00FF_0000_0000), through(.a5, .f5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x00FF_0000_0000), through(.a5, .e5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x00FF_0000_0000), through(.a5, .d5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x00FF_0000_0000), through(.a5, .c5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x00FF_0000_0000), through(.b5, .c5));
    try std.testing.expectEqualDeep(Bitboard.initInt(0x00FF_0000_0000), through(.c5, .f5));
}
