const std = @import("std");
const log = std.log.scoped(.tokenizer);
const eql = std.mem.eql;

const Token = union(enum) {
    DOT,
    SEMICOLON,
    COLON,
    EQUALS,
    LEFT_PAREN,
    RIGHT_PAREN,
    SLASH,
    STRING: []const u8,
    IDENTIFIER: []const u8,
    KEYWORD,
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
        const value = self.peek();
        log.debug("advance: '{c}'", .{value});
        self.current += 1;
        return value;
    }

    fn peek(self: *Self) u8 {
        if (self.isAtEnd()) return 0;
        return self.content[self.current];
    }

    fn peekNext(self: *Self) u8 {
        return self.content[self.current + 1];
    }

    fn match(self: *Self, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.peek() != expected) return false;

        self.current += 1;
        return true;
    }

    fn addToken(self: *Self, token: Token) !void {
        switch (token) {
            .IDENTIFIER => {
                log.debug("Add token identifier: '{s}'.", .{token.IDENTIFIER});
            },
            .STRING => {
                log.debug("Add token string: '{s}'.", .{token.STRING});
            },
            else => {},
        }

        try self.tokens.append(token);
    }

    pub fn tokenize(self: *Self) !void {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.addToken(.EOF);
    }

    fn scanToken(self: *Self) !void {
        const value = self.advance();
        log.debug("- '{c}'", .{value});
        switch (value) {
            0, '\n' => {
                return;
            },
            '.' => try self.addToken(.DOT),
            ';' => try self.addToken(.SEMICOLON),
            ':' => try self.addToken(.COLON),
            '=' => try self.addToken(.EQUALS),
            '(' => try self.addToken(.LEFT_PAREN),
            ')' => try self.addToken(.RIGHT_PAREN),
            '/' => {
                // ignore // comments
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                } else {
                    try self.addToken(.SLASH);
                }
            },
            '\'', '"' => {
                while (self.peek() != value and !self.isAtEnd()) {
                    _ = self.advance();
                }
                const len = self.current - self.start;
                const str = try self.allocator.alloc(u8, len);
                std.mem.copyForwards(
                    u8,
                    str,
                    self.content[self.start + 1 .. self.current],
                );
                try self.addToken(Token{ .STRING = str });
                _ = self.advance();
            },
            else => {
                // Keywords etc.
                if (std.ascii.isAlphabetic(value)) {
                    while (std.ascii.isAlphabetic(self.peek())) {
                        _ = self.advance();
                    }
                    const end = self.current;
                    const len = end - self.start;
                    const str = try self.allocator.alloc(u8, len);
                    std.mem.copyForwards(u8, str, self.content[self.start..end]);
                    log.debug("str: '{s}'", .{str});
                    try self.addToken(Token{ .IDENTIFIER = str });
                    return;
                }
                return Errors.TokenizeError;
            },
        }
    }
};
