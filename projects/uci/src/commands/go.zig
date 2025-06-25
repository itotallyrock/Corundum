
const std = @import("std");

pub const GoTimeControls = union(enum) {
    infinite: struct {},
    search_time_ms: u32,
    move_clock: struct {
        white_time_ms: u32,
        white_increment_ms: ?u32,
        black_time_ms: u32,
        black_increment_ms: ?u32,
    },
};

const PartialTimeControls = struct {
    const Self = @This();
    infinite: bool = false,
    search_time_ms: ?u32 = null,
    white_time_ms: ?u32 = null,
    white_increment_ms: ?u32 = null,
    black_time_ms: ?u32 = null,
    black_increment_ms: ?u32 = null,

    fn controlsType(self: Self) ?enum{ infinite, search_time_ms, move_clock } {
        if (self.infinite) {
            return .infinite;
        } else if (self.search_time_ms != null) {
            return .search_time_ms;
        } else if (self.white_time_ms != null or self.black_time_ms != null or self.white_increment_ms != null or self.black_increment_ms != null) {
            return .move_clock;
        }
        return null;
    }

    fn toTimeControls(self: Self) !GoTimeControls {
        if (self.controlsType()) |controls_type| {
            switch (controls_type) {
                .infinite => return .{ .infinite = .{} },
                .search_time_ms => return .{ .search_time_ms = self.search_time_ms.? },
                .move_clock => {
                    const white_time = self.white_time_ms orelse return error.InvalidGoCommandMissingWhiteTime;
                    const black_time = self.black_time_ms orelse return error.InvalidGoCommandMissingBlackTime;
                    return .{ .move_clock = .{
                        .white_time_ms = white_time,
                        .white_increment_ms = self.white_increment_ms,
                        .black_time_ms = black_time,
                        .black_increment_ms = self.black_increment_ms,
                    }};
                },
            }
        } else {
            return .{ .infinite = .{} };
        }
    }
};

pub const Go = struct {
    time_controls: GoTimeControls = .{ .infinite = .{} },
    ponder: bool = false,
    search_moves: ?std.mem.TokenIterator(u8, .scalar) = null,
    depth: ?u32 = null,
    nodes: ?u64 = null,
    mate: ?u8 = null,

    pub fn parse(source: []const u8) !?Go {
        if (std.ascii.startsWithIgnoreCase(source, "go")) {
            var go = Go{ .time_controls = .{ .infinite = .{} } };
            var partial_tc: PartialTimeControls = .{};
            const command = std.mem.trimLeft(u8, source[2..], " ");
            var tokens = std.mem.tokenizeScalar(u8, command, ' ');

            while (tokens.next()) |token| {
                if (std.ascii.eqlIgnoreCase(token, "infinite")) {
                    if (partial_tc.controlsType()) |tc| {
                        // Cannot specify infinite with other time controls
                        switch (tc) {
                            // Infinite specified multiple times, do nothing
                            .infinite => continue,
                            else => return error.InvalidGoCommandMixedTimeControls,
                        }
                    } else {
                        partial_tc.infinite = true;
                        continue;
                    }
                }

                if (std.ascii.eqlIgnoreCase(token, "movetime")) {
                    if (tokens.next()) |time_str| {
                        if (partial_tc.controlsType()) |tc| {
                            // Cannot specify movetime with infinite time control
                            return switch (tc) {
                                .search_time_ms => error.InvalidGoCommandMultipleMoveTimes,
                                else => error.InvalidGoCommandMixedTimeControls,
                            };
                        } else {
                            const time_ms = std.fmt.parseInt(u32, time_str, 10) catch |err| return switch (err) {
                                error.Overflow => error.InvalidGoCommandInvalidMoveTimeTooLarge,
                                error.InvalidCharacter => error.InvalidGoCommandInvalidMoveTimeCharacter,
                            };
                            partial_tc.search_time_ms = time_ms;
                            continue;
                        }
                    } else {
                        return error.InvalidGoCommandMissingMoveTime;
                    }
                }

                if (std.ascii.eqlIgnoreCase(token, "depth")) {
                    if (tokens.next()) |depth_str| {
                        go.depth = std.fmt.parseInt(u32, depth_str, 10) catch |err| return switch (err) {
                            error.Overflow => error.InvalidGoCommandInvalidDepthTooLarge,
                            error.InvalidCharacter => error.InvalidGoCommandInvalidDepthCharacter,
                        };
                        continue;
                    } else {
                        return error.InvalidGoCommandMissingDepth;
                    }
                }

                if (std.ascii.eqlIgnoreCase(token, "nodes")) {
                    if (tokens.next()) |nodes_str| {
                        go.nodes = std.fmt.parseInt(u64, nodes_str, 10) catch |err| return switch (err) {
                            error.Overflow => error.InvalidGoCommandInvalidNodesTooLarge,
                            error.InvalidCharacter => error.InvalidGoCommandInvalidNodesCharacter,
                        };
                        continue;
                    } else {
                        return error.InvalidGoCommandMissingNodes;
                    }
                }

                if (std.ascii.eqlIgnoreCase(token, "mate")) {
                    if (tokens.next()) |mate_str| {
                        go.mate = std.fmt.parseInt(u8, mate_str, 10) catch |err| return switch (err) {
                            error.Overflow => error.InvalidGoCommandInvalidMatePliesTooLarge,
                            error.InvalidCharacter => error.InvalidGoCommandInvalidMatePliesCharacter,
                        };
                        continue;
                    } else {
                        return error.InvalidGoCommandMissingMatePlies;
                    }
                }

                if (std.ascii.eqlIgnoreCase(token, "ponder")) {
                    go.ponder = true;
                    continue;
                }

                if (std.ascii.eqlIgnoreCase(token, "searchmoves")) {
                    const remaining_str = tokens.rest();
                    const end_index = @min(std.ascii.indexOfIgnoreCase(remaining_str, "depth") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "nodes") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "movetime") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "mate") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "wtime") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "btime") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "winc") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "binc") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "infinite") orelse remaining_str.len,
                    std.ascii.indexOfIgnoreCase(remaining_str, "ponder") orelse remaining_str.len);

                    const moves_str = std.mem.trim(u8, remaining_str[0..end_index], " ");
                    if (moves_str.len > 0) {
                        go.search_moves = std.mem.tokenizeScalar(u8, moves_str, ' ');
                        tokens = std.mem.tokenizeScalar(u8, remaining_str[end_index..], ' ');
                        continue;
                    } else {
                        return error.InvalidGoCommandMissingSearchMoves;
                    }
                }

                // TODO: Check for remaining time control arguments (we probably need to switch to 4 optional u32s for wtime, winc, btime, binc and a optional infinite and movetime then compute the TC once at the end)
                if (std.ascii.eqlIgnoreCase(token, "wtime")) {
                    if (tokens.next()) |wtime_str| {
                        if (partial_tc.controlsType()) |tc| {
                            // Cannot specify wtime with other time controls
                            return switch (tc) {
                                .move_clock => {
                                    partial_tc.white_time_ms = std.fmt.parseInt(u32, wtime_str, 10) catch |err| return switch (err) {
                                        error.Overflow => error.InvalidGoCommandInvalidWhiteTimeTooLarge,
                                        error.InvalidCharacter => error.InvalidGoCommandInvalidWhiteTimeCharacter,
                                    };
                                    continue;
                                },
                                else => error.InvalidGoCommandMixedTimeControls,
                            };
                        } else {
                            partial_tc.white_time_ms = std.fmt.parseInt(u32, wtime_str, 10) catch |err| return switch (err) {
                                error.Overflow => error.InvalidGoCommandInvalidWhiteTimeTooLarge,
                                error.InvalidCharacter => error.InvalidGoCommandInvalidWhiteTimeCharacter,
                            };
                            continue;
                        }
                    } else {
                        return error.InvalidGoCommandMissingWhiteTime;
                    }
                }

                if (std.ascii.eqlIgnoreCase(token, "winc")) {
                    if (tokens.next()) |winc_str| {
                        if (partial_tc.controlsType()) |tc| {
                            // Cannot specify winc with other time controls
                            return switch (tc) {
                                .move_clock => {
                                    partial_tc.white_increment_ms = std.fmt.parseInt(u32, winc_str, 10) catch |err| return switch (err) {
                                        error.Overflow => error.InvalidGoCommandInvalidWhiteIncrementTooLarge,
                                        error.InvalidCharacter => error.InvalidGoCommandInvalidWhiteIncrementCharacter,
                                    };
                                    continue;
                                },
                                else => error.InvalidGoCommandMixedTimeControls,
                            };
                        } else {
                            partial_tc.white_increment_ms = std.fmt.parseInt(u32, winc_str, 10) catch |err| return switch (err) {
                                error.Overflow => error.InvalidGoCommandInvalidWhiteIncrementTooLarge,
                                error.InvalidCharacter => error.InvalidGoCommandInvalidWhiteIncrementCharacter,
                            };
                            continue;
                        }
                    } else {
                        return error.InvalidGoCommandMissingWhiteIncrement;
                    }
                }

                if (std.ascii.eqlIgnoreCase(token, "btime")) {
                    if (tokens.next()) |btime_str| {
                        if (partial_tc.controlsType()) |tc| {
                            // Cannot specify btime with other time controls
                            return switch (tc) {
                                .move_clock => {
                                    partial_tc.black_time_ms = std.fmt.parseInt(u32, btime_str, 10) catch |err| return switch (err) {
                                        error.Overflow => error.InvalidGoCommandInvalidBlackTimeTooLarge,
                                        error.InvalidCharacter => error.InvalidGoCommandInvalidBlackTimeCharacter,
                                    };
                                    continue;
                                },
                                else => error.InvalidGoCommandMixedTimeControls,
                            };
                        } else {
                            partial_tc.black_time_ms = std.fmt.parseInt(u32, btime_str, 10) catch |err| return switch (err) {
                                error.Overflow => error.InvalidGoCommandInvalidBlackTimeTooLarge,
                                error.InvalidCharacter => error.InvalidGoCommandInvalidBlackTimeCharacter,
                            };
                            continue;
                        }
                    } else {
                        return error.InvalidGoCommandMissingBlackTime;
                    }
                }

                if (std.ascii.eqlIgnoreCase(token, "binc")) {
                    if (tokens.next()) |binc_str| {
                        if (partial_tc.controlsType()) |tc| {
                            // Cannot specify binc with other time controls
                            return switch (tc) {
                                .move_clock => {
                                    partial_tc.black_increment_ms = std.fmt.parseInt(u32, binc_str, 10) catch |err| return switch (err) {
                                        error.Overflow => error.InvalidGoCommandInvalidBlackIncrementTooLarge,
                                        error.InvalidCharacter => error.InvalidGoCommandInvalidBlackIncrementCharacter,
                                    };
                                    continue;
                                },
                                else => error.InvalidGoCommandMixedTimeControls,
                            };
                        } else {
                            partial_tc.black_increment_ms = std.fmt.parseInt(u32, binc_str, 10) catch |err| return switch (err) {
                                error.Overflow => error.InvalidGoCommandInvalidBlackIncrementTooLarge,
                                error.InvalidCharacter => error.InvalidGoCommandInvalidBlackIncrementCharacter,
                            };
                            continue;
                        }
                    } else {
                        return error.InvalidGoCommandMissingBlackIncrement;
                    }
                }

                return error.InvalidGoCommandUnknownOption;
            }

            go.time_controls = try partial_tc.toTimeControls();

            return go;
        }

        return null;
    }
};

test Go {
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .infinite = .{} } }, Go.parse("go"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .infinite = .{} } }, Go.parse("GO"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .search_time_ms = 1000 } }, Go.parse("go movetime 1000"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .search_time_ms = 350_000 } }, Go.parse("go movetime 350_000"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .move_clock = .{ .white_time_ms = 35_000, .black_time_ms = 35_000, .white_increment_ms = 1000, .black_increment_ms = 1000 } } }, Go.parse("go wtime 35000 btime 35000 winc 1000 binc 1000"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .infinite = .{} }, .search_moves = std.mem.tokenizeScalar(u8, "e2e4 d2d4", ' ') }, Go.parse("go infinite searchmoves e2e4 d2d4"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .infinite = .{} }, .search_moves = std.mem.tokenizeScalar(u8, "e2e4 d2d4", ' '), .ponder = true }, Go.parse("go infinite searchmoves e2e4 d2d4 ponder"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .move_clock = .{ .white_time_ms = 120_000, .black_time_ms = 30_000, .white_increment_ms = 1000, .black_increment_ms = 1500 } }, .search_moves = std.mem.tokenizeScalar(u8, "b2f4 d8d7", ' '), .ponder = true }, Go.parse("go searchmoves b2f4 d8d7 ponder wtime 120000 btime 30000 winc 1000 binc 1500"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .search_time_ms = 5000 }, .depth = 10 }, Go.parse("go depth 10 movetime 5000"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .search_time_ms = 15_000 }, .nodes = 100_000_000 }, Go.parse("go nodes 100000000 movetime 15000"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .search_time_ms = 25_000 }, .nodes = 1e9 }, Go.parse("go nodes 1000000000 movetime 25000"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .search_time_ms = 1000 }, .ponder = true, .search_moves = std.mem.tokenizeScalar(u8, "e2e4 d2d4", ' ') }, Go.parse("go ponder movetime 1000 searchmoves e2e4 d2d4"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .infinite = .{} } }, Go.parse("go infinite"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .infinite = .{} }, .ponder = true }, Go.parse("go infinite ponder"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .infinite = .{} }, .mate = 5 }, Go.parse("go infinite mate 5"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .infinite = .{} }, .mate = 50 }, Go.parse("go mate 50"));
    try std.testing.expectEqualDeep(Go{ .time_controls = .{ .search_time_ms = 2000 }, .mate = 3 }, Go.parse("go movetime 2000 mate 3"));
    // Error cases
    try std.testing.expectError(error.InvalidGoCommandInvalidMatePliesTooLarge, Go.parse("go mate 500"));
    try std.testing.expectError(error.InvalidGoCommandInvalidMatePliesCharacter, Go.parse("go mate invalid"));
    try std.testing.expectError(error.InvalidGoCommandMissingMatePlies, Go.parse("go mate"));
    try std.testing.expectError(error.InvalidGoCommandMissingMoveTime, Go.parse("go movetime"));
    try std.testing.expectError(error.InvalidGoCommandMissingDepth, Go.parse("go depth"));
    try std.testing.expectError(error.InvalidGoCommandMissingNodes, Go.parse("go nodes"));
    try std.testing.expectError(error.InvalidGoCommandMissingWhiteTime, Go.parse("go wtime"));
    try std.testing.expectError(error.InvalidGoCommandMissingBlackTime, Go.parse("go btime"));
    try std.testing.expectError(error.InvalidGoCommandMissingWhiteIncrement, Go.parse("go winc"));
    try std.testing.expectError(error.InvalidGoCommandMissingBlackIncrement, Go.parse("go binc"));
    try std.testing.expectError(error.InvalidGoCommandMixedTimeControls, Go.parse("go movetime 1000 wtime 5000 btime 5000"));
    try std.testing.expectError(error.InvalidGoCommandMixedTimeControls, Go.parse("go movetime 1000 infinite"));
    try std.testing.expectError(error.InvalidGoCommandMixedTimeControls, Go.parse("go movetime 1000 btime 1000 wtime 1000"));
    try std.testing.expectError(error.InvalidGoCommandMixedTimeControls, Go.parse("go infinite winc 5000"));
    try std.testing.expectError(error.InvalidGoCommandMixedTimeControls, Go.parse("go winc 5000 infinite"));
    try std.testing.expectError(error.InvalidGoCommandMixedTimeControls, Go.parse("go winc 5000 movetime 1000"));
    try std.testing.expectError(error.InvalidGoCommandMultipleMoveTimes, Go.parse("go movetime 1000 movetime 2000"));
    try std.testing.expectError(error.InvalidGoCommandInvalidMoveTimeCharacter, Go.parse("go movetime invalid"));
    try std.testing.expectError(error.InvalidGoCommandInvalidMoveTimeTooLarge, Go.parse("go movetime 50000000000000000000"));
    try std.testing.expectError(error.InvalidGoCommandInvalidDepthCharacter, Go.parse("go depth invalid"));
    try std.testing.expectError(error.InvalidGoCommandInvalidDepthTooLarge, Go.parse("go depth 50000000000000000000"));
    try std.testing.expectError(error.InvalidGoCommandInvalidNodesCharacter, Go.parse("go nodes invalid"));
    try std.testing.expectError(error.InvalidGoCommandInvalidNodesTooLarge, Go.parse("go nodes 5000000000000000000000000000000000"));
    try std.testing.expectError(error.InvalidGoCommandInvalidWhiteTimeCharacter, Go.parse("go wtime invalid"));
    try std.testing.expectError(error.InvalidGoCommandInvalidWhiteTimeTooLarge, Go.parse("go wtime 50000000000000000000"));
    try std.testing.expectError(error.InvalidGoCommandInvalidBlackTimeCharacter, Go.parse("go btime invalid"));
    try std.testing.expectError(error.InvalidGoCommandInvalidBlackTimeTooLarge, Go.parse("go btime 50000000000000000000"));
    try std.testing.expectError(error.InvalidGoCommandInvalidWhiteIncrementCharacter, Go.parse("go winc invalid"));
    try std.testing.expectError(error.InvalidGoCommandInvalidWhiteIncrementTooLarge, Go.parse("go winc 50000000000000000000"));
    try std.testing.expectError(error.InvalidGoCommandInvalidBlackIncrementCharacter, Go.parse("go binc invalid"));
    try std.testing.expectError(error.InvalidGoCommandInvalidBlackIncrementTooLarge, Go.parse("go binc 50000000000000000000"));
    try std.testing.expectError(error.InvalidGoCommandUnknownOption, Go.parse("go unknown_option"));
    // time controls missing white or black
    try std.testing.expectError(error.InvalidGoCommandMissingBlackTime, Go.parse("go wtime 5000"));
    try std.testing.expectError(error.InvalidGoCommandMissingWhiteTime, Go.parse("go btime 5000"));
    // not a go command
    try std.testing.expectEqual(null, Go.parse("not a go command"));
}