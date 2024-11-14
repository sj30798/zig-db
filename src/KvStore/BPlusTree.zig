const std = @import("std");
const StringUtils = @import("../Utils/StringUtils.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const AttributeTypeTag = enum {
    int,
    string,
};

pub const Attribute = union(AttributeTypeTag) {
    int: i8,
    string: ArrayList(u8),

    const Self = @This();

    pub fn initInt(intAttr: i8) Attribute {
        return .{ .int = intAttr };
    }

    pub fn initString(stringAttr: []const u8, allocator: Allocator) !Attribute {
        var keyAttributeValue = std.ArrayList(u8).init(allocator);
        try keyAttributeValue.insertSlice(0, stringAttr);

        return .{ .string = keyAttributeValue };
    }

    pub fn deinit(self: Attribute) void {
        switch (self) {
            AttributeTypeTag.string => self.string.deinit(),
            AttributeTypeTag.int => return,
        }
    }

    pub fn Compare(self: Self, other: Self) !i8 {
        if (@as(AttributeTypeTag, self) != @as(AttributeTypeTag, other)) {
            unreachable;
        }
        switch (self) {
            AttributeTypeTag.string => return StringUtils.compare(self.string.items, other.string.items),
            AttributeTypeTag.int => {
                if (self.int == other.int) {
                    return 0;
                } else if (self.int < other.int) {
                    return -1;
                } else {
                    return 1;
                }
            },
        }
    }

    pub fn toString(self: Self) []const u8 {
        return self.string.items;
    }
};

pub const AttributeList = ArrayList(Attribute);

pub const DataNode = struct {
    m_attributes: AttributeList,
    m_isKey: bool = false,
    m_isKeyMin: bool = false,
    m_isKeyMax: bool = false,

    const Self = @This();

    pub fn init(attributes: AttributeList) !DataNode {
        return .{
            .m_attributes = try attributes.clone(),
        };
    }

    pub fn initKey(attributes: AttributeList) !DataNode {
        return .{
            .m_attributes = try attributes.clone(),
            .m_isKey = true,
        };
    }

    pub fn initKeyMin() DataNode {
        return .{
            .m_attributes = undefined,
            .m_isKey = true,
            .m_isKeyMin = true,
        };
    }

    pub fn initKeyMax() DataNode {
        return .{
            .m_attributes = undefined,
            .m_isKey = true,
            .m_isKeyMax = true,
        };
    }

    pub fn isKey(self: Self) bool {
        return self.m_isKey;
    }

    pub fn deinit(self: Self) void {
        for (self.m_attributes.items) |attribute| {
            attribute.deinit();
        }
        self.m_attributes.deinit();
    }

    pub fn getKeySize(_: Self) usize {
        // TODO: Introduce schema dependency
        return 1;
    }

    pub fn getAttributeAtIndex(self: Self, index: usize) Attribute {
        return self.m_attributes.items[index];
    }

    pub fn compareKey(self: Self, other: DataNode) !i8 {
        if (self.getKeySize() != other.getKeySize()) {
            unreachable;
        }

        if (self.m_isKeyMin) {
            if (other.m_isKeyMin) {
                return 0;
            } else {
                return 1;
            }
        }

        if (self.m_isKeyMax) {
            if (other.m_isKeyMax) {
                return 0;
            } else {
                return -1;
            }
        }

        for (0..self.getKeySize()) |index| {
            const compareResult = try self.getAttributeAtIndex(index).Compare(other.getAttributeAtIndex(index));
            if (compareResult != 0) {
                return compareResult;
            }
        }
        return 0;
    }

    pub fn toString(self: Self, allocator: Allocator) ![]const u8 {
        if (self.m_isKeyMin) {
            return "KEY_MIN";
        }
        if (self.m_isKeyMax) {
            return "KEY_MAX";
        }

        var result = std.ArrayList(u8).init(allocator);
        for (0..self.m_attributes.items.len) |index| {
            if (index != 0) {
                try result.appendSlice(";");
            }
            try result.appendSlice(self.getAttributeAtIndex(index).toString());
        }
        return try result.toOwnedSlice();
    }
};

pub const IndexNode = struct {
    m_keyLow: DataNode,
    m_keyHigh: DataNode,
    m_child: Node,

    const Self = @This();

    pub fn init(keyLow: DataNode, keyHigh: DataNode, child: Node) !IndexNode {
        return .{
            .m_keyLow = keyLow,
            .m_keyHigh = keyHigh,
            .m_child = child,
        };
    }

    pub fn initWithFullKeyRange(child: Node) IndexNode {
        const indexKeyLow = DataNode.initKeyMin();
        const indexKeyHigh = DataNode.initKeyMax();

        return .{
            .m_keyLow = indexKeyLow,
            .m_keyHigh = indexKeyHigh,
            .m_child = child,
        };
    }

    pub fn isKeyInRange(self: Self, key: DataNode) bool {
        if (try self.m_keyLow.compareKey(key) >= 0 and try self.m_keyHigh.compareKey(key) < 0) {
            return true;
        }
        return false;
    }

    pub fn getKeyLow(self: Self) DataNode {
        return self.m_keyLow;
    }

    pub fn getKeyHigh(self: Self) DataNode {
        return self.m_keyHigh;
    }

    pub fn getChild(self: *Self) *Node {
        return &self.m_child;
    }

    pub fn deinit(self: Self) void {
        self.m_child.deinit();
        self.m_keyLow.deinit();
        self.m_keyHigh.deinit();
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
    m_isDataNode: bool,
    m_indexElements: std.ArrayList(IndexNode),
    m_dataElements: std.ArrayList(DataNode),

    const Self = @This();

    const MAX_INDEX_NODE_SIZE = 100;
    const MAX_DATA_NODE_SIZE = 1000;

    pub fn init(isDataNode: bool, allocator: Allocator) !Node {
        var indexElements: std.ArrayList(IndexNode) = undefined;
        var dataElements: std.ArrayList(DataNode) = undefined;
        if (isDataNode) {
            dataElements = try std.ArrayList(DataNode).initCapacity(allocator, MAX_DATA_NODE_SIZE);
        } else {
            indexElements = try std.ArrayList(IndexNode).initCapacity(allocator, MAX_INDEX_NODE_SIZE);
        }
        return .{
            .m_isDataNode = isDataNode,
            .m_indexElements = indexElements,
            .m_dataElements = dataElements,
        };
    }

    pub fn initWithChild(child: Self, allocator: Allocator) !Node {
        const dataElements: std.ArrayList(DataNode) = undefined;
        var indexElements = try std.ArrayList(IndexNode).initCapacity(allocator, MAX_INDEX_NODE_SIZE);
        try indexElements.append(IndexNode.initWithFullKeyRange(child));
        return .{
            .m_isDataNode = false,
            .m_indexElements = indexElements,
            .m_dataElements = dataElements,
        };
    }

    pub fn deinit(self: Self) void {
        if (self.m_isDataNode) {
            for (0..self.m_dataElements.items.len) |i| {
                self.m_dataElements.items[i].deinit();
            }
            self.m_dataElements.deinit();
        } else {
            for (0..self.m_indexElements.items.len) |i| {
                self.m_indexElements.items[i].deinit();
            }
            self.m_indexElements.deinit();
        }
    }

    fn moveElements(self: *Self, other: *Self, startIndexInclusive: usize, endIndexExclusive: usize) !void {
        if (self.m_isDataNode != other.m_isDataNode) {
            return BPlusTreeError.INVALID_ARGS;
        }

        if (self.m_isDataNode) {
            for (startIndexInclusive..endIndexExclusive) |_| {
                const elementToMove = other.m_dataElements.orderedRemove(startIndexInclusive);
                self.m_dataElements.appendAssumeCapacity(elementToMove);
            }
        } else {
            for (startIndexInclusive..endIndexExclusive) |_| {
                const elementToMove = other.m_indexElements.orderedRemove(startIndexInclusive);
                self.m_indexElements.appendAssumeCapacity(elementToMove);
            }
        }
    }

    fn getKeyAtIndex(self: Self, index: usize) !DataNode {
        if (self.getSize() <= index) {
            return BPlusTreeError.INVALID_ARGS;
        }

        if (self.m_isDataNode) {
            return self.m_dataElements.items[index];
        } else {
            return self.m_indexElements.items[index].getKeyLow();
        }
    }

    fn getSize(self: Self) usize {
        var len: usize = 0;
        if (self.m_isDataNode) {
            len = self.m_dataElements.items.len;
        } else {
            len = self.m_indexElements.items.len;
        }

        return len;
    }

    fn getCapacity(self: Self) usize {
        var len: usize = 0;
        if (self.m_isDataNode) {
            len = self.m_dataElements.capacity;
        } else {
            len = self.m_indexElements.capacity;
        }

        return len;
    }

    fn isFull(self: Self) bool {
        return self.getSize() >= self.getCapacity();
    }

    fn getSplitKeyIndex(self: Self) usize {
        const len: usize = self.getSize();
        return len / 2;
    }

    fn split(self: *Self, index: usize, allocator: Allocator) !void {
        if (self.m_isDataNode) {
            return BPlusTreeError.INVALID_ARGS;
        }
        if (index > MAX_INDEX_NODE_SIZE) {
            return BPlusTreeError.INVALID_ARGS;
        }
        if (self.isFull()) {
            return BPlusTreeError.NODE_FULL;
        }

        var childToSplit: IndexNode = self.m_indexElements.items[index];
        const splitKeyIndex = childToSplit.getChild().getSplitKeyIndex();
        const splitKeyLow = try childToSplit.getChild().getKeyAtIndex(splitKeyIndex);
        const childNode = childToSplit.getChild();

        var lChild = try Node.init(childToSplit.getChild().m_isDataNode, allocator);
        try lChild.moveElements(childNode, 0, splitKeyIndex);
        const lElement = try IndexNode.init(childToSplit.getKeyLow(), splitKeyLow, lChild);

        var rChild = try Node.init(childToSplit.m_child.m_isDataNode, allocator);
        try rChild.moveElements(childNode, 0, childToSplit.getChild().getSize());
        const rElement = try IndexNode.init(splitKeyLow, childToSplit.getKeyHigh(), rChild);

        var newChildSplice = [2]IndexNode{ lElement, rElement };
        try self.m_indexElements.replaceRange(index, 1, &newChildSplice);
    }

    pub fn get(self: Node, key: DataNode, allocator: Allocator) anyerror![]const u8 {
        if (self.m_isDataNode) {
            for (self.m_dataElements.items) |element| {
                const compKey = try element.compareKey(key);
                if (compKey == 0) {
                    return try element.toString(allocator);
                }
                if (compKey > 0) {
                    continue;
                }
                break;
            }
            return BPlusTreeError.KEY_NOT_FOUND;
        } else {
            for (self.m_indexElements.items) |element| {
                if (element.isKeyInRange(key)) {
                    return element.m_child.get(key, allocator);
                }
            }
            return BPlusTreeError.KEY_NOT_FOUND;
        }
    }

    pub fn visualizeRoot(self: Node, allocator: Allocator, nested: bool) !void {
        var attributes = try AttributeList.initCapacity(allocator, 1);
        try attributes.append(try Attribute.initString("(*)", allocator));
        const parentElement = try DataNode.init(attributes);

        try self.visualize(parentElement, 0, allocator, nested);
    }

    pub fn visualize(self: Node, parentKey: DataNode, depth: usize, allocator: Allocator, nested: bool) !void {
        if (self.m_isDataNode) {
            for (self.m_dataElements.items) |value| {
                std.debug.print("[{}] {s} => {s}\n", .{
                    depth,
                    try parentKey.toString(allocator),
                    try value.toString(allocator),
                });
            }
        } else {
            for (self.m_indexElements.items) |value| {
                std.debug.print("[{}] {s} => {s}..{s}\n", .{
                    depth,
                    try parentKey.toString(allocator),
                    try value.getKeyLow().toString(allocator),
                    try value.getKeyHigh().toString(allocator),
                });
            }

            if (nested) {
                for (self.m_indexElements.items) |value| {
                    const childParent = value.getKeyLow();
                    try value.m_child.visualize(childParent, depth + 1, allocator, nested);
                }
            }
        }
        return;
    }

    pub fn insert(self: *Node, element: DataNode, allocator: Allocator) anyerror!void {
        if (self.m_isDataNode) {
            if (self.isFull()) {
                return BPlusTreeError.NODE_FULL;
            }

            var indexToInsert: usize = self.m_dataElements.items.len;
            for (self.m_dataElements.items, 0..) |item, i| {
                const keyComp = try item.compareKey(element);
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

            try self.m_dataElements.insert(indexToInsert, element);
            return;
        }

        if (self.m_isDataNode) {
            unreachable;
        }

        if (self.m_indexElements.items.len == 0) {
            unreachable;
        }

        var childIndexToInsert: usize = 0;

        for (self.m_indexElements.items, 0..) |indexElement, i| {
            if (indexElement.isKeyInRange(element)) {
                childIndexToInsert = i;
                break;
            }
        }

        if (self.m_indexElements.items.len == childIndexToInsert) {
            unreachable;
        }

        self.m_indexElements.items[childIndexToInsert].getChild().insert(element, allocator) catch |err| switch (err) {
            BPlusTreeError.NODE_FULL => {
                if (self.isFull()) {
                    return BPlusTreeError.NODE_FULL;
                } else {
                    try self.split(childIndexToInsert, allocator);
                    return try self.insert(element, allocator);
                }
            },
            else => return err,
        };
    }
};
