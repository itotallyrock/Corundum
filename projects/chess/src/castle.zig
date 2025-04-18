const std = @import("std");
const Player = @import("./player.zig").Player;
const ByPlayer = @import("./player.zig").ByPlayer;
const File = @import("./square.zig").File;

/// What set of castling rules are in effect.
pub const CastleGameType = enum {
    /// The standard rules for castling.
    standard,
    /// Chess 960 or Fischer Random Chess rules for castling.
    fischer_random,
};

/// Specifies the configuration of castling by the castle ruleset for each game-type.
/// This can be either the standard configuration or the Fischer Random configuration.
pub const CastleConfig = union(CastleGameType) {
    /// The standard configuration (king on the E file, rooks on A & H files).
    standard: struct {},
    /// The Fischer Random Chess or Chess 960 configuration.
    fischer_random: struct {
        /// The starting files for the rooks in Fischer Random Chess.
        starting_rook_files: ByCastleDirection(File),
        /// The starting file for the king in Fischer Random Chess.
        starting_king_file: File,
    },

    /// The starting files for the rooks
    pub fn startingRookFiles(self: CastleConfig) ByCastleDirection(File) {
        return switch (self) {
            .standard => ByCastleDirection(File).init(.{ .king_side = File.h, .queen_side = File.a }),
            .fischer_random => self.fischer_random.starting_rook_files,
        };
    }

    /// The starting file for the king
    pub fn startingKingFile(self: CastleConfig) File {
        return switch (self) {
            .standard => File.e,
            .fischer_random => self.fischer_random.starting_king_file,
        };
    }

    /// Returns whether the configuration is Fischer Random Chess.
    pub fn isFischerRandom(self: CastleConfig) bool {
        return self == .fischer_random;
    }

    test "isFishcerRandom" {
        const standard_config = CastleConfig{ .standard = .{} };
        const fischer_random_config = CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = File.g, .queen_side = File.b }) } };
        const fischer_random_copying_standard_config = CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = File.h, .queen_side = File.a }) } };

        // Fischer Random configuration is correctly identified as such.
        try std.testing.expectEqual(false, standard_config.isFischerRandom());
        try std.testing.expectEqual(true, fischer_random_config.isFischerRandom());

        // Still indicates that the configuration is Fischer Random despite copying the standard configuration.
        try std.testing.expectEqual(true, fischer_random_copying_standard_config.isFischerRandom());
    }

    test "startingRookFiles" {
        const standard_config = CastleConfig{ .standard = .{} };
        const fischer_random_config = CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = File.g, .queen_side = File.b }) } };
        const fischer_random_copying_standard_config = CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = File.h, .queen_side = File.a }) } };

        // Standard configuration has the correct starting rook files.
        try std.testing.expectEqualDeep(ByCastleDirection(File).init(.{
            .king_side = .h,
            .queen_side = .a,
        }), standard_config.startingRookFiles());

        // Fischer Random configuration has the correct starting rook files.
        try std.testing.expectEqualDeep(ByCastleDirection(File).init(.{
            .king_side = .g,
            .queen_side = .b,
        }), fischer_random_config.startingRookFiles());

        // Fischer Random configuration has the correct starting rook files even when copying the standard configuration.
        try std.testing.expectEqualDeep(ByCastleDirection(File).init(.{
            .king_side = .h,
            .queen_side = .a,
        }), fischer_random_copying_standard_config.startingRookFiles());
    }
};

/// Simple flag container to keep track of which players can castle in which directions.
/// Does not track legality or other positional constraints on castling.
pub const CastleAbilities = packed struct {
    /// No castle abilities.
    pub const none = CastleAbilities{ .abilities = Abilities.initEmpty() };
    /// All castle abilities.
    pub const all = CastleAbilities{ .abilities = Abilities.initFull() };

    /// Internal representation of the castle abilities.
    const Abilities = std.bit_set.IntegerBitSet(std.enums.values(CastleDirection).len * std.enums.values(Player).len);

    /// The abilities for each player.
    abilities: Abilities,

    /// Helper function to get the index of the ability for the given player and direction.
    fn getAbilityIndex(player: Player, direction: CastleDirection) usize {
        return std.enums.values(Player).len * @intFromEnum(direction) + @intFromEnum(player);
    }

    /// Initializes the castle abilities given a `ByPlayer` of `ByCastleDirection` booleans.
    pub fn init(can_castle: ByPlayer(ByCastleDirection(bool))) CastleAbilities {
        var ability = Abilities.initEmpty();
        inline for (comptime std.enums.values(Player)) |player| {
            inline for (comptime std.enums.values(CastleDirection)) |direction| {
                ability.setValue(getAbilityIndex(player, direction), can_castle.get(player).get(direction));
            }
        }
        return CastleAbilities{ .abilities = ability };
    }

    test init {
        const castle_abilities = CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = false,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = true,
            }),
        }));
        try std.testing.expectEqual(true, castle_abilities.hasAbility(.white, .king_side));
        try std.testing.expectEqual(false, castle_abilities.hasAbility(.white, .queen_side));
        try std.testing.expectEqual(false, castle_abilities.hasAbility(.black, .king_side));
        try std.testing.expectEqual(true, castle_abilities.hasAbility(.black, .queen_side));
    }

    /// Returns whether the given player can castle in the specified direction.
    pub fn hasAbility(self: CastleAbilities, player: Player, direction: CastleDirection) bool {
        return self.abilities.isSet(getAbilityIndex(player, direction));
    }

    test hasAbility {
        const all_abilities = CastleAbilities.all;
        try std.testing.expectEqual(true, all_abilities.hasAbility(.white, .king_side));
        try std.testing.expectEqual(true, all_abilities.hasAbility(.white, .queen_side));
        try std.testing.expectEqual(true, all_abilities.hasAbility(.black, .king_side));
        try std.testing.expectEqual(true, all_abilities.hasAbility(.black, .queen_side));

        const no_abilities = CastleAbilities.none;
        try std.testing.expectEqual(false, no_abilities.hasAbility(.white, .king_side));
        try std.testing.expectEqual(false, no_abilities.hasAbility(.white, .queen_side));
        try std.testing.expectEqual(false, no_abilities.hasAbility(.black, .king_side));
        try std.testing.expectEqual(false, no_abilities.hasAbility(.black, .queen_side));
    }

    /// Adds the ability to castle in the specified direction for the given player.
    pub fn addAbility(self: CastleAbilities, player: Player, direction: CastleDirection) CastleAbilities {
        var result = self.abilities;
        result.set(getAbilityIndex(player, direction));
        return CastleAbilities { .abilities = result };
    }

    test addAbility {
        const no_abilities = CastleAbilities.none;
        // Add the king-side castle ability for the white player.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = false,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = false,
            }),
        })), no_abilities.addAbility(.white, .king_side));
        // Add the queen side castle ability for the white player.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = true,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = false,
            }),
        })), no_abilities.addAbility(.white, .queen_side));

        // Add the king-side castle ability for the black player.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = false,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = false,
            }),
        })), no_abilities.addAbility(.black, .king_side));
        // Add the queen side castle ability for the black player.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = false,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = true,
            }),
        })), no_abilities.addAbility(.black, .queen_side));

        // Add castle abilities to the all abilities to see that it doesn't change.
        try std.testing.expectEqual(CastleAbilities.all, CastleAbilities.all.addAbility(.white, .king_side));
        try std.testing.expectEqual(CastleAbilities.all, CastleAbilities.all.addAbility(.white, .queen_side));
        try std.testing.expectEqual(CastleAbilities.all, CastleAbilities.all.addAbility(.black, .king_side));
        try std.testing.expectEqual(CastleAbilities.all, CastleAbilities.all.addAbility(.black, .queen_side));
    }

    /// Removes the ability to castle in the specified direction for the given player.
    pub fn removeAbility(self: CastleAbilities, player: Player, direction: CastleDirection) CastleAbilities {
        var result = self.abilities;
        result.unset(getAbilityIndex(player, direction));
        return CastleAbilities { .abilities = result };
    }

    test removeAbility {
        const all_abilities = CastleAbilities.all;
        // Remove the king-side castle ability for the white player.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = true,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = true,
            }),
        })), all_abilities.removeAbility(.white, .king_side));
        // Remove the queen side castle ability for the white player.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = false,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = true,
            }),
        })), all_abilities.removeAbility(.white, .queen_side));
        // Remove the king-side castle ability for the black player.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = true,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = true,
            }),
        })), all_abilities.removeAbility(.black, .king_side));
        // Remove the queen side castle ability for the black player.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = true,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = false,
            }),
        })), all_abilities.removeAbility(.black, .queen_side));

        // Remove castle abilities from the no abilities to see that it doesn't change.
        try std.testing.expectEqual(CastleAbilities.none, CastleAbilities.none.removeAbility(.white, .king_side));
        try std.testing.expectEqual(CastleAbilities.none, CastleAbilities.none.removeAbility(.white, .queen_side));
        try std.testing.expectEqual(CastleAbilities.none, CastleAbilities.none.removeAbility(.black, .king_side));
        try std.testing.expectEqual(CastleAbilities.none, CastleAbilities.none.removeAbility(.black, .queen_side));
    }

    /// Removes all castle abilities for the given player.
    /// In debug builds will panic if the player has no castle abilities (to avoid calling entirely if no abilities exist based on comptime).
    pub fn kingMove(self: CastleAbilities, player: Player) CastleAbilities {
        std.debug.assert(self.hasAbility(player, .king_side) or self.hasAbility(player, .queen_side));
        return self.removeAbility(player, .king_side).removeAbility(player, .queen_side);
    }

    test kingMove {
        const all_abilities = CastleAbilities.all;
        // White king move removes all white castle abilities.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = false,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = true,
            }),
        })), all_abilities.kingMove(.white));
        // Black king move removes all black castle abilities.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = true,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = false,
            }),
        })), all_abilities.kingMove(.black));
        // Both king move removes all castle abilities.
        try std.testing.expectEqual(CastleAbilities.none, all_abilities.kingMove(.white).kingMove(.black));
    }

    /// Removes the castle move for the given player and direction.
    /// In debug builds will panic if the player does not have the ability to castle in the given direction.
    pub fn rookMove(self: CastleAbilities, player: Player, direction: CastleDirection) CastleAbilities {
        std.debug.assert(self.hasAbility(player, direction));
        return self.removeAbility(player, direction);
    }

    test rookMove {
        // White king-side rook move removes the white king-side castle ability.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = false,
                .queen_side = true,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = true,
            }),
        })), CastleAbilities.all.rookMove(.white, .king_side));
        // Black queen-side rook move removes the black queen-side castle ability.
        try std.testing.expectEqual(CastleAbilities.init(ByPlayer(ByCastleDirection(bool)).init(.{
            .white = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = true,
            }),
            .black = ByCastleDirection(bool).init(.{
                .king_side = true,
                .queen_side = false,
            }),
        })), CastleAbilities.all.rookMove(.black, .queen_side));
    }

    /// Get the UCI string representation of the castle abilities.
    /// i.e. "KQkq" for all abilities, "KQk" for all abilities except black queen side, etc.
    pub fn getUciString(self: CastleAbilities) []const u8 {
        if (self.hasAbility(.white, .king_side) and self.hasAbility(.white, .queen_side) and self.hasAbility(.black, .king_side) and self.hasAbility(.black, .queen_side)) {
            return "KQkq";
        }
        if (self.hasAbility(.white, .king_side) and self.hasAbility(.white, .queen_side) and self.hasAbility(.black, .king_side) and !self.hasAbility(.black, .queen_side)) {
            return "KQk";
        }
        if (self.hasAbility(.white, .king_side) and self.hasAbility(.white, .queen_side) and !self.hasAbility(.black, .king_side) and self.hasAbility(.black, .queen_side)) {
            return "KQq";
        }
        if (self.hasAbility(.white, .king_side) and self.hasAbility(.white, .queen_side) and !self.hasAbility(.black, .king_side) and !self.hasAbility(.black, .queen_side)) {
            return "KQ";
        }
        if (self.hasAbility(.white, .king_side) and !self.hasAbility(.white, .queen_side) and self.hasAbility(.black, .king_side) and self.hasAbility(.black, .queen_side)) {
            return "Kkq";
        }
        if (self.hasAbility(.white, .king_side) and !self.hasAbility(.white, .queen_side) and self.hasAbility(.black, .king_side) and !self.hasAbility(.black, .queen_side)) {
            return "Kk";
        }
        if (self.hasAbility(.white, .king_side) and !self.hasAbility(.white, .queen_side) and !self.hasAbility(.black, .king_side) and self.hasAbility(.black, .queen_side)) {
            return "Kq";
        }
        if (self.hasAbility(.white, .king_side) and !self.hasAbility(.white, .queen_side) and !self.hasAbility(.black, .king_side) and !self.hasAbility(.black, .queen_side)) {
            return "K";
        }
        if (!self.hasAbility(.white, .king_side) and self.hasAbility(.white, .queen_side) and self.hasAbility(.black, .king_side) and self.hasAbility(.black, .queen_side)) {
            return "Qkq";
        }
        if (!self.hasAbility(.white, .king_side) and self.hasAbility(.white, .queen_side) and self.hasAbility(.black, .king_side) and !self.hasAbility(.black, .queen_side)) {
            return "Qk";
        }
        if (!self.hasAbility(.white, .king_side) and self.hasAbility(.white, .queen_side) and !self.hasAbility(.black, .king_side) and self.hasAbility(.black, .queen_side)) {
            return "Qq";
        }
        if (!self.hasAbility(.white, .king_side) and self.hasAbility(.white, .queen_side) and !self.hasAbility(.black, .king_side) and !self.hasAbility(.black, .queen_side)) {
            return "Q";
        }
        if (!self.hasAbility(.white, .king_side) and !self.hasAbility(.white, .queen_side) and self.hasAbility(.black, .king_side) and self.hasAbility(.black, .queen_side)) {
            return "kq";
        }
        if (!self.hasAbility(.white, .king_side) and !self.hasAbility(.white, .queen_side) and self.hasAbility(.black, .king_side) and !self.hasAbility(.black, .queen_side)) {
            return "k";
        }
        if (!self.hasAbility(.white, .king_side) and !self.hasAbility(.white, .queen_side) and !self.hasAbility(.black, .king_side) and self.hasAbility(.black, .queen_side)) {
            return "q";
        }
        return "-";
    }

    test "getUciString" {
        try std.testing.expectEqual("KQkq", CastleAbilities.all.getUciString());
        try std.testing.expectEqual("KQk", CastleAbilities.all.removeAbility(.black, .queen_side).getUciString());
        try std.testing.expectEqual("KQq", CastleAbilities.all.removeAbility(.black, .king_side).getUciString());
        try std.testing.expectEqual("KQ", CastleAbilities.all.removeAbility(.black, .king_side).removeAbility(.black, .queen_side).getUciString());
        try std.testing.expectEqual("Kkq", CastleAbilities.all.removeAbility(.white, .queen_side).getUciString());
        try std.testing.expectEqual("Kk", CastleAbilities.all.removeAbility(.white, .queen_side).removeAbility(.black, .queen_side).getUciString());
        try std.testing.expectEqual("Kq", CastleAbilities.all.removeAbility(.white, .queen_side).removeAbility(.black, .king_side).getUciString());
        try std.testing.expectEqual("K", CastleAbilities.all.removeAbility(.white, .queen_side).removeAbility(.black, .king_side).removeAbility(.black, .queen_side).getUciString());
        try std.testing.expectEqual("Qkq", CastleAbilities.all.removeAbility(.white, .king_side).getUciString());
        try std.testing.expectEqual("Qk", CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.black, .queen_side).getUciString());
        try std.testing.expectEqual("Qq", CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.black, .king_side).getUciString());
        try std.testing.expectEqual("Q", CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.black, .king_side).removeAbility(.black, .queen_side).getUciString());
        try std.testing.expectEqual("kq", CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.white, .queen_side).getUciString());
        try std.testing.expectEqual("k", CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.white, .queen_side).removeAbility(.black, .queen_side).getUciString());
        try std.testing.expectEqual("q", CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.white, .queen_side).removeAbility(.black, .king_side).getUciString());
        try std.testing.expectEqual("-", CastleAbilities.none.getUciString());
    }
};

/// State for maintaining castling rules for a game
pub const CastleState = struct {
    /// The castle configuration.
    config: CastleConfig,
    /// The castle abilities.
    abilities: CastleAbilities,
};

/// Represents the direction of a castle move.
pub const CastleDirection = enum(u1) {
    /// The king-side castle direction.
    king_side,
    /// The queen-side castle direction.
    queen_side,
};

/// A type that maps `T` for each `CastleDirection`.
pub fn ByCastleDirection(comptime T: type) type {
    return std.EnumArray(CastleDirection, T);
}

fn getCastleChar(castle_config: CastleConfig, castle_direction: CastleDirection) u8 {
    const standard_char = ByCastleDirection(u8).init(.{
        .king_side = 'k',
        .queen_side = 'q',
    });
    return switch (castle_config) {
        .standard => standard_char.get(castle_direction),
        .fischer_random => |fischer_config| @tagName(fischer_config.starting_rook_files.get(castle_direction))[0],
    };
}

test "getCastleChar" {
    // Standard castling.
    try std.testing.expectEqual('k', getCastleChar(CastleConfig{ .standard = .{} }, CastleDirection.king_side));
    try std.testing.expectEqual('q', getCastleChar(CastleConfig{ .standard = .{} }, CastleDirection.queen_side));

    // Fischer random castling.
    try std.testing.expectEqual('g', getCastleChar(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, CastleDirection.king_side));
    try std.testing.expectEqual('b', getCastleChar(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, CastleDirection.queen_side));
}

fn getSidedCastleChar(castle_config: CastleConfig, player: Player, castle_direction: CastleDirection) u8 {
    switch (player) {
        .white => return std.ascii.toUpper(getCastleChar(castle_config, castle_direction)),
        .black => return getCastleChar(castle_config, castle_direction),
    }
}

test "getSidedCastleChar" {
    // Standard castling.
    try std.testing.expectEqual('K', getSidedCastleChar(CastleConfig{ .standard = .{} }, .white, CastleDirection.king_side));
    try std.testing.expectEqual('Q', getSidedCastleChar(CastleConfig{ .standard = .{} }, .white, CastleDirection.queen_side));
    try std.testing.expectEqual('k', getSidedCastleChar(CastleConfig{ .standard = .{} }, .black, CastleDirection.king_side));
    try std.testing.expectEqual('q', getSidedCastleChar(CastleConfig{ .standard = .{} }, .black, CastleDirection.queen_side));

    // Fischer random castling.
    try std.testing.expectEqual('G', getSidedCastleChar(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, .white, CastleDirection.king_side));
    try std.testing.expectEqual('B', getSidedCastleChar(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, .white, CastleDirection.queen_side));
    try std.testing.expectEqual('g', getSidedCastleChar(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, .black, CastleDirection.king_side));
    try std.testing.expectEqual('b', getSidedCastleChar(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, .black, CastleDirection.queen_side));
}

fn tryGetSidedCastleChar(castle_config: CastleConfig, castle_abilities: CastleAbilities, player: Player, castle_direction: CastleDirection) ?u8 {
    if (castle_abilities.hasAbility(player, castle_direction)) {
        return getSidedCastleChar(castle_config, player, castle_direction);
    }
    return null;
}

inline fn getCharOrEmpty(castle_config: CastleConfig, castle_abilities: CastleAbilities, player: Player, castle_direction: CastleDirection) []const u8 {
    if (tryGetSidedCastleChar(castle_config, castle_abilities, player, castle_direction)) |char| {
        return &[1]u8{char};
    } else {
        return "";
    }
}

pub fn getUciString(comptime castle_config: CastleConfig, comptime castle_abilities: CastleAbilities) []const u8 {
    const uci_string = comptime getCharOrEmpty(castle_config, castle_abilities, .white, .king_side) ++ getCharOrEmpty(castle_config, castle_abilities, .white, .queen_side) ++ getCharOrEmpty(castle_config, castle_abilities, .black, .king_side) ++ getCharOrEmpty(castle_config, castle_abilities, .black, .queen_side);

    if (uci_string.len == 0) {
        return "-";
    }

    return uci_string;
}

test "getUciString" {
    @setEvalBranchQuota(1000000);

    // Standard
    try std.testing.expectEqualStrings("KQkq", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all));
    try std.testing.expectEqualStrings("KQk", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("KQq", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.black, .king_side)));
    try std.testing.expectEqualStrings("KQ", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.black, .king_side).removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("Kkq", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .queen_side)));
    try std.testing.expectEqualStrings("Kk", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .queen_side).removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("Kq", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .queen_side).removeAbility(.black, .king_side)));
    try std.testing.expectEqualStrings("K", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .queen_side).removeAbility(.black, .king_side).removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("Qkq", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .king_side)));
    try std.testing.expectEqualStrings("Qk", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("Qq", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.black, .king_side)));
    try std.testing.expectEqualStrings("Q", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.black, .king_side).removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("kq", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.white, .queen_side)));
    try std.testing.expectEqualStrings("k", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.white, .queen_side).removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("q", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.all.removeAbility(.white, .king_side).removeAbility(.white, .queen_side).removeAbility(.black, .king_side)));
    try std.testing.expectEqualStrings("-", getUciString(CastleConfig{ .standard = .{} }, CastleAbilities.none));

    // Fischer random
    try std.testing.expectEqualStrings("GBgb", getUciString(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, CastleAbilities.all));
    try std.testing.expectEqualStrings("GBg", getUciString(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, CastleAbilities.all.removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("GBb", getUciString(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, CastleAbilities.all.removeAbility(.black, .king_side)));
    try std.testing.expectEqualStrings("GB", getUciString(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, CastleAbilities.all.removeAbility(.black, .king_side).removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("G", getUciString(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, CastleAbilities.all.removeAbility(.white, .queen_side).removeAbility(.black, .king_side).removeAbility(.black, .queen_side)));
    try std.testing.expectEqualStrings("-", getUciString(CastleConfig{ .fischer_random = .{ .starting_king_file = .e, .starting_rook_files = ByCastleDirection(File).init(.{ .king_side = .g, .queen_side = .b }) } }, CastleAbilities.none));
}
