const std = @import("std");
const http = std.http;
const Server = http.Server;
const HomeView = @import("../Views/HomeView.zig");

pub fn home(request: *Server.Request) !void {
    const homeHtmlView = try HomeView.homeView();

    try request.respond(homeHtmlView, .{});
}
