const std = @import("std");
const StringUtils = @import("./Utils/StringUtils.zig").StringUtils;
const Server = @import("./ServerComponents/Server.zig");
const Routes = @import("./ServerComponents/Routes.zig");
const http = std.http;
const HomeController = @import("./Controllers/HomeController.zig");
const CommandController = @import("./Controllers/CommandController.zig");

pub fn main() !void {
    var routeHandler = Routes.RouteHandler{};

    try routeHandler.addRoute(.{
        .handler = HomeController.home,
        .method = http.Method.GET,
        .path = "/",
    });
    try routeHandler.addRoute(.{
        .handler = CommandController.execute,
        .method = http.Method.POST,
        .path = "/execute",
    });

    const serverConfig = Server.ServerConfig{ .hostname = "127.0.0.1", .port = 8080, .routeHandler = routeHandler };
    var server = Server.Server{ .config = serverConfig };

    try server.startServer();
}
