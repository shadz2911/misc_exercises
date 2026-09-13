This is a personal vault of a bunch of smaller exercises that I do to learn about a bunch of different concepts. Never saw all this in one place, and thought it would be helpful to others :) As such, this will not be the cleanest but I hope that can be forgiven.

## Exercises

### `async_fifo/`
A dual-clock (asynchronous) FIFO: 16-deep, 8-bit words, independent `wr_clk`/`rd_clk` domains. Pointers are passed across the clock-domain crossing in Gray code through two-flop synchronizers, with `norm_to_gray`/`gray_to_norm` helpers, and `full`/`empty` derived from the synchronized pointers. Comes with a self-checking testbench.

### `skid_buffer/`
A pipeline skid buffer for a `valid`/`ready` stream: fully registered outputs so there is no combinational path from `out_ready` back to `in_ready`. Built as a 3-state FSM (empty / one beat / full) over a main output register plus a one-entry skid register that catches the in-flight beat when the downstream stalls. `skid_buffer_tb.v` is a self-checking testbench with a reference-FIFO scoreboard, handshake-stability checks, a full-throughput check, and randomized back-pressure.

### `divide_by_3_clk/`
A duty-cycle-correct divide-by-3 clock divider: two mod-3 counters, one advancing on `posedge clk` and one on `negedge clk`, ORed together so the output stays high for 3 of the 6 half-cycles instead of the lopsided 2-of-3 duty cycle a single-edge counter gives.

### `round_robin_arbiter/`
A 4-channel round-robin arbiter: a registered priority pointer picks the first requester at or after itself, grants exactly that one line, and advances the pointer past it so every channel gets a fair turn under contention. `round_robin_arbiter_tb.v` is a self-checking testbench with a reference model, one-hot/starvation/fairness checks on every cycle, and directed plus randomized request patterns.

### `glitch_free_clock_mux/`
A 2:1 glitch-free clock mux for switching between two unrelated, asynchronous clocks without ever producing a runt pulse on the output: each clock domain has its own 2-flop synchronizer (gated by the *other* domain's synced select, so both can never be granted at once) that only ever updates while its own clock is low, so a switch never truncates a clock pulse mid-cycle. `glitch_free_clock_mux_tb.v` is a self-checking, whitebox testbench that continuously checks mutual exclusion of the two synced selects and validates every output edge's spacing against the source clock's half-period (a mismatch means a glitch), on top of directed passthrough/switch/reset-mid-switch scenarios and randomized async ping-pong switching.
