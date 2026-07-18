# wc-zig

A small `wc` clone written in Zig, for learning. Counts lines, words, and bytes
from stdin (ASCII/byte-oriented — no multibyte/Unicode handling).

## Build & run

```sh
zig build -Doptimize=ReleaseFast
./zig-out/bin/wc_zig            < file.txt   # lines, words, bytes
./zig-out/bin/wc_zig -l         < file.txt   # lines only
./zig-out/bin/wc_zig -lw        < file.txt   # lines + words
```

Flags: `-l` lines, `-w` words, `-c` bytes (combine like `-lw`). No flags = all three.
Input is read from stdin only.

## Test

```sh
zig test src/root.zig
```

## Performance

Competitive with GNU `wc`; see [BENCHMARKS.md](BENCHMARKS.md).
