const std = @import("std");
const http = std.http;
const Server = http.Server;
const Command = @import("../KvStore/CommandModel.zig").Command;
const CommandType = @import("../KvStore/CommandModel.zig").CommandType;
const CommandParser = @import("../KvStore/CommandParser.zig");

pub fn execute(request: *Server.Request) !void {
    var bodyBuff = std.ArrayList(u8).init(std.heap.page_allocator);
    const reader = try request.reader();
    try reader.readAllArrayList(&bodyBuff, 1024);

    const command = try CommandParser.parseCommand(bodyBuff.items);

    if (command.commandType == CommandType.NONE) {
        try request.respond("Unrecognized command provided", .{
            .status = http.Status.forbidden,
        });
        return;
    } else if (command.commandType == CommandType.GET) {
        try request.respond("Received command GET", .{});
        return;
    } else if (command.commandType == CommandType.PUT) {
        try request.respond("Received command PUT", .{});
        return;
    }

    try request.respond("", .{
        .status = http.Status.forbidden,
    });
}
