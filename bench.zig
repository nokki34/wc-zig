// Microbenchmark for `count`, timed externally (this Zig dev build has no std.time.Timer).
// Build+run in ReleaseFast and wrap with shell `time`:
//   zig run -O ReleaseFast bench.zig
const std = @import("std");
const counter = @import("src/root.zig");

// Mimic main.zig: walk the buffer in `chunk`-sized pieces, threading word_reset.
fn countAll(buf: []const u8, chunk: u8) counter.Count {
    var total = counter.Count{ .bytes = 0, .lines = 0, .words = 0 };
    var word_reset = true;
    var off: usize = 0;
    while (off < buf.len) : (off += chunk) {
        const n: u8 = @intCast(@min(@as(usize, chunk), buf.len - off));
        const c = counter.count(buf[off .. off + n], &word_reset, n);
        total.bytes += c.bytes;
        total.lines += c.lines;
        total.words += c.words;
    }
    return total;
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const size = 64 * 1024 * 1024; // 64 MiB per pass
    const iters = 8; // total work = size * iters
    const buf = try alloc.alloc(u8, size);
    defer alloc.free(buf);

    const pattern = "the quick brown fox jumps over the lazy dog\n";
    for (buf, 0..) |*b, i| b.* = pattern[i % pattern.len];

    var sink: u64 = 0;
    var it: usize = 0;
    while (it < iters) : (it += 1) {
        sink +%= countAll(buf, 64).words; // 64 = main.zig's chunk size
    }

    const total_mib = (size / (1024 * 1024)) * iters;
    std.debug.print("counted {d} MiB total (chunk=64)\nsink={d}\n", .{ total_mib, sink });
}
