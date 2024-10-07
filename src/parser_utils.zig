const std = @import("std");
const mecha = @import("mecha");

pub fn full(parser: anytype) mecha.Parser(void) {
    return mecha.combine(.{
        parser.discard(),
        mecha.eos.discard(),
    });
}

pub fn fullT(comptime T: type, parser: mecha.Parser(T)) mecha.Parser(T) {
    return mecha.combine(.{
        parser,
        mecha.eos.discard(),
    });
}

pub const whitespace = mecha.many(mecha.ascii.whitespace, .{ .collect = false, .min = 1 });

pub fn takeUntil(end_parser: anytype) mecha.Parser([]const u8) {
    return .{
        .parse = struct {
            fn parse(allocator: std.mem.Allocator, s: []const u8) !mecha.Result([]const u8) {
                var index: usize = 0;
                while (index < s.len) {
                    const end = end_parser.parse(allocator, s[index..]) catch |err| if (err == error.ParserFailed) {
                        index += 1;
                        continue;
                    } else {
                        return err;
                    };
                    return mecha.Result([]const u8){ .value = s[0 .. index - 1], .rest = end.rest };
                }
                return mecha.Result([]const u8){ .value = s, .rest = &[_]u8{} };
            }
        }.parse,
    };
}
