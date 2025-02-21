const std = @import("std");
const log = std.log.scoped(.tokenizer);
const eql = std.mem.eql;

const Token = union(enum) {
    DOT,
    SEMICOLON,
    COLON,
    EQUALS,
    EQUALS_EQUALS,
    LESS,
    LESS_EQUALS,
    GREATER,
    GREATER_EQUALS,
    BANG,
    BANG_EQUAL,
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACKET,
    RIGHT_BRACKET,
    SLASH,
    STRING: []const u8,
    IDENTIFIER: []const u8,
    INT: usize,
    FLOAT: f32,
    KEYWORD,
    EOF,
    IF,
    ELSE,
    RETURN,
    WHILE,
    VAR,
    CONST,
    TRUE,
    FALSE,
};

const Errors = error{TokenizeError};

pub const Tokenizer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    content: []const u8,

    start: usize,
    current: usize,

    tokens: std.ArrayList(Token),
    keywords: std.StringHashMap(Token),

    pub fn init(allocator: std.mem.Allocator, content: []const u8) !Self {
        var keywords = std.StringHashMap(Token).init(allocator);
        try keywords.put("if", .IF);
        try keywords.put("else", .ELSE);
        try keywords.put("return", .RETURN);
        try keywords.put("while", .WHILE);
        try keywords.put("var", .VAR);
        try keywords.put("const", .CONST);
        try keywords.put("true", .TRUE);
        try keywords.put("false", .FALSE);
        return Tokenizer{
            .allocator = allocator,
            .content = content,
            .start = 0,
            .current = 0,
            .tokens = std.ArrayList(Token).init(allocator),
            .keywords = keywords,
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
        // log.debug("advance: '{c}'", .{value});
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
            0, '\n', ' ', '\t', '\r' => {
                return;
            },
            '.' => try self.addToken(.DOT),
            ';' => try self.addToken(.SEMICOLON),
            ':' => try self.addToken(.COLON),
            '=' => {
                // ==
                if (self.match('=')) {
                    try self.addToken(.EQUALS_EQUALS);
                } else {
                    try self.addToken(.EQUALS);
                }
            },
            '<' => {
                if (self.match('=')) {
                    try self.addToken(.LESS_EQUALS);
                } else {
                    try self.addToken(.LESS);
                }
            },
            '>' => {
                if (self.match('=')) {
                    try self.addToken(.GREATER_EQUALS);
                } else {
                    try self.addToken(.GREATER);
                }
            },
            '(' => try self.addToken(.LEFT_PAREN),
            ')' => try self.addToken(.RIGHT_PAREN),
            '{' => try self.addToken(.LEFT_BRACKET),
            '}' => try self.addToken(.RIGHT_BRACKET),
            '!' => {
                // !=
                if (self.match('=')) {
                    try self.addToken(.BANG_EQUAL);
                } else {
                    try self.addToken(.BANG);
                }
            },
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

                    const token = self.keywords.get(str);
                    if (token) |t| {
                        try self.addToken(t);
                    } else {
                        try self.addToken(Token{ .IDENTIFIER = str });
                    }

                    return;
                }

                if (std.ascii.isDigit(value)) {
                    while (std.ascii.isDigit(self.peek())) {
                        _ = self.advance();
                    }

                    // e.g. 1.5
                    if (self.peek() == '.' and std.ascii.isDigit(self.peekNext())) {
                        _ = self.advance();
                        while (std.ascii.isDigit(self.peek())) {
                            _ = self.advance();
                        }
                    }

                    const end = self.current;
                    const len = end - self.start;
                    const str = try self.allocator.alloc(u8, len);
                    std.mem.copyForwards(u8, str, self.content[self.start..end]);

                    if (std.mem.containsAtLeast(u8, str, 1, ".")) {
                        const number = try std.fmt.parseFloat(f32, str);
                        try self.addToken(Token{ .FLOAT = number });
                        return;
                    } else {
                        const number = try std.fmt.parseInt(usize, str, 10);
                        try self.addToken(Token{ .INT = number });
                        return;
                    }
                }

                return Errors.TokenizeError;
            },
        }
    }
};
