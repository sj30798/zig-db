const std = @import("std");
const http = std.http;
const Server = http.Server;
const StringUtils = @import("../Utils/StringUtils.zig").StringUtils;

pub const PathHandlerError = error{
    PathNotFound,
};

pub const RouteEntry = struct {
    method: http.Method = http.Method.GET,
    path: []const u8,
    handler: *const fn (request: *Server.Request) anyerror!void,
};

pub const RouteHandler = struct {
    routes: std.ArrayList(RouteEntry) = std.ArrayList(RouteEntry).init(std.heap.page_allocator),

    pub fn addRoute(self: *RouteHandler, entry: RouteEntry) !void {
        try self.routes.append(entry);
    }

    pub fn handleRequest(self: RouteHandler, request: *Server.Request) !void {
        for (self.routes.items) |routeEntry| {
            if (request.head.method == routeEntry.method and StringUtils.equal(request.head.target, routeEntry.path)) {
                std.debug.print("Handling request for {d} {s}\n", .{ routeEntry.method, request.head.target });
                routeEntry.handler(request) catch |err| switch (err) {
                    else => return try request.respond("", .{
                        .status = http.Status.internal_server_error,
                    }),
                };
                return;
            }
        }
        std.debug.print("Route handler not found for for {d} {s}\n", .{ request.head.method, request.head.target });

        return PathHandlerError.PathNotFound;
    }
};
