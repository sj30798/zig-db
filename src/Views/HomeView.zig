const std = @import("std");
const HtmlElements = @import("../HtmlElements/Elements.zig");

pub fn homeView() ![]const u8 {
    var bodyParagraph = HtmlElements.Paragraph{
        .content = "Zig key-value database is running!",
    };

    const homeBodyDivElement = HtmlElements.DivElement{
        .content = &bodyParagraph.baseHttpElement,
    };

    var homeBodySlice = [_]HtmlElements.DivElement{homeBodyDivElement};

    var homeHtml = HtmlElements.HttpElement{
        .head = .{
            .title = .{
                .value = "Zig key-value database",
            },
        },
        .body = .{
            .content = &homeBodySlice,
        },
    };

    return try homeHtml.baseHttpElement.toHttpString();
}
