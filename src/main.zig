const std = @import("std");

const Io = std.Io;
const testing = std.testing;
const mem = std.mem;


const Error = error { WrongArgument };
const stdin_buf_size = 64;

// only works with -l (lines) for now otherwise exit 1
// Reads stdin
// 
pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    var l_flag = false;
    const args = try init.minimal.args.toSlice(arena);

    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
        if (mem.eql(u8, arg, "-l")) {
            l_flag = true;
        }
    }

    if (!l_flag) {
        return Error.WrongArgument;
    }


    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    var stdin_buffer: [stdin_buf_size]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;

    var str: [stdin_buf_size]u8 = undefined;
    var result: u64 = 0;

    while (true) {
        const size = try stdin_reader.readSliceShort(&str);

        result += countLines(&str, size);

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

    try stdout_writer.print("{d}\n", .{result});

    try stdout_writer.flush(); // Don't forget to flush!
}

fn countLines(buf:[]const u8, size: usize) u8 {
    var i: u8 = 0;
    var n: u8 = 0;
    while (i < size) : (i+=1) {
        if (buf[i] == '\n') n+=1; 
    }
    return n;
}

test "countLines" {
    // base cases
    try testing.expect(countLines("Line1\nLine2\n", 12) == 2);
    try testing.expect(countLines("Line1\nLine2", 11) == 1);
    try testing.expect(countLines("Line1", 5) == 0);

    // leftover garbage not considered
    try testing.expect(countLines("Line1\nIsabcd\n", 8) == 1);
}
