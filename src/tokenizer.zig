const std = @import("std");
const log = std.log.scoped(.tokenizer);
const eql = std.mem.eql;

const Token = union(enum) {
    DOT,
    SEMICOLON,
    COLON,
    EQUALS,
    STRING: []const u8,
};

const Errors = error{TokenizeError};

pub fn tokenize(content: []const u8, allocator: std.mem.Allocator) ![]Token {
    // log.info("Content: {s}", .{content});

    var arr = std.ArrayList(Token).init(allocator);
    defer arr.deinit();

    var pos: usize = 0;

    while (pos < content.len) {
        const value = content[pos];

        switch (value) {
            '.' => {
                try arr.append(Token.DOT);
            },
            ';' => {
                try arr.append(Token.SEMICOLON);
            },
            ':' => {
                try arr.append(Token.COLON);
            },
            '=' => {
                try arr.append(Token.EQUALS);
            },
            '\'', '"' => {
                const str = try readString(allocator, &content, &pos, content[pos]);
                try arr.append(Token{ .STRING = str });
            },
            else => {
                // return Errors.TokenizeError;
            },
        }

        pos += 1;
        // log.info("{c}", .{value});
    }

    // try arr.append(.{ .type = "" });
    // try arr.append(.{ .type = "" });
    //

    for (arr.items) |token| {
        log.info("Token Type: '{?}'.", .{token});
    }

    return arr.items;
}

fn readString(allocator: std.mem.Allocator, content: *const []const u8, pos: *usize, del: u8) ![]const u8 {
    const start = pos.* + 1;
    var len: usize = 0;
    while (pos.* < content.len) {
        pos.* += 1;
        if (content.*[pos.*] == del) {
            break;
        }
        len += 1;
    }

    const str = try allocator.alloc(u8, len);
    std.mem.copyForwards(u8, str, content.*[start .. start + len]);

    return str;
}
