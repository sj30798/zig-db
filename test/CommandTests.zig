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

    try testing.expectEqualStrings(getA.data, "a;b");

    const getC = try executeCommmand(allocator, "GET c");
    defer getC.deinit();
    try testing.expectEqual(getC.status, http.Status.bad_request);

    const viz = try executeCommmand(allocator, "VISUALIZE");
    defer viz.deinit();
    try testing.expectEqual(viz.status, http.Status.ok);
}

test "Command execution splt testing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const index = 100000;

    for (0..index) |value| {
        var buf: [100]u8 = undefined;
        const command = try std.fmt.bufPrint(&buf, "PUT a{} b", .{value});
        const startMicroTime = std.time.microTimestamp();
        const insertA = try executeCommmand(allocator, command);
        const endMicroTime = std.time.microTimestamp();
        defer insertA.deinit();

        std.debug.print("Execute command: \"{s}\" with latency {} microsec, response: {s}\n", .{ command, endMicroTime - startMicroTime, insertA.reason });

        if (std.mem.eql(u8, insertA.reason, "Key already present!")) {
            try testing.expect(insertA.status == http.Status.bad_request);
        } else {
            try testing.expect(insertA.status == http.Status.ok);
        }
    }

    std.debug.print("Verifying all keys again\n", .{});
    for (0..index) |value| {
        var buf1: [100]u8 = undefined;
        const command1 = try std.fmt.bufPrint(&buf1, "GET a{}", .{value});
        const getA = try executeCommmand(allocator, command1);
        defer getA.deinit();

        if (getA.status != http.Status.ok) {
            std.debug.print("Missing key for command: {s}\n", .{command1});
        }
        try testing.expectEqual(getA.status, http.Status.ok);

        const expectedValue = try std.fmt.bufPrint(&buf1, "a{};b", .{value});

        try testing.expectEqualStrings(getA.data, expectedValue);
    }
    std.debug.print("All keys are present\n", .{});

    const getC = try executeCommmand(allocator, "GET c");
    defer getC.deinit();
    try testing.expectEqual(getC.status, http.Status.bad_request);
}
