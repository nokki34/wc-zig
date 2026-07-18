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
- [x] Widen `count`'s `size` (and internal `i`/`lines`/`words`) beyond `u8`, raise
  `stdin_buf_size` to e.g. 64 KiB, re-measure. Expectation: system time collapses,
  end-to-end approaches the micro-benchmark throughput. → see next section.

### 2026-07-19 — widen size to usize + 64 KiB buffer

Same machine/Zig/baseline as above.

**Change**
- `src/root.zig`: `count(..., size: usize)`; internal `i: usize`, `lines`/`words: u64`
  (the `u8` counters would have overflowed on a 64 KiB chunk).
- `src/main.zig`: `stdin_buf_size = 64 * 1024`; dropped `@truncate(size)`.

**End-to-end vs `wc` (64 MiB file, `-l`)** — correctness re-verified equal
(1,525,201 lines / 13,726,813 words / 67,108,864 bytes)

| Program | Total time (best of 5) | user / system | Throughput |
|---|---|---|---|
| `wc_zig -l` (64 B buffer, prev) | 0.101 s | 0.06 / 0.04 s | ~0.63 GiB/s |
| `wc_zig -l` (64 KiB buffer) | **0.047 s** | 0.04 / **0.00** s | ~1.36 GiB/s |
| GNU `wc -l` | 0.004 s | 0.00 / 0.00 s | ~16 GiB/s |

**Result: ~2.2× faster end-to-end.** The hypothesis held — **system time went 0.04 s → 0.00 s**:
the ~1M `read()` syscalls are gone (now ~1000 reads of 64 KiB). Micro-benchmark unchanged
(~1.75 GiB/s), confirming the win was I/O, not the loop.

**New bottleneck: the counting loop itself.** `wc_zig`'s time is now ~100% user, at ~1.4 GiB/s,
matching the micro-benchmark. Still ~12× slower than GNU `wc` **on the `-l`-only path**. Why:
- GNU `wc -l` counts newlines with SIMD `memchr` and skips the word state machine entirely.
- `wc_zig` always runs the full per-byte loop (newline + whitespace + word-state) even for `-l`.

**But all-three is a different story.** Comparing full counts (64 MiB, correctness equal:
1,525,201 / 13,726,813 / 67,108,864):

| Program | Total time (best of 5) | Throughput |
|---|---|---|
| `wc_zig` (l+w+c) | **0.047 s** | ~1.36 GiB/s |
| GNU `wc -lwc` | 0.052 s | ~1.23 GiB/s |

**`wc_zig` is ~10% *faster* than GNU `wc` at all three counts.** The 12× gap only exists for
`-l` alone, because that's the one case GNU `wc` special-cases (memchr, no word work). Once
words are required, GNU `wc` runs a per-byte state machine too — and ours is slightly faster.

**Takeaway:** the all-3 path is already at/above parity; no gap to close there. The only real
opportunity left is the `-l`-only fast path.

**Next lever (optional)**
- [ ] Specialize `-l`-only: count newlines with a vectorized/`@Vector` scan (memchr-style)
  instead of the per-byte state machine. Only helps the lines-only path — all-3 already wins.
