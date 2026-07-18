//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;
const testing = std.testing;

// bytes lines words
pub const Count = packed struct { bytes: u64, lines: u64, words: u64 };

pub fn count(buf: []const u8, word_reset: *bool, size: usize) Count {
    var i: usize = 0;
    var lines: u64 = 0;
    var words: u64 = 0;
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

    return .{ .bytes = size, .lines = lines, .words = words };
}

const EchoOut = struct { []const u8, *bool, usize };

var echo_word_reset = true;

fn echo(comptime text: []const u8) EchoOut {
    const buf: []const u8 = text ++ "\n";
    echo_word_reset = true;
    return .{ buf, &echo_word_reset, buf.len };
}

test "count" {
    try testing.expectEqual(Count{ .bytes = 12, .lines = 2, .words = 2 }, @call(.auto, count, echo("Line1\nLine2")));

    try testing.expectEqual(Count{ .bytes = 11, .lines = 1, .words = 1 }, @call(.auto, count, echo("Line1Line2")));
}

// wc -l counts the number of newline bytes.
test "lines" {
    std.debug.print("Lines tests:\n", .{});
    try testing.expectEqual(2, @call(.auto, count, echo("Line1\nLine2")).lines); // "Line1\nLine2\n"
    try testing.expectEqual(3, @call(.auto, count, echo("a\nb\nc")).lines); // "a\nb\nc\n"
    try testing.expectEqual(1, @call(.auto, count, echo("single line")).lines); // trailing \n only
    try testing.expectEqual(1, @call(.auto, count, echo("")).lines); // "\n"
}

// wc -w counts maximal runs of non-whitespace, so runs of spaces collapse.
test "words" {
    std.debug.print("Words tests:\n", .{});
    try testing.expectEqual(2, @call(.auto, count, echo("hello world")).words);
    try testing.expectEqual(4, @call(.auto, count, echo("one two three four")).words);
    try testing.expectEqual(1, @call(.auto, count, echo("single")).words);
    try testing.expectEqual(2, @call(.auto, count, echo("Line1\nLine2")).words);
    try testing.expectEqual(3, @call(.auto, count, echo("a  b  c")).words); // collapsed double spaces
    try testing.expectEqual(0, @call(.auto, count, echo("")).words); // "\n" has no words
}

// wc -c counts total bytes, including the newline echo appends.
test "bytes" {
    std.debug.print("Bytes tests:\n", .{});
    try testing.expectEqual(6, @call(.auto, count, echo("hello")).bytes); // "hello\n"
    try testing.expectEqual(12, @call(.auto, count, echo("Line1\nLine2")).bytes);
    try testing.expectEqual(8, @call(.auto, count, echo("a  b  c")).bytes); // "a  b  c\n"
    try testing.expectEqual(1, @call(.auto, count, echo("")).bytes); // "\n"
}
