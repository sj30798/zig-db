pub const CommandType = enum {
    NONE,
    GET,
    PUT,
    VISUALIZE,
};

pub const Command = struct {
    commandType: CommandType,
    args: [][]const u8,
};
