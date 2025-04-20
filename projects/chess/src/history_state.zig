const std = @import("std");

const Bitboard = @import("./bitboard.zig").Bitboard;
const BoardStatus = @import("./board_status.zig").BoardStatus;
const StartingCastleFiles = @import("./castle.zig").StartingCastleFiles;
const GameRules = @import("./game_rules.zig").GameRules;
const HalfmoveClock = @import("./halfmove_clock.zig").HalfmoveClock;
const between = @import("./line.zig").between;
const ByNonKingPiece = @import("./piece.zig").ByNonKingPiece;
const PieceArrangement = @import("./piece_arrangement.zig").PieceArrangement;
const ByPlayer = @import("./player.zig").ByPlayer;
const Player = @import("./player.zig").Player;
const Ply = @import("./ply.zig").Ply;
const ZobristHash = @import("./zobrist.zig").ZobristHash;

/// Create a history state for a game of chess for a given set of game rules.
pub fn HistoryState(comptime rules: GameRules) type {
    return struct {
        const Self = @This();
        const MoveLimitClock = HalfmoveClock(rules.fifty_move_limit);

        /// The state from before this move
        previous: ?*Self = null,
        /// The state from the next move
        next: ?*Self = null,
        /// How many times this position has been seen
        repetition_count: Ply = 0,
        /// How many half moves have been made this game
        game_ply: Ply = 0,

        // Irreversible state of the game
        /// The Zobrist hash of the position
        zobrist_hash: ZobristHash,
        /// The move limit clock
        halfmove_clock: MoveLimitClock = MoveLimitClock.init(),

        // State of the game that is used to generate legal moves
        /// Squares currently giving check
        checkers: Bitboard,
        /// Pieces that are blocking a check
        blockers: ByPlayer(Bitboard),
        /// Pieces that are attacking the king through another piece
        pinners: ByPlayer(Bitboard),
        /// Squares that when occupied by a certain piece would result in check
        check_squares: ByNonKingPiece(Bitboard),

        fn init(comptime board_status: BoardStatus, pieces: PieceArrangement, zobrist_hash: ZobristHash) Self {
            const white_blockers, const black_pinners = computeBlockerPinners(pieces, .white);
            const black_blockers, const white_pinners = computeBlockerPinners(pieces, .black);
            return Self{
                .zobrist_hash = zobrist_hash,
                .checkers = computeCheckers(board_status, pieces),
                .blockers = .init(.{ .white = white_blockers, .black = black_blockers }),
                .pinners = .init(.{ .white = white_pinners, .black = black_pinners }),
                .check_squares = computeCheckSquares(board_status, pieces),
            };
        }

        // Create a new history state for a new game given the game rules and the initial position
        pub fn initPieces(comptime board_status: BoardStatus, pieces: PieceArrangement) Self {
            return Self.init(board_status, pieces, ZobristHash.initPieces(board_status, pieces));
        }

        /// Create a contuination state of the game from a previous state
        pub fn initNext(comptime board_status: BoardStatus, zobrist_hash: ZobristHash, pieces: PieceArrangement, previous: *Self) Self {
            var state = Self.init(board_status, pieces, zobrist_hash);
            state.previous = previous;
            state.game_ply = previous.game_ply + 1;
            state.halfmove_clock = previous.halfmove_clock;
            previous.next = &state;
        }

        /// Compute a new bitboard mask of all pieces giving check to the king
        fn computeCheckers(comptime board_status: BoardStatus, pieces: PieceArrangement) Bitboard {
            const opponent_king_square = pieces.kings.get(board_status.side_to_move.opposite());
            const friendly_pieces = pieces.side_masks.get(board_status.side_to_move);
            return pieces.attackersTo(opponent_king_square, false).logicalAnd(friendly_pieces);
        }

        /// Compute the blockers and pinners for a given player returns a tuple of blockers then pinners
        fn computeBlockerPinners(pieces: PieceArrangement, blocker_perspective: Player) struct { Bitboard, Bitboard } {
            const king_square = pieces.kings.get(blocker_perspective);
            const king_mask = king_square.toBitboard();
            var blockers = Bitboard.empty;
            var pinners = Bitboard.empty;

            const occupied = pieces.occupied();
            const queens = pieces.piece_masks.get(.queen);
            const queen_rooks = queens.logicalOr(pieces.piece_masks.get(.rook));
            const queen_bishops = queens.logicalOr(pieces.piece_masks.get(.bishop));
            const snipers = king_mask.attacks(.rook, occupied).logicalAnd(queen_rooks)
                .logicalOr(king_mask.attacks(.bishop, occupied).logicalAnd(queen_bishops))
                .logicalAnd(pieces.side_masks.get(blocker_perspective.opposite()));
            const occupancy = occupied.logicalXor(snipers);

            var sniper_squares = snipers.iterator(.{});
            while (sniper_squares.next()) |sniper_square| {
                const blockers_for_sniper = between(king_square, sniper_square).logicalAnd(occupancy);
                // If only one blocker is between the king and the sniper, it is a pin
                if (!blockers_for_sniper.isEmpty() and blockers_for_sniper.numSquares() == 1) {
                    blockers = blockers.logicalOr(blockers_for_sniper);
                    if (!blockers_for_sniper.logicalAnd(pieces.side_masks.get(blocker_perspective)).isEmpty()) {
                        pinners = pinners.logicalOr(sniper_square.toBitboard());
                    }
                }
            }

            return .{
                blockers,
                pinners,
            };
        }

        /// Compute the squares that would give check if occupied by a certain piece
        fn computeCheckSquares(comptime board_status: BoardStatus, pieces: PieceArrangement) ByNonKingPiece(Bitboard) {
            const opponent_king_mask = pieces.kings.get(board_status.side_to_move.opposite()).toBitboard();
            const occupied = pieces.occupied();

            const bishop_attacks = opponent_king_mask.attacks(.bishop, occupied);
            const rook_attacks = opponent_king_mask.attacks(.rook, occupied);

            return .init(.{
                .pawn = pieces.piece_masks.get(.pawn).pawnAttacks(board_status.side_to_move.opposite()),
                .knight = pieces.piece_masks.get(.knight).attacks(.knight, occupied),
                .bishop = bishop_attacks,
                .rook = rook_attacks,
                .queen = rook_attacks.logicalOr(bishop_attacks),
            });
        }
    };
}
