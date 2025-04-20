const std = @import("std");
const zobrist_seed = @import("build_options").zobrist_seed;

const BoardStatus = @import("./board_status.zig").BoardStatus;
const CastleAbilities = @import("./castle.zig").CastleAbilities;
const CastleDirection = @import("./castle.zig").CastleDirection;
const ByCastleDirection = @import("./castle.zig").ByCastleDirection;
const BoardDirection = @import("./direction.zig").BoardDirection;
const OwnedPiece = @import("./piece.zig").OwnedPiece;
const PromotionPiece = @import("./piece.zig").PromotionPiece;
const OwnedNonKingPiece = @import("./piece.zig").OwnedNonKingPiece;
const Piece = @import("./piece.zig").Piece;
const ByPiece = @import("./piece.zig").ByPiece;
const PieceArrangement = @import("./piece_arrangement.zig").PieceArrangement;
const Player = @import("./player.zig").Player;
const ByPlayer = @import("./player.zig").ByPlayer;
const Square = @import("./square.zig").Square;
const File = @import("./square.zig").File;
const BySquare = @import("./square.zig").BySquare;
const EnPassantSquare = @import("./square.zig").EnPassantSquare;
const ByFile = @import("./square.zig").ByFile;

/// The underlying type of a Zobrist hash, a 64-bit unsigned integer
const ZobristKey = u64;

/// The type of the seed used to generate Zobrist keys at compile time.
const ComptimeRandomSeed = u256;

/// Generate a random array of Zobrist key using Xoshiro256 algorithm.
fn comptimeRandom(comptime seed: ComptimeRandomSeed, comptime count: usize) [count]ZobristKey {
    const mask = (1 << 64) - 1;
    var state: [4]u64 = .{
        @intCast(seed & mask),
        @intCast((seed >> 64) & mask),
        @intCast((seed >> 128) & mask),
        @intCast((seed >> 192) & mask),
    };

    var result: [count]ZobristKey = undefined;
    inline for (0..count) |i| {
        result[i] = std.math.rotl(u64, state[0] +% state[3], 23) +% state[0];

        const t = state[1] << 17;

        state[2] ^= state[0];
        state[3] ^= state[1];
        state[1] ^= state[2];
        state[0] ^= state[3];

        state[2] ^= t;

        state[3] = std.math.rotl(u64, state[3], 45);
    }
    return result;
}

/// A type containing all Zobrist keys needed to represent any possible chess position.
const ZobristKeys = struct {
    /// The base/empty board key
    empty: ZobristKey,
    /// Hash value used for black to move
    side: ZobristKey,
    /// Hash value of one of the 8 possible files for an en-passant squares A3-H3, A6-H6
    en_passant: ByFile(ZobristKey),
    /// Hash for one of 4 castle abilities, white/black king-side/queen-side
    castle: ByPlayer(ByCastleDirection(ZobristKey)),
    /// Hash value for all piece square possibilities (including some illegal positions like pawns on last rank)
    piece_square: ByPlayer(ByPiece(BySquare(ZobristKey))),

    /// Create a new Zobrist keys struct from a seed.
    fn init(seed: ComptimeRandomSeed) ZobristKeys {
        @setEvalBranchQuota(120_000);
        const EMPTY_INDEX: usize = 0;
        const SIDE_INDEX: usize = 1;
        const EN_PASSANT_INDEX: usize = 2;
        const CASTLE_INDEX: usize = EN_PASSANT_INDEX + std.enums.values(File).len;
        const PIECE_SQUARE_INDEX: usize = CASTLE_INDEX + (std.enums.values(CastleDirection).len * std.enums.values(Player).len);
        const TOTAL_COUNT: usize = PIECE_SQUARE_INDEX + (std.enums.values(Piece).len * std.enums.values(Square).len * std.enums.values(Player).len);

        // Generate a random data for the Zobrist keys
        const source: [TOTAL_COUNT]ZobristKey = comptimeRandom(seed, TOTAL_COUNT);

        // Convert the random data into the Zobrist keys
        var en_passant = ByFile(ZobristKey).initUndefined();

        inline for (std.enums.values(File), 0..) |file, i| {
            en_passant.set(file, source[EN_PASSANT_INDEX + i]);
        }

        var castle = ByPlayer(ByCastleDirection(ZobristKey)).initUndefined();
        var piece_square = ByPlayer(ByPiece(BySquare(ZobristKey))).initUndefined();

        inline for (std.enums.values(Player), 0..) |player, player_index| {
            var castles = ByCastleDirection(ZobristKey).initUndefined();
            inline for (std.enums.values(CastleDirection), 0..) |castle_direction, castle_index| {
                castles.set(castle_direction, source[CASTLE_INDEX + player_index * std.enums.values(CastleDirection).len + castle_index]);
            }
            castle.set(player, castles);
            var pieces = ByPiece(BySquare(ZobristKey)).initUndefined();
            inline for (std.enums.values(Piece), 0..) |piece, piece_index| {
                var squares = BySquare(ZobristKey).initUndefined();
                inline for (std.enums.values(Square), 0..) |square, square_index| {
                    squares.set(square, source[PIECE_SQUARE_INDEX + player_index * std.enums.values(Piece).len * std.enums.values(Square).len + piece_index * std.enums.values(Square).len + square_index]);
                }
                pieces.set(piece, squares);
            }
            piece_square.set(player, pieces);
        }

        return ZobristKeys{
            .empty = source[EMPTY_INDEX],
            .side = source[SIDE_INDEX],
            .en_passant = en_passant,
            .castle = castle,
            .piece_square = piece_square,
        };
    }
};

/// A Zobrist hash for a chess position.
pub const ZobristHash = struct {
    const FEATURES = ZobristKeys.init(zobrist_seed);

    /// The underlying Zobrist key.
    key: ZobristKey,

    pub fn initPieces(comptime board_status: BoardStatus, pieces: PieceArrangement) ZobristHash {
        @setEvalBranchQuota(1_000_000);
        var hash = fromKey(FEATURES.empty)
            .togglePiece(.{ .player = .white, .piece = .king }, pieces.kings.get(.white))
            .togglePiece(.{ .player = .black, .piece = .king }, pieces.kings.get(.black))
            .toggleCastleAbilities(board_status.castle_abilities);

        if (board_status.en_passant_file.inner()) |file| {
            hash = hash.toggleEnPassant(file);
        }

        if (board_status.side_to_move == .black) {
            hash = hash.switchSides();
        }

        inline for (comptime std.enums.values(Square)) |square| {
            if (pieces.sidedPieceOn(square)) |piece| {
                hash = hash.togglePiece(piece, square);
            }
        }

        return hash;
    }

    /// Switch the side to move in the Zobrist hash.
    pub fn switchSides(self: ZobristHash) ZobristHash {
        return self.logicalXor(fromKey(FEATURES.side));
    }

    /// Toggle the side to move in the Zobrist hash.
    pub fn capture(self: ZobristHash, piece: OwnedPiece, captured_piece: OwnedNonKingPiece, from: Square, to: Square) ZobristHash {
        return self
            .move(piece, from, to)
            .togglePiece(captured_piece.to_owned(), to);
    }

    /// Quiet move a piece in the Zobrist hash.
    pub fn move(self: ZobristHash, piece: OwnedPiece, from: Square, to: Square) ZobristHash {
        return self
            .togglePiece(piece, from)
            .togglePiece(piece, to);
    }

    /// Double push a pawn from the start rank in the Zobrist hash.
    pub fn doublePawnPush(self: ZobristHash, player: Player, en_passant_file: File) ZobristHash {
        const en_passant_square = en_passant_file.epSquareFor(player).to_square();
        const forward = BoardDirection.forward(player);
        const from = en_passant_square.shift(forward.opposite()) orelse unreachable;
        const to = en_passant_square.shift(forward) orelse unreachable;
        return self
            .move(.{ .player = player, .piece = .pawn }, from, to)
            .toggleEnPassant(en_passant_file);
    }

    /// Clear the en-passant square in the Zobrist hash.
    pub fn clearEnPassant(self: ZobristHash, en_passant_file: File) ZobristHash {
        return self.toggleEnPassant(en_passant_file);
    }

    /// Capture a pawn that just moved two squares by attacking the jumped square (en passant).
    pub fn enPassantCapture(self: ZobristHash, player: Player, from: Square, to: Square) ZobristHash {
        const en_passant_square = to.shift(BoardDirection.forward(player).opposite()).?;
        return self
            .move(.{ .player = player, .piece = .pawn }, from, to)
            .togglePiece(.{ .player = player.opposite(), .piece = .pawn }, en_passant_square)
            .toggleEnPassant(en_passant_square.fileOf());
    }

    /// Promote a pawn in the Zobrist hash.
    pub fn promote(self: ZobristHash, player: Player, promotion: PromotionPiece, from: Square, to: Square) ZobristHash {
        return self
            .togglePiece(.{ .player = player, .piece = .pawn }, from)
            .togglePiece(.{ .player = player, .piece = promotion.toPiece() }, to);
    }

    /// Promote a pawn and capture a piece in the Zobrist hash.
    pub fn promoteCapture(self: ZobristHash, player: Player, captured_piece: OwnedNonKingPiece, promotion: PromotionPiece, from: Square, to: Square) ZobristHash {
        return self
            .togglePiece(captured_piece.to_owned(), to)
            .togglePiece(.{ .player = player, .piece = .pawn }, from)
            .togglePiece(.{ .player = player, .piece = promotion.toPiece() }, to);
    }

    /// Toggle an individual player's castle ability for a specific castle direction in the Zobrist hash.
    pub fn toggleCastleAbility(self: ZobristHash, player: Player, castle_direction: CastleDirection) ZobristHash {
        return self.logicalXor(fromKey(FEATURES.castle.get(player).get(castle_direction)));
    }

    /// Toggle all `true` castle abilities in the Zobrist hash.
    fn toggleCastleAbilities(self: ZobristHash, castle_abilities: CastleAbilities) ZobristHash {
        var result = self;
        inline for (comptime std.enums.values(Player)) |player| {
            inline for (comptime std.enums.values(CastleDirection)) |castle_direction| {
                if (castle_abilities.hasAbility(player, castle_direction)) {
                    result = result.logicalXor(fromKey(FEATURES.castle.get(player).get(castle_direction)));
                }
            }
        }
        return result;
    }

    /// Toggle the en-passant file in the Zobrist hash.
    fn toggleEnPassant(self: ZobristHash, en_passant_file: File) ZobristHash {
        return self.logicalXor(fromKey(FEATURES.en_passant.get(en_passant_file)));
    }

    /// Toggle a player's piece on the board at a given square.
    fn togglePiece(self: ZobristHash, piece: OwnedPiece, square: Square) ZobristHash {
        return self.logicalXor(fromKey(FEATURES.piece_square.get(piece.player).get(piece.piece).get(square)));
    }

    /// Create a new Zobrist hash from a Zobrist key.
    fn fromKey(key: ZobristKey) ZobristHash {
        return ZobristHash{ .key = key };
    }

    /// Add or undo a feature from the Zobrist hash using the XOR operator.
    fn logicalXor(self: ZobristHash, feature: ZobristHash) ZobristHash {
        return fromKey(self.key ^ feature.key);
    }

    // Ensure that the Zobrist key is unique for each feature
    test FEATURES {
        var seen = std.AutoHashMap(ZobristKey, bool).init(std.testing.allocator);
        defer seen.deinit();

        for (std.enums.values(Player)) |player| {
            for (std.enums.values(Piece)) |piece| {
                for (std.enums.values(Square)) |square| {
                    const key = FEATURES.piece_square.get(player).get(piece).get(square);
                    try std.testing.expect(!(try seen.getOrPut(key)).found_existing);
                }
            }
        }

        for (std.enums.values(Player)) |player| {
            for (std.enums.values(CastleDirection)) |castle_direction| {
                const key = FEATURES.castle.get(player).get(castle_direction);
                try std.testing.expect(!(try seen.getOrPut(key)).found_existing);
            }
        }

        for (std.enums.values(File)) |files| {
            const key = FEATURES.en_passant.get(files);
            try std.testing.expect(!(try seen.getOrPut(key)).found_existing);
        }

        const side_key = FEATURES.side;
        try std.testing.expect(!(try seen.getOrPut(side_key)).found_existing);

        const empty_key = FEATURES.empty;
        try std.testing.expect(!(try seen.getOrPut(empty_key)).found_existing);

        try std.testing.expectEqual(782, seen.count());
    }

    // Test that toggling each piece for any player and square is symmetric for any starting player
    test togglePiece {
        const players = comptime std.enums.values(Player);
        const pieces = comptime std.enums.values(Piece);
        inline for (players) |starting_player| {
            inline for (players) |player| {
                inline for (pieces) |piece| {
                    const owned_piece = OwnedPiece{ .piece = piece, .player = player };
                    const hash = comptime ZobristHash.initPieces(.init(starting_player, .all, .none), .init(.init(.{ .white = .e1, .black = .e8 })));
                    for (std.enums.values(Square)) |square| {
                        const toggled_once = hash.togglePiece(owned_piece, square);
                        try std.testing.expect(hash.key != toggled_once.key);
                        const toggled_twice = toggled_once.togglePiece(owned_piece, square);
                        try std.testing.expect(toggled_once.key != toggled_twice.key);
                        try std.testing.expect(hash.key == toggled_twice.key);
                    }
                }
            }
        }
    }

    // Test that switching sides is symmetric for any starting player
    test switchSides {
        const players = comptime std.enums.values(Player);
        inline for (players) |starting_player| {
            const hash = comptime ZobristHash.initPieces(.init(starting_player, .all, .none), .init(.init(.{ .white = .e1, .black = .e8 })));
            const toggled = hash.switchSides();
            try std.testing.expect(hash.key != toggled.key);
            const toggled_back = toggled.switchSides();
            try std.testing.expect(toggled.key != toggled_back.key);
            try std.testing.expect(hash.key == toggled_back.key);
        }
    }

    // Test toggling all individual castle ability is symmetric for any starting player
    test toggleCastleAbility {
        const players = comptime std.enums.values(Player);
        const castle_directions = comptime std.enums.values(CastleDirection);
        inline for (players) |starting_player| {
            const hash = comptime ZobristHash.initPieces(.init(starting_player, .all, .none), .init(.init(.{ .white = .e1, .black = .e8 })));
            inline for (players) |player| {
                inline for (castle_directions) |castle_direction| {
                    const toggled = hash.toggleCastleAbility(player, castle_direction);
                    try std.testing.expect(hash.key != toggled.key);
                    const toggled_back = toggled.toggleCastleAbility(player, castle_direction);
                    try std.testing.expect(toggled.key != toggled_back.key);
                    try std.testing.expect(hash.key == toggled_back.key);
                }
            }
        }
    }

    // Test that toggling multiple castle abilities is symmetric for any starting player
    test toggleCastleAbilities {
        const players = comptime std.enums.values(Player);
        inline for (players) |starting_player| {
            const hash = comptime ZobristHash.initPieces(.init(starting_player, .all, .none), .init(.init(.{ .white = .e1, .black = .e8 })));
            const toggled = hash.toggleCastleAbilities(CastleAbilities.all);
            try std.testing.expect(hash.key != toggled.key);
            const toggled_back = toggled.toggleCastleAbilities(CastleAbilities.all);
            try std.testing.expect(toggled.key != toggled_back.key);
            try std.testing.expect(hash.key == toggled_back.key);
            // Test that toggling CastleAbilitites.none doesn't toggle anything
            try std.testing.expectEqual(hash.key, hash.toggleCastleAbilities(CastleAbilities.none).key);
        }
    }

    // Test that toggling the en-passant square is symmetric for any starting player
    test toggleEnPassant {
        const players = comptime std.enums.values(Player);
        const files = comptime std.enums.values(File);
        inline for (players) |starting_player| {
            const hash = comptime ZobristHash.initPieces(.init(starting_player, .all, .none), .init(.init(.{ .white = .e1, .black = .e8 })));
            inline for (files) |file| {
                const toggled = hash.toggleEnPassant(file);
                try std.testing.expect(hash.key != toggled.key);
                const toggled_back = toggled.toggleEnPassant(file);
                try std.testing.expect(toggled.key != toggled_back.key);
                try std.testing.expect(hash.key == toggled_back.key);
            }
        }
    }
};
