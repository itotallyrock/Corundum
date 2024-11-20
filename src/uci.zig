const std = @import("std");

/// A parsed incoming UCI command
pub const UciCommand = union(enum) {
    uci: struct {},
    debug: Debug,
    isready: struct {},
    ucinewgame: struct {},
    setoption: SetOption,
    position: Position,
    go: Go,
    stop: struct {},
    ponderhit: struct {},
    quit: struct {},
    register: Register,
};

pub const Debug = struct {
    on: bool,
};

pub const SetOption = struct {
    name: []const u8,
    value: ?[]const u8,
};

pub const Go = struct {
    searchmoves: ?[]const []const u8,
    ponder: bool = false,
    wtime: ?u32,
    btime: ?u32,
    winc: ?u32,
    binc: ?u32,
    movestogo: ?u32,
    depth: ?u32,
    nodes: ?u32,
    mate: ?u32,
    movetime: ?u32,
    infinite: bool = false,
};

pub const Position = struct {
    position: union(enum) {
        fen: []const u8,
        startpos: struct {},
    },
    moves: ?[]const []const u8,
};

pub const Register = union(enum) {
    user: struct {
        name: []const u8,
        code: []const u8,
    },
    later: struct {},
};

pub const UciOptionType = enum {
    check,
    spin,
    combo,
    string,
    button,
};

pub const UciOptionValue = union(UciOptionType) {
    check: bool,
    spin: i32,
    combo: []const u8,
    string: []const u8,
    button,
};

pub const UciOptionConfig = struct {
    name: []const u8,
    config: union(UciOptionType) {
        check: struct {
            default: bool = false,
        },
        spin: struct {
            default: i32,
            min: i32,
            max: i32,
        },
        combo: struct {
            default: []const u8,
            options: []const []const u8,
        },
        string: struct {
            default: []const u8,
        },
        button,
    },

    /// Tries to parse the given value into the correct UciOptionValue
    // Inline since this is often immediately switched on after calling, this switch can be combined with the switch in the caller
    pub fn tryParse(self: UciOptionConfig, value: ?[]const u8) !UciOptionValue {
        // TODO: Possibly use mecha here
        switch (self.config) {
            .check => {
                if (value) |v| {
                    if (v.len == 0) {
                        return .{ .check = self.config.check.default };
                    } else if (std.ascii.eqlIgnoreCase(v, "true")) {
                        return .{ .check = true };
                    } else if (std.ascii.eqlIgnoreCase(v, "false")) {
                        return .{ .check = false };
                    } else {
                        return error.InvalidOptionValue;
                    }
                } else {
                    return .{ .check = self.config.check.default };
                }
            },
            .spin => {
                if (value) |v| {
                    if (v.len > 0) {
                        const i = std.fmt.parseInt(i32, v, 10) catch return error.InvalidOptionValue;
                        if (i < self.config.spin.min or i > self.config.spin.max) {
                            return error.InvalidOptionValue;
                        }
                        return .{ .spin = i };
                    } else {
                        return .{ .spin = self.config.spin.default };
                    }
                } else {
                    return .{ .spin = self.config.spin.default };
                }
            },
            .button => return .button,
            .combo => {
                if (value) |v| {
                    if (v.len == 0) {
                        return .{ .combo = self.config.combo.default };
                    }

                    for (self.config.combo.options) |option| {
                        if (std.mem.eql(u8, v, option)) {
                            return .{ .combo = option };
                        }
                    }
                    return error.InvalidOptionValue;
                } else {
                    return .{ .combo = self.config.combo.default };
                }
            },
            .string => {
                if (value) |v| {
                    return .{ .string = v };
                } else {
                    return .{ .string = self.config.string.default };
                }
            },
        }
    }

    test tryParse {
        const spin_config = UciOptionConfig{
            .name = "test",
            .config = .{ .spin = .{ .default = 10, .min = 0, .max = 100 } },
        };
        try std.testing.expectEqualDeep(UciOptionValue{ .spin = 10 }, try spin_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue{ .spin = 10 }, try spin_config.tryParse(""));
        try std.testing.expectEqualDeep(UciOptionValue{ .spin = 20 }, try spin_config.tryParse("20"));
        try std.testing.expectError(error.InvalidOptionValue, spin_config.tryParse("200"));
        try std.testing.expectError(error.InvalidOptionValue, spin_config.tryParse("a"));

        const check_config = UciOptionConfig{
            .name = "test",
            .config = .{ .check = .{ .default = true } },
        };
        try std.testing.expectEqualDeep(UciOptionValue{ .check = true }, try check_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = true }, try check_config.tryParse(""));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = true }, try check_config.tryParse("true"));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = true }, try check_config.tryParse("tRuE"));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = false }, try check_config.tryParse("false"));
        try std.testing.expectEqualDeep(UciOptionValue{ .check = false }, try check_config.tryParse("fAlSe"));
        try std.testing.expectError(error.InvalidOptionValue, check_config.tryParse("a"));

        const combo_config = UciOptionConfig{
            .name = "test",
            .config = .{ .combo = .{ .default = "a", .options = &[_][]const u8{ "a", "b", "c" } } },
        };
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "a" }, try combo_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "a" }, try combo_config.tryParse(""));
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "a" }, try combo_config.tryParse("a"));
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "b" }, try combo_config.tryParse("b"));
        try std.testing.expectEqualDeep(UciOptionValue{ .combo = "c" }, try combo_config.tryParse("c"));
        try std.testing.expectError(error.InvalidOptionValue, combo_config.tryParse("d"));
        try std.testing.expectError(error.InvalidOptionValue, combo_config.tryParse("C"));

        const string_config = UciOptionConfig{
            .name = "test",
            .config = .{ .string = .{ .default = "a" } },
        };
        try std.testing.expectEqualDeep(UciOptionValue{ .string = "a" }, try string_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue{ .string = "" }, try string_config.tryParse(""));
        try std.testing.expectEqualDeep(UciOptionValue{ .string = "lol" }, try string_config.tryParse("lol"));

        const button_config = UciOptionConfig{
            .name = "test",
            .config = .button,
        };
        try std.testing.expectEqualDeep(UciOptionValue.button, try button_config.tryParse(null));
        try std.testing.expectEqualDeep(UciOptionValue.button, try button_config.tryParse(""));
    }
};

/// A message sent from the engine to the GUI
pub const UciResponse = union(enum) {
    id: union(enum) {
        name: []const u8,
        author: []const u8,
    },
    uciok,
    readyok,
    bestmove: struct {
        move: []const u8,
        ponder: ?[]const u8,
    },
    copyprotection: enum { checking, ok, @"error" },
    registration: enum { checking, ok, @"error" },
    info: struct {
        depth: ?u32,
        seldepth: ?u32,
        time: ?u32,
        nodes: ?u32,
        pv: ?[]const []const u8,
        multipv: ?u32,
        // TODO: Account for upper/lowerbound scores
        score: ?union(enum) { mate: i32, depth: u32 },
        hashfull: ?u32,
        nps: ?u32,
        tbhits: ?u32,
        cpuload: ?u32,
        string: ?[]const u8,
    },
    option: UciOptionConfig,
};
