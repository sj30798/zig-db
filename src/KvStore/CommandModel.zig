pub const CommandType = enum {
    NONE,
    GET,
    PUT,
};

pub const Command = struct {
    commandType: CommandType,
    args: [][]const u8,
};
