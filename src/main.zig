const std = @import("std");
const log = std.log.scoped(.main);
const Tokenizer = @import("./tokenizer.zig").Tokenizer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const file_content = try readFile("test.ts", allocator);
    defer allocator.free(file_content);

    var tokenizer = try Tokenizer.init(
        arena.allocator(),
        file_content,
    );
    try tokenizer.tokenize();

    for (tokenizer.tokens.items) |token| {
        log.info("Token Type: '{?}'.", .{token});
    }
    log.info("Found tokens: {d}", .{tokenizer.tokens.items.len});
}

fn readFile(file_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const length = try file.getEndPos();
    const buffer = try allocator.alloc(u8, length);

    _ = try file.readAll(buffer);

    return buffer;
}
