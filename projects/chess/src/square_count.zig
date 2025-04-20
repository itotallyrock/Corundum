const std = @import("std");

const Square = @import("./square.zig").Square;

/// Type containing a number of squares.
/// Typically represents the number of pieces on the board, and can represent count of single piece type or any grouping of pieces.
pub const SquareCount = std.math.IntFittingRange(0, std.enums.values(Square).len);

test SquareCount {
    try std.testing.expectEqual(7, @bitSizeOf(SquareCount));
}
