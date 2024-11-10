const std = @import("std");
const StringUtils = @import("../Utils/StringUtils.zig");

pub const Element = struct {
    key: []const u8,
    value: []const u8,

    pub fn getKey(self: Element) []const u8 {
        return self.key;
    }

    pub fn getValue(self: Element) []const u8 {
        return self.value;
    }

    pub fn setValue(self: *Element, value: []const u8) void {
        self.value = value;
    }

    pub fn compareKey(self: Element, other: []const u8) i8 {
        return StringUtils.compare(self.key, other);
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
    keys: std.ArrayList([]const u8),
    children: std.ArrayList(Node),
    isLeaf: bool,
    elements: std.ArrayList(Element),

    const MAX_LEAF_NODE_SIZE = 10;

    pub fn init(isLeaf: bool) !Node {
        return .{
            .isLeaf = isLeaf,
            .keys = try std.ArrayList([]const u8).initCapacity(std.heap.page_allocator, MAX_LEAF_NODE_SIZE),
            .children = try std.ArrayList(Node).initCapacity(std.heap.page_allocator, MAX_LEAF_NODE_SIZE),
            .elements = try std.ArrayList(Element).initCapacity(std.heap.page_allocator, MAX_LEAF_NODE_SIZE),
        };
    }

    fn duplicateElements(self: *Node, other: Node, startIndexInclusive: usize, endIndexExclusive: usize) !void {
        if (self.isLeaf != other.isLeaf) {
            return BPlusTreeError.INVALID_ARGS;
        }

        if (self.isLeaf) {
            for (startIndexInclusive..endIndexExclusive) |index| {
                self.elements.appendAssumeCapacity(other.elements.items[index]);
            }
        } else {
            for (startIndexInclusive..endIndexExclusive + 1) |index| {
                self.children.appendAssumeCapacity(other.children.items[index]);
            }
            for (startIndexInclusive..endIndexExclusive) |index| {
                self.keys.appendAssumeCapacity(other.keys.items[index]);
            }
        }
    }

    pub fn getElementAtIndex(self: Node, index: usize) ![]const u8 {
        if (self.getSize() <= index) {
            return BPlusTreeError.INVALID_ARGS;
        }

        if (self.isLeaf) {
            return self.elements.items[index].key;
        } else {
            return self.keys.items[index];
        }
    }

    pub fn getSize(self: Node) usize {
        var len: usize = 0;
        if (self.isLeaf) {
            len = self.elements.items.len;
        } else {
            len = self.keys.items.len;
        }

        return len;
    }

    pub fn getSplitKeyIndex(self: Node) usize {
        const len: usize = self.getSize();
        return len / 2;
    }

    fn split(self: *Node, index: usize) !void {
        if (self.isLeaf) {
            return BPlusTreeError.INVALID_ARGS;
        }
        if (index > MAX_LEAF_NODE_SIZE) {
            return BPlusTreeError.INVALID_ARGS;
        }
        if (self.keys.items.len == MAX_LEAF_NODE_SIZE) {
            return BPlusTreeError.NODE_FULL;
        }

        const childToSplit: Node = self.children.items[index];
        const splitKeyIndex = childToSplit.getSplitKeyIndex();
        const splitKey = try childToSplit.getElementAtIndex(splitKeyIndex);
        var lChild = try Node.init(childToSplit.isLeaf);
        var rChild = try Node.init(childToSplit.isLeaf);

        try lChild.duplicateElements(childToSplit, 0, splitKeyIndex);
        try rChild.duplicateElements(childToSplit, splitKeyIndex, childToSplit.getSize());

        try self.keys.insert(index, splitKey);
        try self.children.insert(index, lChild);
        try self.children.insert(index + 1, rChild);
        _ = self.children.orderedRemove(index + 2);
    }

    pub fn get(self: Node, key: []const u8) BPlusTreeError![]const u8 {
        if (self.isLeaf) {
            for (self.elements.items) |element| {
                const compKey = element.compareKey(key);
                if (compKey == 0) {
                    return element.value;
                }
                if (compKey > 0) {
                    continue;
                }
                break;
            }
            return BPlusTreeError.KEY_NOT_FOUND;
        } else {
            for (self.keys.items, 0..) |items, i| {
                if (StringUtils.compare(items, key) >= 0) {
                    continue;
                }
                return try self.children.items[i].get(key);
            }
            if (self.children.items.len == 0) {
                return BPlusTreeError.KEY_NOT_FOUND;
            }
            return try self.children.items[self.children.items.len - 1].get(key);
        }
    }

    pub fn visualize(self: Node, parentKey: []const u8) void {
        if (self.isLeaf) {
            for (self.elements.items) |value| {
                std.debug.print("{s} => {s}->{s}\n", .{ parentKey, value.getKey(), value.getValue() });
            }
        }

        for (self.keys.items) |value| {
            std.debug.print("{s} => {s}\n", .{ parentKey, value });
        }

        for (self.children.items, 0..) |value, i| {
            const childParent = if (i == 0) parentKey else self.keys.items[i - 1];
            value.visualize(childParent);
        }
        return;
    }

    pub fn insert(self: *Node, key: []const u8, value: []const u8) anyerror!void {
        if (key.len == 0) {
            return BPlusTreeError.EMPTY_KEY_PROVIDED;
        }

        if (self.isLeaf) {
            if (self.getSize() == MAX_LEAF_NODE_SIZE) {
                return BPlusTreeError.NODE_FULL;
            }

            var indexToInsert: usize = self.elements.items.len;
            for (self.elements.items, 0..) |item, i| {
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

            const element = Element{ .key = key, .value = value };
            if (indexToInsert == self.elements.items.len) {
                try self.elements.append(element);
            } else {
                try self.elements.insert(indexToInsert, element);
            }

            return;
        }

        if (self.isLeaf) {
            unreachable;
        }

        var childIndexToInsert = self.keys.items.len;

        for (self.keys.items, 0..) |item, i| {
            if (StringUtils.compare(item, key) >= 0) {
                continue;
            } else {
                childIndexToInsert = i;
            }
        }

        if (self.children.items.len == childIndexToInsert) {
            try self.children.append(try Node.init(true));
        }

        self.children.items[childIndexToInsert].insert(key, value) catch |err| switch (err) {
            BPlusTreeError.NODE_FULL => {
                if (self.getSize() == MAX_LEAF_NODE_SIZE) {
                    return BPlusTreeError.NODE_FULL;
                } else {
                    try self.split(childIndexToInsert);
                    return try self.insert(key, value);
                }
            },
            else => return err,
        };
    }
};
