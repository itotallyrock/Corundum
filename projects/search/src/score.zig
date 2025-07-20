const std = @import("std");
const use_precise_score = @import("search_build_options").precise_score;
const MAX_PLIES = @import("corundum_chess").ply.MAX_PLIES;
const Ply = @import("corundum_chess").ply.Ply;

/// How many decimals of precision for the smallest value (a pawn) to use when approximating the position evaluation.
const pawn_grain = if (use_precise_score) 6 else 2;
/// The maximum value in pawns that a specific side should be able to reach
const max_pawn_value = 160;
const pawn_upper_bound = max_pawn_value * std.math.pow(i64, 10, pawn_grain);
const max_mate_plies = MAX_PLIES;
/// The maximum underlying raw score, represents the max pawn value, mates, and infinite.
const infinity = pawn_upper_bound + max_mate_plies + 1;

pub const PawnEvaluation = std.math.IntFittingRange(-infinity, infinity);

pub const Score = enum(PawnEvaluation) {
    const Self = @This();

    negative_infinity = -infinity,
    mated = -infinity + max_mate_plies + 1,
    draw = 0,
    mate = infinity - max_mate_plies - 1,
    infinity = infinity,
    _,

    /// Creates an approximate score from a pawn value
    pub fn initApproximate(pawns: PawnEvaluation) Self {
        // std.debug.assert(pawns <= max_pawn_value and pawns >= -max_pawn_value);
        return @enumFromInt(pawns);
    }

    test initApproximate {
        try std.testing.expectEqual(Score.initApproximate(0), Score.draw);
        try std.testing.expectEqual(Score.initApproximate(100), Score.initApproximate(100));
    }

    /// Creates a mated score
    pub fn initMate(plies: Ply) Self {
        return @enumFromInt(@intFromEnum(Self.mate) - plies);
    }

    test initMate {
        try std.testing.expectEqual(Score.mate, Score.initMate(0));
    }

    /// Creates a mated score
    pub fn initMated(plies: Ply) Self {
        return @enumFromInt(@intFromEnum(Self.mated) + plies);
    }

    test initMated {
        try std.testing.expectEqual(Score.mated, Score.initMated(0));
    }

    /// Negates the score (inverts the perspective or player this score is for)
    pub fn negate(self: Score) Score {
        return @enumFromInt(-1 * @intFromEnum(self));
    }

    test negate {
        try std.testing.expectEqual(Score.mated, Score.initMate(0).negate());
        try std.testing.expectEqual(Score.mate, Score.initMated(0).negate());
        try std.testing.expectEqual(Score.draw, Score.draw.negate());
        try std.testing.expectEqual(Score.infinity, Score.negative_infinity.negate());
        try std.testing.expectEqual(Score.negative_infinity, Score.infinity.negate());
        try std.testing.expectEqual(Score.initApproximate(100), Score.initApproximate(-100).negate());
        try std.testing.expectEqual(Score.initApproximate(-300), Score.initApproximate(300).negate());
    }

    /// Returns true if the score is a definite win (unavoidable checkmate for opponent)
    pub fn isWin(self: Score) bool {
        return @intFromEnum(self) >= @intFromEnum(Self.mate);
    }

    test isWin {
        try std.testing.expectEqual(true, Score.mate.isWin());
        try std.testing.expectEqual(false, Score.mated.isWin());
        try std.testing.expectEqual(false, Score.draw.isWin());
        try std.testing.expectEqual(false, Score.negative_infinity.isWin());
        try std.testing.expectEqual(true, Score.infinity.isWin());
        try std.testing.expectEqual(false, Score.initApproximate(100).isWin());
    }

    /// Returns true if the score is a definite loss (unavoiadable checkmate)
    pub fn isLoss(self: Score) bool {
        return @intFromEnum(self) <= @intFromEnum(Self.mated);
    }

    test isLoss {
        try std.testing.expectEqual(false, Score.mate.isLoss());
        try std.testing.expectEqual(true, Score.mated.isLoss());
        try std.testing.expectEqual(false, Score.draw.isLoss());
        try std.testing.expectEqual(true, Score.negative_infinity.isLoss());
        try std.testing.expectEqual(false, Score.infinity.isLoss());
        try std.testing.expectEqual(false, Score.initApproximate(100).isLoss());
    }

    /// Returns true if the score is a definite win or loss (true when one side has an unavoidable checkmate)
    pub fn isDecisive(self: Score) bool {
        return self.isWin() or self.isLoss();
    }

    test isDecisive {
        try std.testing.expectEqual(true, Score.mate.isDecisive());
        try std.testing.expectEqual(true, Score.mated.isDecisive());
        try std.testing.expectEqual(false, Score.draw.isDecisive());
        try std.testing.expectEqual(true, Score.infinity.isDecisive());
        try std.testing.expectEqual(true, Score.negative_infinity.isDecisive());
        try std.testing.expectEqual(false, Score.initApproximate(100).isDecisive());
    }

    test "ordering" {
        // Mated scores are ordered by number of plies
        try std.testing.expect(@intFromEnum(Score.initMated(1)) > @intFromEnum(Score.initMated(0)));
        try std.testing.expect(@intFromEnum(Score.initMated(1)) < @intFromEnum(Score.initMated(2)));
        // Mate scores are ordered by number of plies
        try std.testing.expect(@intFromEnum(Score.initMate(0)) > @intFromEnum(Score.initMate(1)));
        try std.testing.expect(@intFromEnum(Score.initMate(0)) > @intFromEnum(Score.initMate(2)));
        // Mate scores are above mated scores
        try std.testing.expect(@intFromEnum(Score.initMate(0)) > @intFromEnum(Score.initMated(0)));
        // Mated score is below draw score
        try std.testing.expect(@intFromEnum(Score.initMated(0)) < @intFromEnum(Score.draw));
        // Approximate positive is above draw
        try std.testing.expect(@intFromEnum(Score.initApproximate(100)) > @intFromEnum(Score.draw));
        // Approximate negative is below draw
        try std.testing.expect(@intFromEnum(Score.initApproximate(-100)) < @intFromEnum(Score.draw));
        // Approximate positive is above approximate negative
        try std.testing.expect(@intFromEnum(Score.initApproximate(100)) > @intFromEnum(Score.initApproximate(-100)));
        // Approximate positive is below mate
        try std.testing.expect(@intFromEnum(Score.initApproximate(100)) < @intFromEnum(Score.initMate(0)));
        // Approximate negative is above mated
        try std.testing.expect(@intFromEnum(Score.initApproximate(-100)) > @intFromEnum(Score.initMated(0)));
        // Infinity is above all scores
        try std.testing.expect(@intFromEnum(Score.infinity) > @intFromEnum(Score.negative_infinity));
        try std.testing.expect(@intFromEnum(Score.infinity) > @intFromEnum(Score.draw));
    }
};

test "score is correct size" {
    try std.testing.expectEqual(if (use_precise_score) 4 else 2, @sizeOf(Score));
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
