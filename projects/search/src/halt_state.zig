const std = @import("std");

/// The halted state of the search
pub const HaltState = enum(u8) {
    /// The search has not been stopped yet
    running,
    /// A stop command has been issued
    stopped,
    /// A quit command has been issued
    quit,
};

const HaltError = error{
    /// The search has been stopped
    stopped,
    /// The search has been quit
    quit,
};

/// Flag representing the halted state of the search
pub const HaltFlag = struct {
    flag: std.atomic.Value(HaltState) = .init(HaltState.running),

    /// Stops the search
    pub fn stop(self: *HaltFlag) void {
        self.flag.store(.stopped, .release);
    }

    test stop {
        var flag = HaltFlag{};
        flag.stop();
        try std.testing.expectEqual(HaltState.stopped, flag.flag.load(.acquire));
    }

    /// Quits the search
    pub fn quit(self: *HaltFlag) void {
        self.flag.store(.quit, .release);
    }

    test quit {
        var flag = HaltFlag{};
        flag.quit();
        try std.testing.expectEqual(HaltState.quit, flag.flag.load(.acquire));
    }

    /// Checks if the search has been stopped or quit
    pub fn check(self: *const HaltFlag) HaltError!void {
        switch (self.flag.load(.unordered)) {
            .stopped => return error.stopped,
            .quit => return error.quit,
            .running => return,
        }
    }

    test check {
        try std.testing.expectError(error.stopped, (HaltFlag{ .flag = .init(.stopped) }).check());
        try std.testing.expectError(error.quit, (HaltFlag{ .flag = .init(.quit) }).check());
        try (HaltFlag{ .flag = .init(.running) }).check();
    }
};

test {
    std.testing.refAllDecls(@This());
}
