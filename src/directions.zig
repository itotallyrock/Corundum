const std = @import("std");
const Player = @import("players.zig").Player;

/// Represents an absolute direction on the board (always from white's perspective).
pub const BoardDirection = enum(i5) {
    north = 8,
    south = -8,
    east = 1,
    west = -1,
    north_east = 9,
    north_west = 7,
    south_east = -7,
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
    forward,
    backward,
    left,
    right,
    forward_left,
    forward_right,
    backward_left,
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
    forward_left = @intFromEnum(RelativeDirection.forward_left),
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
