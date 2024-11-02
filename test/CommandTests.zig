const std = @import("std");
const http = std.http;

const testing = std.testing;
const Allocator = std.mem.Allocator;

const KvStoreResponse = struct {
    allocator: Allocator,
    status: http.Status,
    reason: []const u8,
    data: []const u8,

    pub fn init(allocator: Allocator, data: []const u8, reason: []const u8, status: http.Status) !KvStoreResponse {
        return .{
            .allocator = allocator,
            .data = try std.mem.Allocator.dupe(allocator, u8, data),
            .reason = try std.mem.Allocator.dupe(allocator, u8, reason),
            .status = status,
        };
    }

    pub fn deinit(self: KvStoreResponse) void {
        self.allocator.free(self.data);
        self.allocator.free(self.reason);
    }
};

fn executeCommmand(allocator: Allocator, payload: []const u8) !KvStoreResponse {
    const uri = try std.Uri.parse("http://localhost:8080/execute");

    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var buf: [1024]u8 = undefined;

    var request = try client.open(.POST, uri, .{
        .server_header_buffer = &buf,
    });
    defer request.deinit();

    request.transfer_encoding = .{ .content_length = payload.len };

    try request.send();

    try request.writeAll(payload);
    try request.finish();
    try request.wait();

    var rdr = request.reader();
    const body = try rdr.readAllAlloc(allocator, 1024);
    defer allocator.free(body);

    return try KvStoreResponse.init(allocator, body, request.response.reason, request.response.status);
}

test "Command execution sanity testing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const insertA = try executeCommmand(allocator, "PUT a b");
    defer insertA.deinit();
    if (std.mem.eql(u8, insertA.reason, "Key already present!")) {
        try testing.expect(insertA.status == http.Status.bad_request);
    } else {
        try testing.expect(insertA.status == http.Status.ok);
    }

    const getA = try executeCommmand(allocator, "GET a");
    defer getA.deinit();
    try testing.expectEqual(getA.status, http.Status.ok);

    try testing.expectEqualStrings(getA.data, "b");

    const getC = try executeCommmand(allocator, "GET c");
    defer getC.deinit();
    try testing.expectEqual(getC.status, http.Status.bad_request);
}
