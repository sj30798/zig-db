const std = @import("std");

pub const BaseHttpElement = struct {
    toHttpStringFn: *const fn (*BaseHttpElement) anyerror![]const u8,

    pub fn toHttpString(iBaseHttpElement: *BaseHttpElement) ![]const u8 {
        return iBaseHttpElement.toHttpStringFn(iBaseHttpElement);
    }
};

pub const Title = struct {
    value: ?[]const u8 = null,

    baseHttpElement: BaseHttpElement = .{
        .toHttpStringFn = toHttpString,
    },

    fn toHttpString(iBaseHttpElement: *BaseHttpElement) anyerror![]const u8 {
        const self = @as(*Title, @fieldParentPtr("baseHttpElement", iBaseHttpElement));

        if (self.value) |titleValue| {
            return try std.fmt.allocPrint(std.heap.page_allocator, "<title>{s}</title>", .{titleValue});
        } else {
            return "";
        }
    }
};

pub const Head = struct {
    title: ?Title = null,

    baseHttpElement: BaseHttpElement = .{
        .toHttpStringFn = toHttpString,
    },

    fn toHttpString(iBaseHttpElement: *BaseHttpElement) anyerror![]const u8 {
        const self = @as(*Head, @fieldParentPtr("baseHttpElement", iBaseHttpElement));

        const titleString = if (self.title) |_|
            try self.title.?.baseHttpElement.toHttpString()
        else
            "";

        return try std.fmt.allocPrint(std.heap.page_allocator, "<head>{s}</head>", .{titleString});
    }
};

pub const Paragraph = struct {
    content: ?[]const u8 = null,

    baseHttpElement: BaseHttpElement = .{
        .toHttpStringFn = toHttpString,
    },

    fn toHttpString(iBaseHttpElement: *BaseHttpElement) anyerror![]const u8 {
        const self = @as(*Paragraph, @fieldParentPtr("baseHttpElement", iBaseHttpElement));

        const contentString = if (self.content) |content|
            content
        else
            "";

        return try std.fmt.allocPrint(std.heap.page_allocator, "<p>{s}</p>", .{contentString});
    }
};

pub const ButtonElement = struct {
    text: []const u8 = "",

    baseHttpElement: BaseHttpElement = .{
        .toHttpStringFn = toHttpString,
    },

    fn toHttpString(iBaseHttpElement: *BaseHttpElement) anyerror![]const u8 {
        const self = @as(*ButtonElement, @fieldParentPtr("baseHttpElement", iBaseHttpElement));

        return try std.fmt.allocPrint(std.heap.page_allocator, "<button type=\\\"button\\\">{s}</button>", .{self.text});
    }
};

pub const DivElement = struct {
    content: ?*BaseHttpElement = null,

    baseHttpElement: BaseHttpElement = .{
        .toHttpStringFn = toHttpString,
    },

    fn toHttpString(iBaseHttpElement: *BaseHttpElement) anyerror![]const u8 {
        const self = @as(*DivElement, @fieldParentPtr("baseHttpElement", iBaseHttpElement));

        if (self.content) |_| {
            return std.fmt.allocPrint(std.heap.page_allocator, "<div>{s}</div", .{try self.content.?.toHttpString()});
        } else {
            return "<div></div>";
        }
    }
};

pub const Body = struct {
    content: ?[]DivElement = null,

    baseHttpElement: BaseHttpElement = .{
        .toHttpStringFn = toHttpString,
    },

    fn toHttpString(iBaseHttpElement: *BaseHttpElement) anyerror![]const u8 {
        const self = @as(*Body, @fieldParentPtr("baseHttpElement", iBaseHttpElement));

        var bodyContent = std.ArrayList(u8).init(std.heap.page_allocator);

        if (self.content) |_| {
            for (0..self.content.?.len) |index| {
                var paragraph = self.content.?[index];
                try bodyContent.appendSlice(try paragraph.baseHttpElement.toHttpString());
            }
        }

        return try std.fmt.allocPrint(std.heap.page_allocator, "<body>{s}</body>", .{bodyContent.items});
    }
};

pub const HttpElement = struct {
    head: ?Head = null,
    body: ?Body = null,

    baseHttpElement: BaseHttpElement = .{
        .toHttpStringFn = toHttpString,
    },

    fn toHttpString(iBaseHttpElement: *BaseHttpElement) anyerror![]const u8 {
        const self = @as(*HttpElement, @fieldParentPtr("baseHttpElement", iBaseHttpElement));

        const headString = if (self.head) |_|
            try self.head.?.baseHttpElement.toHttpString()
        else
            "";

        const bodyString = if (self.body) |_|
            try self.body.?.baseHttpElement.toHttpString()
        else
            "";

        return try std.fmt.allocPrint(std.heap.page_allocator, "<html>{s}{s}</html>", .{ headString, bodyString });
    }
};
