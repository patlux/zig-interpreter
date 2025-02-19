const std = @import("std");
const log = std.log.scoped(.tokenizer);
const eql = std.mem.eql;

const Token = union(enum) {
    DOT,
    SEMICOLON,
    COLON,
    EQUALS,
    STRING: []const u8,
    EOF,
};

const Errors = error{TokenizeError};

pub const Tokenizer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    content: []const u8,

    start: usize,
    current: usize,

    tokens: std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator, content: []const u8) Self {
        return Tokenizer{
            .allocator = allocator,
            .content = content,
            .start = 0,
            .current = 0,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    fn isAtEnd(self: *Self) bool {
        return self.current >= self.content.len;
    }

    fn advance(self: *Self) u8 {
        const value = self.content[self.current];
        self.current += 1;
        return value;
    }

    fn peek(self: *Self) u8 {
        return self.content[self.current];
    }

    fn peekNext(self: *Self) u8 {
        return self.content[self.current + 1];
    }

    fn addToken(self: *Self, token: Token) !void {
        try self.tokens.append(token);
    }

    pub fn tokenize(self: *Self) !void {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.addToken(.EOF);

        for (self.tokens.items) |token| {
            log.info("Token Type: '{?}'.", .{token});
        }
    }

    fn scanToken(self: *Self) !void {
        const value = self.advance();
        switch (value) {
            '.' => try self.addToken(.DOT),
            ';' => try self.addToken(.SEMICOLON),
            ':' => try self.addToken(.COLON),
            '=' => try self.addToken(.EQUALS),
            '\'', '"' => {
                while (self.advance() != value) {}
                const len = self.current - self.start - 2; // -2 -> ""
                const str = try self.allocator.alloc(u8, len);
                std.mem.copyForwards(u8, str, self.content[self.start + 1 .. self.current - 1]);
                try self.addToken(Token{ .STRING = str });
            },
            else => {
                return Errors.TokenizeError;
            },
        }
    }
};
