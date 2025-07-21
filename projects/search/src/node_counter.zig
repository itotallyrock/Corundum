const std = @import("std");

/// The maximum number of nodes a game/search can reach
pub const max_nodes = @import("search_build_options").max_nodes;

/// A ply is a half-move in chess. It is used to represent the number of moves made in a game.
pub const NodeCount = std.math.IntFittingRange(0, max_nodes);

/// A NodeCounter is used to track the number of nodes a search has reached.
pub const NodeCounter = struct {
    count: std.atomic.Value(NodeCount) = .init(0),

    /// Visits a node
    pub fn increment(self: *NodeCounter) void {
        _ = self.count.fetchAdd(1, .seq_cst);
    }

    test increment {
        var counter = NodeCounter{};
        counter.increment();
        try std.testing.expectEqual(counter.count.load(.seq_cst), 1);
        counter.increment();
        try std.testing.expectEqual(counter.count.load(.seq_cst), 2);
    }
};

test {
    std.testing.refAllDecls(@This());
}
