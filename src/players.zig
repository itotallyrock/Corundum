
pub const Player = enum {
    White,
    Black,

    pub fn opposite(self: Player) Player {
        return if (self == .White) .Black else .White;
    }
};
