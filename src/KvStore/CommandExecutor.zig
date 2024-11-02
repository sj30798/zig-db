const std = @import("std");
const http = std.http;
const Server = http.Server;
const DbStore = @import("./DbStore.zig").DbStore;
const DbStoreError = @import("./DbStore.zig").DbStoreError;
const Command = @import("./CommandModel.zig").Command;

pub const CommandExecutor = struct {
    var store: ?DbStore = null;

    pub fn get(request: *Server.Request, command: Command) anyerror!void {
        if (CommandExecutor.store == null) {
            CommandExecutor.store = try DbStore.init();
        }

        if (command.args.len != 1) {
            try request.respond("", .{ .status = http.Status.bad_request, .reason = "GET expects only one argument!" });
            return;
        }

        if (CommandExecutor.store.?.get(command.args[0])) |value| {
            var output: [1024]u8 = undefined;
            try request.respond(try std.fmt.bufPrint(&output, "{s}", .{value}), .{});
            return;
        } else |err| switch (err) {
            DbStoreError.KEY_NOT_FOUND => {
                try request.respond("", .{ .status = http.Status.bad_request, .reason = "Key not found!" });
            },
            else => return err,
        }
    }

    pub fn put(request: *Server.Request, command: Command) anyerror!void {
        if (CommandExecutor.store == null) {
            CommandExecutor.store = try DbStore.init();
        }

        if (command.args.len != 2) {
            try request.respond("", .{ .status = http.Status.bad_request, .reason = "PUT expects two arguments!" });
            return;
        }

        CommandExecutor.store.?.put(command.args[0], command.args[1]) catch |err| switch (err) {
            DbStoreError.KEY_ALREADY_PRESENT => {
                try request.respond("", .{ .status = http.Status.bad_request, .reason = "Key already present!" });
                return;
            },
            else => {
                return err;
            },
        };
        try request.respond("", .{});
    }
};
