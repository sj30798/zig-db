const std = @import("std");
const BPlusTree = @import("./BPlusTree.zig");

pub const DbStoreError = error{
    KEY_NOT_FOUND,
    KEY_ALREADY_PRESENT,
};

pub const DbStore = struct {
    rootNode: BPlusTree.Node,
    gpa: std.heap.GeneralPurposeAllocator(.{}),

    pub fn init() !DbStore {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        var rootNode = try BPlusTree.Node.init(false, gpa.allocator());
        const emptyDataNode = try BPlusTree.Node.init(true, gpa.allocator());
        const emptyIndexElement = try BPlusTree.IndexElement.initWithFullKeyRange(emptyDataNode, gpa.allocator());
        try rootNode.indexElements.append(emptyIndexElement);
        return .{
            .rootNode = rootNode,
            .gpa = gpa,
        };
    }

    pub fn get(self: DbStore, key: []const u8) anyerror![]const u8 {
        return self.rootNode.get(key) catch |err| switch (err) {
            BPlusTree.BPlusTreeError.KEY_NOT_FOUND => return DbStoreError.KEY_NOT_FOUND,
            else => return err,
        };
    }

    pub fn put(self: *DbStore, key: []const u8, value: []const u8) anyerror!void {
        var needsRetry = false;

        self.rootNode.insert(key, value, self.gpa.allocator()) catch |err| switch (err) {
            BPlusTree.BPlusTreeError.KEY_ALREADY_PRESENT => return DbStoreError.KEY_ALREADY_PRESENT,
            BPlusTree.BPlusTreeError.NODE_FULL => {
                std.debug.print("Initilaizing with new root", .{});
                const newRootNode = try BPlusTree.Node.init_with_node(self.rootNode, self.gpa.allocator());
                self.rootNode = newRootNode;
                needsRetry = true;
            },
            else => return err,
        };

        if (needsRetry) {
            self.rootNode.insert(key, value, self.gpa.allocator()) catch |err| switch (err) {
                BPlusTree.BPlusTreeError.KEY_ALREADY_PRESENT => return DbStoreError.KEY_ALREADY_PRESENT,
                else => return err,
            };
        }
    }

    pub fn visualize(self: *DbStore) void {
        self.rootNode.visualize("(*)", 0);
        return;
    }

    pub fn truncate(self: *DbStore) anyerror!void {
        self.rootNode.deinit();
        self.rootNode = try BPlusTree.Node.init(false, self.gpa.allocator());

        return;
    }

    pub fn testCmd(self: *DbStore) anyerror!void {
        const element = try std.ArrayList(BPlusTree.DataElement).initCapacity(self.gpa.allocator(), 10);
        std.debug.print("Elements capacity: {}", .{element.capacity});
    }
};
