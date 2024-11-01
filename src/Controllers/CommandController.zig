const std = @import("std");
const http = std.http;
const Server = http.Server;
const Command = @import("../KvStore/CommandModel.zig").Command;
const CommandType = @import("../KvStore/CommandModel.zig").CommandType;
const CommandParser = @import("../KvStore/CommandParser.zig");
const CommandExecutor = @import("../KvStore/CommandExecutor.zig").CommandExecutor;
const CommandExecutorError = @import("../KvStore/CommandExecutor.zig").CommandExecutorError;

pub fn execute(request: *Server.Request) !void {
    var bodyBuff = std.ArrayList(u8).init(std.heap.page_allocator);
    const reader = try request.reader();
    try reader.readAllArrayList(&bodyBuff, 1024);

    const command = try CommandParser.parseCommand(bodyBuff.items);

    if (command.commandType == CommandType.NONE) {
        try request.respond("", .{ .status = http.Status.forbidden, .reason = "Command not identified!" });
        return;
    } else if (command.commandType == CommandType.GET) {
        try CommandExecutor.get(request, command);
        return;
    } else if (command.commandType == CommandType.PUT) {
        try CommandExecutor.put(request, command);
        return;
    }

    try request.respond("", .{
        .status = http.Status.internal_server_error,
    });
}
