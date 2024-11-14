const std = @import("std");
const http = std.http;

const testing = std.testing;
const Allocator = std.mem.Allocator;

pub const Element = struct {
    key: std.ArrayList(u8),
    value: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(key: []const u8, value: []const u8, allocator: std.mem.Allocator) !Element {
        var keyArr = std.ArrayList(u8).init(allocator);
        try keyArr.appendSlice(key);
        var valueArr = std.ArrayList(u8).init(allocator);
        try valueArr.appendSlice(value);

        return .{
            .key = keyArr,
            .value = valueArr,
            .allocator = allocator,
        };
    }

    pub fn getKey(self: Element) []const u8 {
        return self.key.items;
    }

    pub fn getValue(self: Element) []const u8 {
        return self.value.items;
    }

    pub fn deinit(self: Element) void {
        self.key.deinit();
        self.value.deinit();
    }

    pub fn setValue(self: *Element, value: []const u8) void {
        self.value.deinit();
        self.value = std.ArrayList(u8).init(self.allocator);
        try self.value.appendSlice(value);
    }
};

test "Allocator" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var element = try std.ArrayList(Element).initCapacity(allocator, 10);
    std.debug.print("Elements capacity: {}\n", .{element.capacity});

    try element.append(try Element.init("key1", "value", allocator));
    try element.append(try Element.init("key2", "value", allocator));
    try element.append(try Element.init("key3", "value", allocator));
    try element.append(try Element.init("key4", "value", allocator));

    std.debug.print("Array length: {}\n", .{element.items.len});
    for (element.items) |value| {
        std.debug.print("Item in arr: {s}\n", .{value.getKey()});
    }
    _ = element.orderedRemove(1);
    std.debug.print("Array length: {}\n", .{element.items.len});
    for (element.items) |value| {
        std.debug.print("Item in arr after remove: {s}\n", .{value.getKey()});
    }
}
