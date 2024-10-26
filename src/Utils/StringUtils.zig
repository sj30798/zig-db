const std = @import("std");

pub const StringUtils = struct {
    pub fn trim(string: []const u8, value_to_strip: []const u8) []const u8 {
        return std.mem.trim(u8, string, value_to_strip);
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
        if (getLength(string) < index) {
            return string[index];
        }

        return null;
    }
};
