const std = @import("std");
const Player = @import("./player.zig").Player;

/// Represents an absolute direction on the board (always from white's perspective).
pub const BoardDirection = enum(i5) {
    /// Towards the top of the board from whites POV (rank 8).
    north = 8,
    /// Towards the bottom of the board from whites POV (rank 1).
    south = -8,
    /// Towards the right of the board from whites POV (file h).
    east = 1,
    /// Towards the left of the board from whites POV (file a).
    west = -1,
    /// Towards the top right of the board from whites POV (rank 8, file h).
    north_east = 9,
    /// Towards the top left of the board from whites POV (rank 8, file a).
    north_west = 7,
    /// Towards the bottom right of the board from whites POV (rank 1, file h).
    south_east = -7,
    /// Towards the bottom left of the board from whites POV (rank 1, file a).
    south_west = -9,

    /// Returns the direction that is the opposite of this one.
    pub fn opposite(self: BoardDirection) BoardDirection {
        return @enumFromInt(-@intFromEnum(self));
    }

    /// Returns north or south depending on the player.
    pub fn forward(player: Player) BoardDirection {
        switch (player) {
            .white => return .north,
            .black => return .south,
        }
    }

    test opposite {
        try std.testing.expectEqual(BoardDirection.north.opposite(), BoardDirection.south);
        try std.testing.expectEqual(BoardDirection.south.opposite(), BoardDirection.north);
        try std.testing.expectEqual(BoardDirection.east.opposite(), BoardDirection.west);
        try std.testing.expectEqual(BoardDirection.west.opposite(), BoardDirection.east);
        try std.testing.expectEqual(BoardDirection.north_east.opposite(), BoardDirection.south_west);
        try std.testing.expectEqual(BoardDirection.north_west.opposite(), BoardDirection.south_east);
        try std.testing.expectEqual(BoardDirection.south_east.opposite(), BoardDirection.north_west);
        try std.testing.expectEqual(BoardDirection.south_west.opposite(), BoardDirection.north_east);
    }

    test forward {
        try std.testing.expectEqual(BoardDirection.forward(.white), BoardDirection.north);
        try std.testing.expectEqual(BoardDirection.forward(.black), BoardDirection.south);
    }
};

/// A type that is indexed by `BoardDirection`
pub fn ByBoardDirection(comptime T: type) type {
    return std.EnumArray(BoardDirection, T);
}

/// A relative direction on the board, relative to a player's perspective.
pub const RelativeDirection = enum(u3) {
    /// The direction a player's own pawns move
    forward,
    /// Towards your own back rank
    backward,
    /// Towards the left of the board from your perspective
    left,
    /// Towards the right of the board from your perspective
    right,
    /// Towards the enemy's back rank and left
    forward_left,
    /// Towards the enemy's back rank and right
    forward_right,
    /// Towards your own back rank and left
    backward_left,
    /// Towards your own back rank and right
    backward_right,

    /// Given a perspective, returns the corresponding `BoardDirection`.
    pub fn toDirection(self: RelativeDirection, comptime perspective: Player) BoardDirection {
        return switch (self) {
            .forward => if (perspective == .white) .north else .south,
            .backward => if (perspective == .white) .south else .north,
            .left => if (perspective == .white) .west else .east,
            .right => if (perspective == .white) .east else .west,
            .forward_left => if (perspective == .white) .north_west else .north_east,
            .forward_right => if (perspective == .white) .north_east else .north_west,
            .backward_left => if (perspective == .white) .south_west else .south_east,
            .backward_right => if (perspective == .white) .south_east else .south_west,
        };
    }

    test toDirection {
        try std.testing.expectEqual(RelativeDirection.forward.toDirection(.white), BoardDirection.north);
        try std.testing.expectEqual(RelativeDirection.forward.toDirection(.black), BoardDirection.south);
        try std.testing.expectEqual(RelativeDirection.backward.toDirection(.white), BoardDirection.south);
        try std.testing.expectEqual(RelativeDirection.backward.toDirection(.black), BoardDirection.north);
        try std.testing.expectEqual(RelativeDirection.left.toDirection(.white), BoardDirection.west);
        try std.testing.expectEqual(RelativeDirection.left.toDirection(.black), BoardDirection.east);
        try std.testing.expectEqual(RelativeDirection.right.toDirection(.white), BoardDirection.east);
        try std.testing.expectEqual(RelativeDirection.right.toDirection(.black), BoardDirection.west);
        try std.testing.expectEqual(RelativeDirection.forward_left.toDirection(.white), BoardDirection.north_west);
        try std.testing.expectEqual(RelativeDirection.forward_left.toDirection(.black), BoardDirection.north_east);
        try std.testing.expectEqual(RelativeDirection.forward_right.toDirection(.white), BoardDirection.north_east);
        try std.testing.expectEqual(RelativeDirection.forward_right.toDirection(.black), BoardDirection.north_west);
        try std.testing.expectEqual(RelativeDirection.backward_left.toDirection(.white), BoardDirection.south_west);
        try std.testing.expectEqual(RelativeDirection.backward_left.toDirection(.black), BoardDirection.south_east);
        try std.testing.expectEqual(RelativeDirection.backward_right.toDirection(.white), BoardDirection.south_east);
        try std.testing.expectEqual(RelativeDirection.backward_right.toDirection(.black), BoardDirection.south_west);
    }
};

/// Represents the relative direction a pawn can attack in.
pub const PawnAttackDirection = enum(u3) {
    /// The direction a pawn attacks forward (diagonal left).
    forward_left = @intFromEnum(RelativeDirection.forward_left),
    /// The direction a pawn attacks forward (diagonal right).
    forward_right = @intFromEnum(RelativeDirection.forward_right),

    /// Returns the `RelativeDirection` corresponding to this `PawnAttackDirection`.s
    pub fn toRelativeDirection(self: PawnAttackDirection) RelativeDirection {
        return @enumFromInt(@intFromEnum(self));
    }

    test toRelativeDirection {
        try std.testing.expectEqual(PawnAttackDirection.forward_left.toRelativeDirection(), RelativeDirection.forward_left);
        try std.testing.expectEqual(PawnAttackDirection.forward_right.toRelativeDirection(), RelativeDirection.forward_right);
    }
};

/// Represents the two types of sliding piece directions.
pub const SlidingPieceRayDirections = enum(u1) {
    /// Represents straight vertical or horizontal sliding (Rooks and Queens).
    cardinal,
    /// Represents diagonal sliding (Bishops and Queens).
    diagonal,
};
