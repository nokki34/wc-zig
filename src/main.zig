const std = @import("std");
const counter = @import("wc_zig");

const Io = std.Io;
const testing = std.testing;
const mem = std.mem;

const Error = error{ WrongArgument, FileNotSupported };
const stdin_buf_size = 64;

// only works with -l (lines) for now otherwise exit 1
// Reads stdin
//
pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);

    const flags = try parseFlags(args);

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    var stdin_buffer: [stdin_buf_size]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;

    var str: [stdin_buf_size]u8 = undefined;
    var result: @Vector(3, u64) = .{ 0, 0, 0 };
    var word_reset = true;

    while (true) {
        const size = try stdin_reader.readSliceShort(&str);

        const counts = counter.count(&str, &word_reset, @truncate(size));

        result += @as(@Vector(3, u64), .{ counts.lines, counts.words, counts.bytes });

        if (size < stdin_buf_size) {
            break;
        }
    }

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [10]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try printResult(stdout_writer, result, flags);

    try stdout_writer.flush(); // Don't forget to flush!
}

const Flags = packed struct {
    l: bool = false, // lines,
    w: bool = false, // words
    c: bool = false, // bytes
};

fn parseFlags(args: []const [:0]const u8) Error!Flags {
    var flags = Flags{};
    for (args[1..]) |arg| {
        if (arg[0] != '-') {
            return Error.FileNotSupported;
        }
        for (arg) |char| {
            switch (char) {
                '-' => continue,
                'w' => flags.w = true,
                'c' => flags.c = true,
                'l' => flags.l = true,
                else => return Error.WrongArgument,
            }
        }
    }

    // if all false
    if (flags.w == false and flags.l == false and flags.c == false) {
        return Flags{ .w = true, .c = true, .l = true };
    }

    return flags;
}

fn printResult(writer: *std.Io.Writer, counts: [3]u64, flags: Flags) !void {
    const flags_arr: [3]u2 = .{ @intFromBool(flags.l), @intFromBool(flags.w), @intFromBool(flags.c) };
    const single = @reduce(.Add, @as(@Vector(3, u2), flags_arr)) == 1;

    var i: usize = 0;

    while (i < 3) : (i += 1) {
        if (!single) {
            try writer.writeByte('\t');
        }

        if (flags_arr[i] == 1) {
            try writer.print("{d}", .{counts[i]});
        }
    }
    try writer.writeByte('\n');
}
