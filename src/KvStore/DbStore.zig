const std = @import("std");
const BPlusTree = @import("./BPlusTree.zig");

pub const DbStoreError = error{
    KEY_NOT_FOUND,
    KEY_ALREADY_PRESENT,
};

pub const DbStore = struct {
    rootNode: BPlusTree.Node,

    pub fn init() !DbStore {
        const rootNode = try BPlusTree.Node.init(false);
        return .{
            .rootNode = rootNode,
        };
    }

    pub fn get(self: DbStore, key: []const u8) anyerror![]const u8 {
        return self.rootNode.get(key) catch |err| switch (err) {
            BPlusTree.BPlusTreeError.KEY_NOT_FOUND => return DbStoreError.KEY_NOT_FOUND,
            else => return err,
        };
    }

    pub fn put(self: *DbStore, key: []const u8, value: []const u8) anyerror!void {
        return self.rootNode.insert(key, value) catch |err| switch (err) {
            BPlusTree.BPlusTreeError.KEY_ALREADY_PRESENT => return DbStoreError.KEY_ALREADY_PRESENT,
            else => return err,
        };
    }
};
