const std = @import("std");

const CastleState = @import("./castle.zig").CastleState;
const CastleAbilities = @import("./castle.zig").CastleAbilities;
const CastleDirection = @import("./castle.zig").CastleDirection;
const StartingCastleFiles = @import("./castle.zig").StartingCastleFiles;
const ByCastleDirection = @import("./castle.zig").ByCastleDirection;
const BoardDirection = @import("./direction.zig").BoardDirection;
const CastleConfig = @import("./castle.zig").CastleConfig;
const OwnedPiece = @import("./piece.zig").OwnedPiece;
const OwnedNonKingPiece = @import("./piece.zig").OwnedNonKingPiece;
const PieceArrangement = @import("./piece_arrangement.zig").PieceArrangement;
const Player = @import("./player.zig").Player;
const ByPlayer = @import("./player.zig").ByPlayer;
const Ply = @import("./ply.zig").Ply;
const EnPassantSquare = @import("./square.zig").EnPassantSquare;
const Square = @import("./square.zig").Square;
const File = @import("./square.zig").File;
const Rank = @import("./square.zig").Rank;

/// A struct representing a parsed FEN string.
/// Known to be pseudo-legal and could be invalid.
pub const ParsedPsuedoLegalFen = struct {
    /// The pieces on the board.
    pieces: PieceArrangement,
    /// The player who is currently to move.
    side_to_move: Player,
    /// The castling abilities and configuration of the current position.
    castles: CastleState,
    /// The square that a pawn can move to in order to capture an opponent's pawn.
    en_passant_square: ?EnPassantSquare,
    /// The number of half moves made since the last pawn move or capture. (the halfmove clock from the fen)
    halfmove_clock: ?Ply,
    /// The number of half moves made in the game. (the full move number from the fen)
    game_ply: ?Ply,
};

const FenParseError = error{
    MissingPieces,
    MissingSideToMove,
    MissingCastleRights,
    MissingEnPassantSquare,
    UnrecognizedPieceCharacter,
    InvalidPieceOffset,
    InvalidBoardDimensions,
    InvalidSideToMove,
    InvalidEnPassantSquare,
    InvalidCastles,
    InvalidHalfmoveClock,
    InvalidFullmoveCount,
    MissingWhiteKing,
    MissingBlackKing,
};

pub fn parseFen(fen: []const u8) FenParseError!ParsedPsuedoLegalFen {
    var parts = std.mem.tokenizeScalar(u8, std.mem.trim(u8, fen, " \n\r\t"), ' ');
    const pieces = try parsePieces(parts.next());
    const side_to_move = try parseSideToMove(parts.next());
    const castles = try parseCastles(parts.next(), pieces);
    const en_passant_square = try parseEnPassantSquare(parts.next());
    const halfmove_clock = try parseHalfmoveClock(parts.next());
    const fullmove_count = try parseGamePly(parts.next());
    var game_ply: ?Ply = null;
    if (fullmove_count) |fullmoves| {
        game_ply = 2 * (fullmoves - 1) + @intFromEnum(side_to_move);
    }

    return ParsedPsuedoLegalFen{
        .pieces = pieces,
        .side_to_move = side_to_move,
        .castles = castles,
        .en_passant_square = en_passant_square,
        .halfmove_clock = halfmove_clock,
        .game_ply = game_ply,
    };
}

fn parsePieces(part: ?[]const u8) FenParseError!PieceArrangement {
    if (part) |p| {
        var square_offset: i8 = @intCast(Square.a8.offset());
        var king_squares = ByPlayer(?Square).init(.{ .white = null, .black = null });
        var non_king_piece_list = std.BoundedArray(struct { OwnedNonKingPiece, Square }, std.enums.values(Square).len).init(0) catch unreachable;
        for (p) |c| {
            switch (c) {
                '1'...'8' => square_offset += @intCast(std.fmt.charToDigit(c, 10) catch unreachable),
                '0' | '9' => return FenParseError.InvalidPieceOffset,
                '/' => square_offset -= 16,
                'K' => {
                    king_squares.set(.white, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions));
                    square_offset += 1;
                },
                'k' => {
                    king_squares.set(.black, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions));
                    square_offset += 1;
                },
                'Q' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .queen, .player = .white }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'q' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .queen, .player = .black }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'R' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .rook, .player = .white }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'r' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .rook, .player = .black }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'B' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .bishop, .player = .white }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'b' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .bishop, .player = .black }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'N' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .knight, .player = .white }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'n' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .knight, .player = .black }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'P' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .pawn, .player = .white }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                'p' => {
                    non_king_piece_list.appendAssumeCapacity(.{ .{ .piece = .pawn, .player = .black }, Square.fromOffset(std.math.cast(Square.OffsetInt, square_offset) orelse return FenParseError.InvalidBoardDimensions) });
                    square_offset += 1;
                },
                else => return FenParseError.UnrecognizedPieceCharacter,
            }
        }

        if (king_squares.get(.white)) |white_king| {
            if (king_squares.get(.black)) |black_king| {
                var pieces = PieceArrangement.init(.init(.{
                    .white = white_king,
                    .black = black_king,
                }));

                for (non_king_piece_list.constSlice()) |piece_square| {
                    const piece, const to_square = piece_square;
                    pieces = pieces.tryAddPiece(piece, to_square) catch return FenParseError.InvalidBoardDimensions;
                }

                return pieces;
            }
            return FenParseError.MissingBlackKing;
        }

        return FenParseError.MissingWhiteKing;
    }

    return FenParseError.MissingPieces;
}

fn parseSideToMove(part: ?[]const u8) FenParseError!Player {
    if (part) |p| {
        if (std.mem.eql(u8, p, "w")) {
            return Player.white;
        } else if (std.mem.eql(u8, p, "b")) {
            return Player.black;
        } else {
            return FenParseError.InvalidSideToMove;
        }
    }

    return FenParseError.MissingSideToMove;
}

fn parseCastles(part: ?[]const u8, pieces: PieceArrangement) FenParseError!CastleState {
    if (part) |p| {
        if (std.mem.eql(u8, p, "-")) return .{
            .config = .standard,
            .abilities = .none,
        };
        if (p.len > 4) return FenParseError.InvalidCastles;

        var abilities = CastleAbilities.none;
        inline for (0..4) |i| {
            switch (p[i]) {
                'K' => abilities = abilities.addAbility(.white, .king_side),
                'Q' => abilities = abilities.addAbility(.white, .queen_side),
                'k' => abilities = abilities.addAbility(.black, .king_side),
                'q' => abilities = abilities.addAbility(.black, .queen_side),
                else => return FenParseError.InvalidCastles,
            }
        }

        // If no castling rights are present, return the standard config since Fischer Random won't impact anything without rights
        if (abilities == CastleAbilities.none) {
            return .{
                .config = .standard,
                .abilities = abilities,
            };
        }

        var maybe_king_file: ?File = null;
        inline for (comptime std.enums.values(Player)) |player| {
            if (abilities.hasAbility(player, .king_side) or abilities.hasAbility(player, .queen_side)) {
                const rank: Rank = switch (player) {
                    .white => ._1,
                    .black => ._8,
                };
                inline for (comptime std.enums.values(File)) |file| {
                    const square = Square.fromFileAndRank(file, rank);
                    if (pieces.pieceOn(square) == .king and abilities.hasAbility(player, .king_side)) {
                        maybe_king_file = file;
                    }
                }
            }
        }
        if (maybe_king_file) |king_file| {
            var maybe_rook_files = ByCastleDirection(?File).init(.{ .queen_side = null, .king_side = null });
            inline for (comptime std.enums.values(Player)) |player| {
                const rank: Rank = switch (player) {
                    .white => ._1,
                    .black => ._8,
                };
                inline for (comptime std.enums.values(File)) |file| {
                    if (file != king_file) {
                        const square = Square.fromFileAndRank(file, rank);
                        if (pieces.pieceOn(square) == .rook) {
                            if (maybe_rook_files.get(.queen_side) == null) {
                                if (abilities.hasAbility(player, .queen_side)) {
                                    maybe_rook_files.set(.queen_side, file);
                                } else if (maybe_rook_files.get(.king_side) == null and abilities.hasAbility(player, .king_side)) {
                                    maybe_rook_files.set(.king_side, file);
                                }
                            } else if (maybe_rook_files.get(.king_side) == null and abilities.hasAbility(player, .king_side)) {
                                maybe_rook_files.set(.king_side, file);
                            }
                        }
                    }
                }

                if (maybe_rook_files.get(.queen_side)) |queen_side_rook_file| {
                    if (maybe_rook_files.get(.king_side)) |king_side_rook_file| {
                        const standard = StartingCastleFiles(.standard, .all).init();
                        if (standard.kingFile() == king_file) {
                            const standard_rook_files = standard.rookFiles();
                            if (standard_rook_files.get(.queen_side) == queen_side_rook_file and standard_rook_files.get(.king_side) == king_side_rook_file) {
                                return .{
                                    .config = .standard,
                                    .abilities = abilities,
                                };
                            }
                        }

                        return .{
                            .config = .{
                                .fischer_random = .{
                                    .starting_rook_files = .init(.{
                                        .queen_side = queen_side_rook_file,
                                        .king_side = king_side_rook_file,
                                    }),
                                    .starting_king_file = king_file,
                                },
                            },
                            .abilities = abilities,
                        };
                    }

                    // Missing king side rook on back rank for a player with castle abilities
                    return FenParseError.InvalidCastles;
                }

                // Missing rook on back rank for a player with castle abilities
                return FenParseError.InvalidCastles;
            }
        }

        // Missing king on back rank for both players
        return FenParseError.InvalidCastles;
    }

    return FenParseError.MissingCastleRights;
}

fn parseEnPassantSquare(part: ?[]const u8) FenParseError!?EnPassantSquare {
    if (part) |p| {
        if (std.mem.eql(u8, p, "-")) return null;

        inline for (comptime std.enums.values(EnPassantSquare)) |potential_ep_square| {
            const tag = @tagName(potential_ep_square);
            const lower_tag = "" ++ .{std.ascii.toLower(tag[0])} ++ tag[1..];
            if (std.mem.eql(u8, p, tag) or std.mem.eql(u8, p, lower_tag)) {
                return potential_ep_square;
            }
        }

        return FenParseError.InvalidEnPassantSquare;
    }

    return FenParseError.MissingEnPassantSquare;
}

fn parseHalfmoveClock(part: ?[]const u8) FenParseError!?Ply {
    if (part) |p| {
        return std.fmt.parseInt(Ply, p, 10) catch return FenParseError.InvalidHalfmoveClock;
    }

    return null;
}

fn parseGamePly(part: ?[]const u8) FenParseError!?Ply {
    if (part) |p| {
        return std.fmt.parseInt(Ply, p, 10) catch return FenParseError.InvalidFullmoveCount;
    }

    return null;
}

test "parseFen startpos" {
    const fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    const parsed = try parseFen(fen);

    try std.testing.expectEqual(OwnedPiece{ .piece = .rook, .player = .white }, parsed.pieces.sidedPieceOn(.a1).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .knight, .player = .white }, parsed.pieces.sidedPieceOn(.b1).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .bishop, .player = .white }, parsed.pieces.sidedPieceOn(.c1).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .queen, .player = .white }, parsed.pieces.sidedPieceOn(.d1).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .king, .player = .white }, parsed.pieces.sidedPieceOn(.e1).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .bishop, .player = .white }, parsed.pieces.sidedPieceOn(.f1).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .knight, .player = .white }, parsed.pieces.sidedPieceOn(.g1).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .rook, .player = .white }, parsed.pieces.sidedPieceOn(.h1).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .white }, parsed.pieces.sidedPieceOn(.a2).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .white }, parsed.pieces.sidedPieceOn(.b2).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .white }, parsed.pieces.sidedPieceOn(.c2).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .white }, parsed.pieces.sidedPieceOn(.d2).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .white }, parsed.pieces.sidedPieceOn(.e2).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .white }, parsed.pieces.sidedPieceOn(.f2).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .white }, parsed.pieces.sidedPieceOn(.g2).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .white }, parsed.pieces.sidedPieceOn(.h2).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .rook, .player = .black }, parsed.pieces.sidedPieceOn(.a8).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .knight, .player = .black }, parsed.pieces.sidedPieceOn(.b8).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .bishop, .player = .black }, parsed.pieces.sidedPieceOn(.c8).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .queen, .player = .black }, parsed.pieces.sidedPieceOn(.d8).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .king, .player = .black }, parsed.pieces.sidedPieceOn(.e8).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .bishop, .player = .black }, parsed.pieces.sidedPieceOn(.f8).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .knight, .player = .black }, parsed.pieces.sidedPieceOn(.g8).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .rook, .player = .black }, parsed.pieces.sidedPieceOn(.h8).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .black }, parsed.pieces.sidedPieceOn(.a7).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .black }, parsed.pieces.sidedPieceOn(.b7).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .black }, parsed.pieces.sidedPieceOn(.c7).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .black }, parsed.pieces.sidedPieceOn(.d7).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .black }, parsed.pieces.sidedPieceOn(.e7).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .black }, parsed.pieces.sidedPieceOn(.f7).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .black }, parsed.pieces.sidedPieceOn(.g7).?);
    try std.testing.expectEqual(OwnedPiece{ .piece = .pawn, .player = .black }, parsed.pieces.sidedPieceOn(.h7).?);
    try std.testing.expectEqual(null, parsed.pieces.sidedPieceOn(.a3));
    try std.testing.expectEqual(null, parsed.pieces.sidedPieceOn(.a4));
    try std.testing.expectEqual(null, parsed.pieces.sidedPieceOn(.a5));

    try std.testing.expectEqual(Player.white, parsed.side_to_move);
    try std.testing.expectEqual(CastleAbilities.all, parsed.castles.abilities);
    try std.testing.expectEqualDeep(CastleConfig{ .standard = .{} }, parsed.castles.config);

    try std.testing.expectEqual(null, parsed.en_passant_square);

    try std.testing.expectEqual(0, parsed.halfmove_clock.?);
    try std.testing.expectEqual(0, parsed.game_ply.?);
}

test "parseFen missing kings errors" {
    const bothFen = "8/8/8/8/8/8/8/8 w - - 0 1";
    try std.testing.expectError(FenParseError.MissingWhiteKing, parseFen(bothFen));
    const whiteFen = "8/8/8/8/8/8/8/4K3 w - - 0 1";
    try std.testing.expectError(FenParseError.MissingBlackKing, parseFen(whiteFen));
}

test "parseFen missing pieces errors" {
    const emptyFen = "";
    try std.testing.expectError(FenParseError.MissingPieces, parseFen(emptyFen));
    const spacesFen = " w - - 0 1";
    try std.testing.expectError(FenParseError.UnrecognizedPieceCharacter, parseFen(spacesFen));
}

test "parseFen missing side to move errors" {
    const missingSideFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR";
    try std.testing.expectError(FenParseError.MissingSideToMove, parseFen(missingSideFen));
}

test "parseFen missing castle rights errors" {
    const missingCastleFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w";
    try std.testing.expectError(FenParseError.MissingCastleRights, parseFen(missingCastleFen));
}

test "parseFen missing en passant square errors" {
    const missingEnPassantFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq";
    try std.testing.expectError(FenParseError.MissingEnPassantSquare, parseFen(missingEnPassantFen));
}

test "parseFen missing halfmove clock returns null for it" {
    const missingHalfmoveClockFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
    try std.testing.expectEqual(null, (try parseFen(missingHalfmoveClockFen)).halfmove_clock);
}
test "parseFen missing fullmove count returns null for it" {
    const missingFullmoveCountFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0";
    try std.testing.expectEqual(null, (try parseFen(missingFullmoveCountFen)).game_ply);
}

test "parseFen fullmove count matches for white" {
    const whiteFullmoveCountFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 21";
    try std.testing.expectEqual(40, (try parseFen(whiteFullmoveCountFen)).game_ply.?);
}

test "parseFen fullmove count matches for black" {
    const blackFullmoveCountFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 21";
    try std.testing.expectEqual(41, (try parseFen(blackFullmoveCountFen)).game_ply.?);
}

test "parseFen halfmove clock matches" {
    const halfmoveClockFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 5 21";
    try std.testing.expectEqual(5, (try parseFen(halfmoveClockFen)).halfmove_clock.?);
}
// TODO: test a ton more fens
// TODO: test chess960 fens
