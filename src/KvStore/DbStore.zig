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
        const emptyDataNode = try BPlusTree.Node.init(true, gpa.allocator());
        const rootNode = try BPlusTree.Node.initWithChild(emptyDataNode, gpa.allocator());
        return .{
            .rootNode = rootNode,
            .gpa = gpa,
        };
    }

    pub fn get(self: *DbStore, key: []const u8) anyerror![]const u8 {
        const allocator = self.gpa.allocator();
        var attributes = try BPlusTree.AttributeList.initCapacity(allocator, 1);
        try attributes.append(try BPlusTree.Attribute.initString(key, allocator));
        const searchElement = try BPlusTree.DataNode.init(attributes);

        return self.rootNode.get(searchElement, allocator) catch |err| switch (err) {
            BPlusTree.BPlusTreeError.KEY_NOT_FOUND => return DbStoreError.KEY_NOT_FOUND,
            else => return err,
        };
    }

    pub fn put(self: *DbStore, key: []const u8, value: []const u8) anyerror!void {
        var needsRetry = false;

        const allocator = self.gpa.allocator();
        var attributes = try BPlusTree.AttributeList.initCapacity(allocator, 2);
        try attributes.append(try BPlusTree.Attribute.initString(key, allocator));
        try attributes.append(try BPlusTree.Attribute.initString(value, allocator));
        const insertElement = try BPlusTree.DataNode.init(attributes);

        self.rootNode.insert(insertElement, self.gpa.allocator()) catch |err| switch (err) {
            BPlusTree.BPlusTreeError.KEY_ALREADY_PRESENT => return DbStoreError.KEY_ALREADY_PRESENT,
            BPlusTree.BPlusTreeError.NODE_FULL => {
                std.debug.print("Initilaizing with new root\n", .{});

                const oldRoot = self.rootNode;
                const newRootNode = try BPlusTree.Node.initWithChild(oldRoot, allocator);
                if (newRootNode.m_indexElements.items.len != 1) {
                    unreachable;
                }
                self.rootNode = newRootNode;
                if (self.rootNode.m_indexElements.items.len != 1) {
                    unreachable;
                }
                needsRetry = true;
            },
            else => return err,
        };

        if (needsRetry) {
            self.rootNode.insert(insertElement, allocator) catch |err| switch (err) {
                BPlusTree.BPlusTreeError.KEY_ALREADY_PRESENT => return DbStoreError.KEY_ALREADY_PRESENT,
                else => return err,
            };
        }
    }

    pub fn visualize(self: *DbStore) !void {
        const allocator = self.gpa.allocator();

        try self.rootNode.visualizeRoot(allocator, true);
        return;
    }

    pub fn truncate(self: *DbStore) anyerror!void {
        self.rootNode.deinit();
        self.rootNode = try BPlusTree.Node.init(false, self.gpa.allocator());

        return;
    }

    pub fn testCmd(self: *DbStore) anyerror!void {
        const element = try std.ArrayList(BPlusTree.DataNode).initCapacity(self.gpa.allocator(), 10);
        std.debug.print("Elements capacity: {}", .{element.capacity});
    }
};
