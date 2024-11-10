const CommandModel = @import("CommandModel.zig");
const StringUtils = @import("../Utils/StringUtils.zig");
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;

pub fn parseCommand(userInput: []const u8) !CommandModel.Command {
    const splittedInput = try StringUtils.split(userInput, " ");

    var commandType = CommandModel.CommandType.NONE;
    if (StringUtils.equal(splittedInput[0], "GET")) {
        commandType = CommandModel.CommandType.GET;
    } else if (StringUtils.equal(splittedInput[0], "PUT")) {
        commandType = CommandModel.CommandType.PUT;
    } else if (StringUtils.equal(splittedInput[0], "VISUALIZE")) {
        commandType = CommandModel.CommandType.VISUALIZE;
    } else {
        return CommandModel.Command{
            .commandType = CommandModel.CommandType.NONE,
            .args = &[_][]const u8{},
        };
    }

    return CommandModel.Command{
        .commandType = commandType,
        .args = splittedInput[1..],
    };
}

test "CommandParser parseCommand GET" {
    const command = try parseCommand("GET arg1 arg2");

    try testing.expectEqual(command, CommandModel.CommandType.GET);
    try testing.expect(command.args.len == 2);
    try testing.expectEqualStrings("arg1", command.args[0]);
    try testing.expectEqualStrings("arg2", command.args[0]);
}

test "CommandParser parseCommand PUT" {
    const command = try parseCommand("PUT arg1 arg2");

    try testing.expectEqual(command, CommandModel.CommandType.PUT);
    try testing.expect(command.args.len == 2);
    try testing.expectEqualStrings("arg1", command.args[0]);
    try testing.expectEqualStrings("arg2", command.args[0]);
}

test "CommandParser parseCommand NONE" {
    const command = try parseCommand("GETS arg1 arg2");

    try testing.expectEqual(command, CommandModel.CommandType.NONE);
    try testing.expect(command.args.len == 0);
}

test "CommandParser parseCommand VISUALIZE" {
    const command = try parseCommand("VISUALIZE");

    try testing.expectEqual(command, CommandModel.CommandType.VISUALIZE);
    try testing.expect(command.args.len == 0);
}
