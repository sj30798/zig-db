const std = @import("std");
const net = std.net;
const http = std.http;
const Routes = @import("Routes.zig");
const RouteHandler = Routes.RouteHandler;

pub const ServerConfig = struct {
    hostname: []const u8,
    port: u16,
    routeHandler: RouteHandler,
};

pub const Server = struct {
    config: ServerConfig,

    pub fn startServer(self: *Server) !void {
        const stdout = std.io.getStdOut().writer();
        const stderr = std.io.getStdErr().writer();

        const addr = net.Address.parseIp4(self.config.hostname, self.config.port) catch |err| {
            try stderr.print("An error occurred while resolving the IP address: {}\n", .{err});
            return;
        };

        var server = try addr.listen(.{});

        try stdout.print("Starting server at port: {d}\n", .{server.listen_address.getPort()});
        while (true) {
            var connection = server.accept() catch |err| {
                try stderr.print("Connection to client interrupted: {}\n", .{err});
                continue;
            };
            defer connection.stream.close();

            var read_buffer: [1024]u8 = undefined;
            var http_server = http.Server.init(connection, &read_buffer);

            var request = http_server.receiveHead() catch |err| {
                try stderr.print("Could not read head: {}\n", .{err});
                continue;
            };

            self.config.routeHandler.handleRequest(&request) catch |err| switch (err) {
                Routes.PathHandlerError.PathNotFound => {
                    request.respond("", .{ .status = http.Status.not_found }) catch |err1| switch (err1) {
                        else => {
                            try stderr.print("Failed to respond to request", .{});
                        },
                    };
                    continue;
                },
                else => {
                    request.respond("", .{
                        .status = http.Status.internal_server_error,
                    }) catch |err1| switch (err1) {
                        else => {
                            try stderr.print("Failed to respond to request", .{});
                        },
                    };
                    continue;
                },
            };
        }
        return;
    }
};
