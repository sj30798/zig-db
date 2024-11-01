const std = @import("std");
const expect = std.testing.expect;

pub fn trim(string: []const u8, value_to_strip: []const u8) []const u8 {
    return std.mem.trim(u8, string, value_to_strip);
}

pub fn split(string: []const u8, delimiter: []const u8) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(std.heap.page_allocator);

    var splittedStringIterator = std.mem.split(u8, string, delimiter);
    while (splittedStringIterator.next()) |nextSplit| {
        try result.append(nextSplit);
    }

    return result.items;
}

pub fn isNullOrEmpty(string: []const u8) bool {
    return string.len == 0;
}

pub fn getLength(string: []const u8) usize {
    return string.len;
}

pub fn equal(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right);
}

pub fn charAt(string: []const u8, index: u8) ?u8 {
    if (getLength(string) > index) {
        return string[index];
    }

    return null;
}

test "String trim" {
    const string = "ABCD";

    try expect(equal(trim(string, "A"), "BCD"));
    try expect(equal(trim(string, "D"), "ABC"));
    try expect(equal(trim(string, "B"), "ABCD"));
    try expect(equal(trim("ACBA", "A"), "CB"));
}

test "String isNullOrEmpty" {
    const string = "ABCD";

    try expect(!isNullOrEmpty(string));
    try expect(isNullOrEmpty(""));
}

test "String getLength" {
    const string = "ABCD";

    try expect(getLength(string) == 4);
}

test "String charAt" {
    const string = "ABCD";

    const char = charAt(string, 1);
    try expect(char != null);
    try expect(char.? == 'B');
}

test "String charAt invalid index" {
    const string = "ABCD";

    const char = charAt(string, 4);
    try expect(char == null);
}

test "String equal test" {
    const string = "ABCD";

    try expect(equal(string, "ABCD"));
}

test "String split test" {
    const delimitedString = "A||ABC||||DEF";
    const splittedString = try split(delimitedString, "||");

    try expect(splittedString.len == 4);
    try expect(equal(splittedString[0], "A"));
    try expect(equal(splittedString[1], "ABC"));
    try expect(equal(splittedString[2], ""));
    try expect(equal(splittedString[3], "DEF"));
}
