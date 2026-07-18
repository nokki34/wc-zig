//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const testing = std.testing;

// bytes lines words
pub const Count = packed struct { bytes: u64, lines: u64, words: u64 };

pub fn count(buf: []const u8, word_reset: *bool, size: u8) Count {
    var i: u8 = 0;
    var lines: u8 = 0;
    var words: u8 = 0;
    while (i < size) : (i += 1) {
        if (buf[i] == '\n') {
            lines += 1;
        }
        if (std.ascii.isWhitespace(buf[i])) {
            word_reset.* = true;
        } else {
            if (word_reset.*) words += 1;
            word_reset.* = false;
        }
    }
    if (buf.len < size and word_reset.*) {
        words += 1;
    }

    return .{ .bytes = size, .lines = lines, .words = words };
}

const EchoOut = struct { []const u8, *bool, u8 };

fn echo(comptime text: []const u8) EchoOut {
    const buf: []const u8 = text ++ "\n";
    var word_reset = true;
    return .{ buf, &word_reset, @intCast(buf.len) };
}

test "count" {
    try testing.expectEqual(Count{ 12, 2, 2 }, @call(.auto, count, echo("Line1\nLine2")));

    try testing.expectEqual(Count{ 11, 1, 1 }, @call(.auto, count, echo("Line1Line2")));
}

// wc -l counts the number of newline bytes.
test "lines" {
    std.debug.print("Lines tests:\n", .{});
    try testing.expectEqual(2, @call(.auto, count, echo("Line1\nLine2"))[1]); // "Line1\nLine2\n"
    try testing.expectEqual(3, @call(.auto, count, echo("a\nb\nc"))[1]); // "a\nb\nc\n"
    try testing.expectEqual(1, @call(.auto, count, echo("single line"))[1]); // trailing \n only
    try testing.expectEqual(1, @call(.auto, count, echo(""))[1]); // "\n"
}

// wc -w counts maximal runs of non-whitespace, so runs of spaces collapse.
test "words" {
    std.debug.print("Words tests:\n", .{});
    try testing.expectEqual(2, @call(.auto, count, echo("hello world"))[2]);
    try testing.expectEqual(4, @call(.auto, count, echo("one two three four"))[2]);
    try testing.expectEqual(1, @call(.auto, count, echo("single"))[2]);
    try testing.expectEqual(2, @call(.auto, count, echo("Line1\nLine2"))[2]);
    try testing.expectEqual(3, @call(.auto, count, echo("a  b  c"))[2]); // collapsed double spaces
    try testing.expectEqual(0, @call(.auto, count, echo(""))[2]); // "\n" has no words
}

// wc -c counts total bytes, including the newline echo appends.
test "bytes" {
    std.debug.print("Bytes tests:\n", .{});
    try testing.expectEqual(6, @call(.auto, count, echo("hello"))[0]); // "hello\n"
    try testing.expectEqual(12, @call(.auto, count, echo("Line1\nLine2"))[0]);
    try testing.expectEqual(8, @call(.auto, count, echo("a  b  c"))[0]); // "a  b  c\n"
    try testing.expectEqual(1, @call(.auto, count, echo(""))[0]); // "\n"
}
