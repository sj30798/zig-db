const std = @import("std");
const StringUtils = @import("../Utils/StringUtils.zig");

pub const IndexElement = struct {
    keyLow: std.ArrayList(u8),
    keyHigh: std.ArrayList(u8),
    children: Node,

    pub fn init(keyLow: []const u8, keyHigh: []const u8, children: Node, allocator: std.mem.Allocator) !IndexElement {
        var keyLowArr = std.ArrayList(u8).init(allocator);
        try keyLowArr.appendSlice(try allocator.dupe(u8, keyLow));
        var keyHighArr = std.ArrayList(u8).init(allocator);
        try keyHighArr.appendSlice(try allocator.dupe(u8, keyHigh));

        return .{
            .keyLow = keyLowArr,
            .keyHigh = keyHighArr,
            .children = children,
        };
    }

    pub fn initWithFullKeyRange(children: Node, allocator: std.mem.Allocator) !IndexElement {
        const keyLowArr = std.ArrayList(u8).init(allocator);
        var keyHighArr = std.ArrayList(u8).init(allocator);
        try keyHighArr.appendNTimes(255, 100);

        return .{
            .keyLow = keyLowArr,
            .keyHigh = keyHighArr,
            .children = children,
        };
    }

    pub fn setKeyLow(self: *IndexElement, key: []const u8, allocator: std.mem.Allocator) !void {
        var keyLowArr = std.ArrayList(u8).init(allocator);
        try keyLowArr.appendSlice(try allocator.dupe(u8, key));

        self.keyLow.deinit();

        self.keyLow = keyLowArr;
    }

    pub fn isKeyInRange(self: IndexElement, key: []const u8) bool {
        if (StringUtils.compare(self.keyLow.items, key) >= 0) {
            if (StringUtils.compare(key, self.keyHigh.items) > 0) {
                return true;
            }
        }
        return false;
    }

    pub fn deinit(self: *IndexElement) void {
        self.children.deinit();
        self.keyLow.deinit();
        self.keyHigh.deinit();
    }
};

pub const DataElement = struct {
    key: std.ArrayList(u8),
    value: std.ArrayList(u8),

    pub fn init(key: []const u8, value: []const u8, allocator: std.mem.Allocator) !DataElement {
        var keyArr = std.ArrayList(u8).init(allocator);
        try keyArr.appendSlice(try allocator.dupe(u8, key));
        var valueArr = std.ArrayList(u8).init(allocator);
        try valueArr.appendSlice(try allocator.dupe(u8, value));

        return .{
            .key = keyArr,
            .value = valueArr,
        };
    }

    pub fn getKey(self: DataElement) []const u8 {
        return self.key.items;
    }

    pub fn getValue(self: DataElement) []const u8 {
        return self.value.items;
    }

    pub fn deinit(self: DataElement) void {
        self.key.deinit();
        self.value.deinit();
    }

    pub fn compareKey(self: DataElement, other: []const u8) i8 {
        return StringUtils.compare(self.key.items, other);
    }
};

pub const BPlusTreeError = error{
    NODE_FULL,
    EMPTY_KEY_PROVIDED,
    KEY_ALREADY_PRESENT,
    INVALID_ARGS,
    KEY_NOT_FOUND,
};

pub const Node = struct {
    isLeaf: bool,
    indexElements: std.ArrayList(IndexElement),
    dataElements: std.ArrayList(DataElement),

    const MAX_INDEX_NODE_SIZE = 20;
    const MAX_DATA_NODE_SIZE = 1000;

    pub fn init(isLeaf: bool, allocator: std.mem.Allocator) !Node {
        var indexElements: std.ArrayList(IndexElement) = undefined;
        var dataElements: std.ArrayList(DataElement) = undefined;
        if (isLeaf) {
            dataElements = try std.ArrayList(DataElement).initCapacity(allocator, MAX_DATA_NODE_SIZE);
        } else {
            indexElements = try std.ArrayList(IndexElement).initCapacity(allocator, MAX_INDEX_NODE_SIZE);
        }
        return .{
            .isLeaf = isLeaf,
            .indexElements = indexElements,
            .dataElements = dataElements,
        };
    }

    pub fn init_with_node(child: Node, allocator: std.mem.Allocator) !Node {
        const dataElements: std.ArrayList(DataElement) = undefined;
        var indexElements = try std.ArrayList(IndexElement).initCapacity(allocator, MAX_INDEX_NODE_SIZE);
        try indexElements.append(try IndexElement.initWithFullKeyRange(child, allocator));
        return .{
            .isLeaf = false,
            .indexElements = indexElements,
            .dataElements = dataElements,
        };
    }

    pub fn deinit(self: *Node) void {
        if (self.isLeaf) {
            for (0..self.dataElements.items.len) |i| {
                self.dataElements.items[i].deinit();
            }
            self.dataElements.deinit();
        } else {
            for (0..self.indexElements.items.len) |i| {
                self.indexElements.items[i].deinit();
            }
            self.indexElements.deinit();
        }
    }

    fn moveElements(self: *Node, other: *Node, startIndexInclusive: usize, endIndexExclusive: usize) !void {
        if (self.isLeaf != other.isLeaf) {
            return BPlusTreeError.INVALID_ARGS;
        }

        if (self.isLeaf) {
            for (startIndexInclusive..endIndexExclusive) |_| {
                const elementToMove = other.dataElements.orderedRemove(startIndexInclusive);
                self.dataElements.appendAssumeCapacity(elementToMove);
            }
        } else {
            for (startIndexInclusive..endIndexExclusive) |_| {
                const elementToMove = other.indexElements.orderedRemove(startIndexInclusive);
                self.indexElements.appendAssumeCapacity(elementToMove);
            }
        }
    }

    pub fn getKeyAtIndex(self: Node, index: usize) ![]const u8 {
        if (self.getSize() <= index) {
            return BPlusTreeError.INVALID_ARGS;
        }

        if (self.isLeaf) {
            return self.dataElements.items[index].getKey();
        } else {
            return self.indexElements.items[index].keyLow.items;
        }
    }

    pub fn getSize(self: Node) usize {
        var len: usize = 0;
        if (self.isLeaf) {
            len = self.dataElements.items.len;
        } else {
            len = self.indexElements.items.len;
        }

        return len;
    }

    fn isFull(self: Node) bool {
        if (self.isLeaf) {
            if (self.getSize() == MAX_DATA_NODE_SIZE) {
                return true;
            }
        } else if (self.getSize() == MAX_INDEX_NODE_SIZE) {
            return true;
        }
        return false;
    }

    pub fn getSplitKeyIndex(self: Node) usize {
        const len: usize = self.getSize();
        return len / 2;
    }

    fn split(self: *Node, index: usize, allocator: std.mem.Allocator) !void {
        if (self.isLeaf) {
            return BPlusTreeError.INVALID_ARGS;
        }
        if (index > MAX_INDEX_NODE_SIZE) {
            return BPlusTreeError.INVALID_ARGS;
        }
        if (self.isFull()) {
            return BPlusTreeError.NODE_FULL;
        }

        var childToSplit: *IndexElement = &self.indexElements.items[index];
        const splitKeyIndex = childToSplit.children.getSplitKeyIndex();
        const splitKeyLow = try allocator.dupe(u8, try childToSplit.children.getKeyAtIndex(splitKeyIndex));

        var lChild = try Node.init(childToSplit.children.isLeaf, allocator);
        try lChild.moveElements(&childToSplit.children, 0, splitKeyIndex);
        const lElement = try IndexElement.init(childToSplit.keyLow.items, splitKeyLow, lChild, allocator);

        try self.indexElements.insert(index, lElement);
        try self.indexElements.items[index + 1].setKeyLow(splitKeyLow, allocator);
    }

    pub fn get(self: Node, key: []const u8) BPlusTreeError![]const u8 {
        if (self.isLeaf) {
            for (self.dataElements.items) |element| {
                const compKey = element.compareKey(key);
                if (compKey == 0) {
                    return element.getValue();
                }
                if (compKey > 0) {
                    continue;
                }
                break;
            }
            return BPlusTreeError.KEY_NOT_FOUND;
        } else {
            for (self.indexElements.items) |element| {
                if (element.isKeyInRange(key)) {
                    return element.children.get(key);
                }
            }
            return BPlusTreeError.KEY_NOT_FOUND;
        }
    }

    pub fn visualize(self: Node, parentKey: []const u8, depth: usize) void {
        if (self.isLeaf) {
            for (self.dataElements.items) |value| {
                std.debug.print("[{}] {s} => {s}->{s}\n", .{ depth, parentKey, value.getKey(), value.getValue() });
            }
        } else {
            for (self.indexElements.items) |value| {
                std.debug.print("[{}] {s} => {s}..{s}\n", .{ depth, parentKey, value.keyLow.items, value.keyHigh.items });
            }

            for (self.indexElements.items) |value| {
                const childParent = value.keyLow;
                value.children.visualize(childParent.items, depth + 1);
            }
        }
        return;
    }

    pub fn insert(self: *Node, key: []const u8, value: []const u8, allocator: std.mem.Allocator) anyerror!void {
        if (key.len == 0) {
            return BPlusTreeError.EMPTY_KEY_PROVIDED;
        }

        if (self.isLeaf) {
            if (self.isFull()) {
                return BPlusTreeError.NODE_FULL;
            }

            var indexToInsert: usize = self.dataElements.items.len;
            for (self.dataElements.items, 0..) |item, i| {
                const keyComp = item.compareKey(key);
                if (keyComp == 0) {
                    return BPlusTreeError.KEY_ALREADY_PRESENT;
                } else if (keyComp > 0) {
                    continue;
                } else if (keyComp < 0) {
                    indexToInsert = i;
                    break;
                } else {
                    unreachable;
                }
            }

            const element = try DataElement.init(key, value, allocator);
            if (indexToInsert == self.dataElements.items.len) {
                try self.dataElements.append(element);
            } else {
                try self.dataElements.insert(indexToInsert, element);
            }

            return;
        }

        if (self.isLeaf) {
            unreachable;
        }

        var childIndexToInsert: usize = 0;

        for (self.indexElements.items, 0..) |element, i| {
            if (element.isKeyInRange(key)) {
                childIndexToInsert = i;
                break;
            }
        }

        if (self.indexElements.items.len == childIndexToInsert) {
            unreachable;
        }

        self.indexElements.items[childIndexToInsert].children.insert(key, value, allocator) catch |err| switch (err) {
            BPlusTreeError.NODE_FULL => {
                if (self.isFull()) {
                    return BPlusTreeError.NODE_FULL;
                } else {
                    try self.split(childIndexToInsert, allocator);
                    return try self.insert(key, value, allocator);
                }
            },
            else => return err,
        };
    }
};
