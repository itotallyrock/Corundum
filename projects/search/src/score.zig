const std = @import("std");
const pawn_grain = @import("search_build_options").pawn_grain;
const max_material_score = @import("search_build_options").max_material_score;
const max_mate_plies = @import("search_build_options").max_mate_plies;
const Ply = @import("corundum_chess").ply.Ply;

/// Granularized/scaled maximum material score
const material_upper_bound: i64 = max_material_score * pawn_grain;
/// The maximum underlying raw score, represents the max pawn value, mates, and infinite.
const infinity: i64 = (material_upper_bound + (max_mate_plies + 1)) + 1;

test "max_mate_plies is less than or equal to max_plies" {
    const max_plies = @import("corundum_chess").ply.max_plies;
    try std.testing.expect(max_mate_plies <= max_plies);
}

/// Raw granularized score integer type
pub const MaterialEvaluationInt = std.math.IntFittingRange(-infinity, infinity);

/// Evaluation of a position.
/// Can be a loss, a win, a draw, or approximate material score.
pub const Score = enum(MaterialEvaluationInt) {
    const Self = @This();

    /// The minumum underlying raw score, used as a bound for alpha-beta searching
    negative_infinity = -infinity,
    /// Lowest possible mated score (most posssible moves for the opponent to mate us)
    max_mated = -material_upper_bound - 1,
    /// Draw, stalemate, insufficient material, etc
    draw = 0,
    /// Lowest possible mate score (most possible moves for the us to mate the opponent)
    max_mate = material_upper_bound + 1,
    /// The maximum underlying raw score, used as a bound for alpha-beta searching
    infinity = infinity,
    /// Any other granularized material score
    _,

    /// Creates an approximate score from a pawn value
    pub fn initFloat(score: f32) Self {
        const clamped_score = std.math.clamp(score, -@as(f32, @floatFromInt(max_material_score)), @as(f32, @floatFromInt(max_material_score)));
        return Self.initGranularized(@intFromFloat(clamped_score * pawn_grain));
    }

    test initFloat {
        try std.testing.expectEqual(Score.initFloat(0.0), Score.draw);
        try std.testing.expectEqual(Score.initFloat(1.0), Score.initGranularized(pawn_grain));
        try std.testing.expectEqual(Score.initGranularized(material_upper_bound), Score.initFloat(@as(f32, @floatFromInt(max_material_score)) + 0.1));
        try std.testing.expectEqual(Score.initGranularized(-material_upper_bound), Score.initFloat(-@as(f32, @floatFromInt(max_material_score)) - 0.1));
        try std.testing.expectEqual(Score.initGranularized(material_upper_bound), Score.initFloat(@as(f32, @floatFromInt(max_material_score)) + 200.0));
        try std.testing.expectEqual(Score.initGranularized(-material_upper_bound), Score.initFloat(-@as(f32, @floatFromInt(max_material_score)) - 200.0));
    }

    /// Creates a material score from an approximate/granularized pawn value
    pub fn initGranularized(granularized_score: MaterialEvaluationInt) Self {
        return @enumFromInt(std.math.clamp(granularized_score, -material_upper_bound, material_upper_bound));
    }

    test initGranularized {
        try std.testing.expectEqual(Score.initGranularized(0), Score.draw);
        try std.testing.expectEqual(Score.initGranularized(100), Score.initGranularized(100));
        try std.testing.expectEqual(Score.initGranularized(material_upper_bound), Score.initGranularized(material_upper_bound + 100));
        try std.testing.expectEqual(Score.initGranularized(-material_upper_bound), Score.initGranularized(-material_upper_bound - 100));
    }

    /// Creates a mated score
    pub fn initMate(plies: Ply) Self {
        const clamped_plies: MaterialEvaluationInt = @intCast(std.math.clamp(plies, 0, max_mate_plies));
        return @enumFromInt(@intFromEnum(Score.infinity) - 1 - clamped_plies);
    }

    test initMate {
        try std.testing.expectEqual(Score.max_mate, Score.initMate(max_mate_plies));
        // Mate next turn is one grain below infinity
        try std.testing.expectEqual(@as(Score, @enumFromInt(@as(MaterialEvaluationInt, @intFromEnum(Score.infinity) - 1))), Score.initMate(0));
    }

    /// Creates a mated score
    pub fn initMated(plies: Ply) Self {
        const clamped_plies: MaterialEvaluationInt = @intCast(std.math.clamp(plies, 0, max_mate_plies));
        return @enumFromInt(@intFromEnum(Score.negative_infinity) + 1 + clamped_plies);
    }

    test initMated {
        try std.testing.expectEqual(Score.max_mated, Score.initMated(max_mate_plies));
        // Mated next turn is one grain above negative infinity
        try std.testing.expectEqual(@as(Score, @enumFromInt(@as(MaterialEvaluationInt, @intFromEnum(Score.negative_infinity) + 1))), Score.initMated(0));
    }

    /// Negates the score (inverts the perspective or player this score is for)
    pub fn negate(self: Score) Score {
        return @enumFromInt(-1 * @intFromEnum(self));
    }

    test negate {
        try std.testing.expectEqual(Score.max_mated, Score.initMate(max_mate_plies).negate());
        try std.testing.expectEqual(Score.max_mate, Score.initMated(max_mate_plies).negate());
        try std.testing.expectEqual(Score.draw, Score.draw.negate());
        try std.testing.expectEqual(Score.infinity, Score.negative_infinity.negate());
        try std.testing.expectEqual(Score.negative_infinity, Score.infinity.negate());
        try std.testing.expectEqual(Score.initGranularized(100), Score.initGranularized(-100).negate());
        try std.testing.expectEqual(Score.initGranularized(-300), Score.initGranularized(300).negate());
    }

    /// Returns true if the score is a definite win (unavoidable checkmate for opponent)
    pub fn isWin(self: Score) bool {
        return @intFromEnum(self) >= @intFromEnum(Self.max_mate);
    }

    test isWin {
        try std.testing.expectEqual(true, Score.max_mate.isWin());
        try std.testing.expectEqual(false, Score.max_mated.isWin());
        try std.testing.expectEqual(false, Score.draw.isWin());
        try std.testing.expectEqual(false, Score.negative_infinity.isWin());
        try std.testing.expectEqual(true, Score.infinity.isWin());
        try std.testing.expectEqual(false, Score.initGranularized(100).isWin());
    }

    /// Returns true if the score is a definite loss (unavoiadable checkmate)
    pub fn isLoss(self: Score) bool {
        return @intFromEnum(self) <= @intFromEnum(Self.max_mated);
    }

    test isLoss {
        try std.testing.expectEqual(false, Score.max_mate.isLoss());
        try std.testing.expectEqual(true, Score.max_mated.isLoss());
        try std.testing.expectEqual(false, Score.draw.isLoss());
        try std.testing.expectEqual(true, Score.negative_infinity.isLoss());
        try std.testing.expectEqual(false, Score.infinity.isLoss());
        try std.testing.expectEqual(false, Score.initGranularized(100).isLoss());
    }

    /// Returns true if the score is a definite win or loss (true when one side has an unavoidable checkmate)
    pub fn isDecisive(self: Score) bool {
        return self.isWin() or self.isLoss();
    }

    test isDecisive {
        try std.testing.expectEqual(true, Score.max_mate.isDecisive());
        try std.testing.expectEqual(true, Score.max_mated.isDecisive());
        try std.testing.expectEqual(false, Score.draw.isDecisive());
        try std.testing.expectEqual(true, Score.infinity.isDecisive());
        try std.testing.expectEqual(true, Score.negative_infinity.isDecisive());
        try std.testing.expectEqual(false, Score.initGranularized(100).isDecisive());
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
        try std.testing.expect(@intFromEnum(Score.initGranularized(100)) > @intFromEnum(Score.draw));
        // Approximate negative is below draw
        try std.testing.expect(@intFromEnum(Score.initGranularized(-100)) < @intFromEnum(Score.draw));
        // Approximate positive is above approximate negative
        try std.testing.expect(@intFromEnum(Score.initGranularized(100)) > @intFromEnum(Score.initGranularized(-100)));
        // Approximate positive is below mate
        try std.testing.expect(@intFromEnum(Score.initGranularized(100)) < @intFromEnum(Score.initMate(0)));
        // Approximate negative is above mated
        try std.testing.expect(@intFromEnum(Score.initGranularized(-100)) > @intFromEnum(Score.initMated(0)));
        // Infinity is above all scores
        try std.testing.expect(@intFromEnum(Score.infinity) > @intFromEnum(Score.negative_infinity));
        try std.testing.expect(@intFromEnum(Score.infinity) > @intFromEnum(Score.draw));
    }
};

test {
    std.testing.refAllDeclsRecursive(@This());
}
