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
            std.debug.print("Initializing DBStore GET command\n", .{});
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
            std.debug.print("Initializing DBStore PUT command\n", .{});
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

    pub fn visualize(request: *Server.Request, command: Command) anyerror!void {
        if (CommandExecutor.store == null) {
            CommandExecutor.store = try DbStore.init();
            std.debug.print("Initializing DBStore VISUALIZE command\n", .{});
        }

        if (command.args.len != 0) {
            try request.respond("", .{ .status = http.Status.bad_request, .reason = "VISUALIZE expects no arguments!" });
            return;
        }

        try CommandExecutor.store.?.visualize();
        try request.respond("", .{});
    }

    pub fn truncate(request: *Server.Request, command: Command) anyerror!void {
        if (CommandExecutor.store == null) {
            CommandExecutor.store = try DbStore.init();
            std.debug.print("Initializing DBStore TRUNCATE command\n", .{});
        }

        if (command.args.len != 0) {
            try request.respond("", .{ .status = http.Status.bad_request, .reason = "TRUNCATE expects no arguments!" });
            return;
        }

        try CommandExecutor.store.?.truncate();
        try request.respond("", .{});
    }

    pub fn testCmd(request: *Server.Request, command: Command) anyerror!void {
        if (CommandExecutor.store == null) {
            CommandExecutor.store = try DbStore.init();
            std.debug.print("Initializing DBStore TEST command\n", .{});
        }

        if (command.args.len != 0) {
            try request.respond("", .{ .status = http.Status.bad_request, .reason = "TEST expects no arguments!" });
            return;
        }
        try CommandExecutor.store.?.testCmd();
        try request.respond("", .{});
    }
};
