pub const CommandType = enum {
    NONE,
    GET,
    PUT,
    VISUALIZE,
    TRUNCATE,
    TEST,
};

pub const Command = struct {
    commandType: CommandType,
    args: [][]const u8,
};
