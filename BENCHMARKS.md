# Benchmarks

Performance records for `wc_zig`. Append a new dated section for each run so we can
track regressions/improvements over time.

## How to reproduce

```bash
# 1. micro-benchmark: count() over an in-memory buffer, no I/O
zig build-exe -O ReleaseFast bench.zig -femit-bin=/tmp/bench && time /tmp/bench

# 2. end-to-end: real CLI vs system wc (more honest for a CLI)
zig build -Doptimize=ReleaseFast
yes "the quick brown fox jumps over the lazy dog" | head -c 67108864 > /tmp/big.txt
for i in $(seq 5); do { TIMEFORMAT='%R'; time ./zig-out/bin/wc_zig -l < /tmp/big.txt >/dev/null; } 2>&1; done
for i in $(seq 5); do { TIMEFORMAT='%R'; time wc -l < /tmp/big.txt >/dev/null; } 2>&1; done
```

Rules: always `ReleaseFast`; keep results live (bench.zig accumulates into `sink`) so the
optimizer can't delete the loop; take best-of-N; verify correctness against `wc` first.

---

## 2026-07-19

**Environment**
- CPU: AMD Ryzen 5 9600X (6 cores / 12 threads)
- Kernel: Linux 7.1.3-arch1-2
- Zig: 0.17.0-dev.1282+c0f9b51d8
- Baseline: GNU coreutils `wc` 9.11
- Build: `-O ReleaseFast`

**Config under test**
- `src/main.zig`: `stdin_buf_size = 64`
- `src/root.zig`: `count(buf, word_reset, size: u8)` — chunk size capped at 255 by the `u8`

**Micro-benchmark (`count`, in-memory, chunk=64)**

| Total counted | Time (user) | Throughput |
|---|---|---|
| 512 MiB (64 MiB × 8) | 0.29 s | **~1.75 GiB/s** |

**End-to-end vs `wc` (64 MiB file, `-l`)** — correctness verified equal (1,525,201 lines)

| Program | Total time (best of 5) | user / system | Throughput |
|---|---|---|---|
| `wc_zig -l` | 0.101 s | 0.06 / 0.04 s | ~0.63 GiB/s |
| GNU `wc -l` | 0.004 s | 0.00 / 0.00 s | ~16 GiB/s |

`wc_zig` is ~25× slower end-to-end.

**Analysis**
- The counting loop is *not* the bottleneck — 1.75 GiB/s in isolation.
- ~40% of `wc_zig`'s wall time is **system** time: the 64-byte `stdin_buf_size` forces
  ~1,048,576 `read()` syscalls for 64 MiB (64 MiB ÷ 64 B). GNU `wc` reads in large blocks
  → a few hundred syscalls.
- The 64-byte buffer can't simply be enlarged because `count`'s `size: u8` caps a chunk at
  255 bytes. Widening `size`/counters to `usize` would unlock large-block reads.

**Next lever**
- [ ] Widen `count`'s `size` (and internal `i`/`lines`/`words`) beyond `u8`, raise
  `stdin_buf_size` to e.g. 64 KiB, re-measure. Expectation: system time collapses,
  end-to-end approaches the micro-benchmark throughput.
