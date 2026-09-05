This is a personal vault of a bunch of smaller exercises that I do to learn about a bunch of different concepts. Never saw all this in one place, and thought it would be helpful to others :) As such, this will not be the cleanest but I hope that can be forgiven.

## Exercises

### `async_fifo/`
A dual-clock (asynchronous) FIFO: 16-deep, 8-bit words, independent `wr_clk`/`rd_clk` domains. Pointers are passed across the clock-domain crossing in Gray code through two-flop synchronizers, with `norm_to_gray`/`gray_to_norm` helpers, and `full`/`empty` derived from the synchronized pointers. Comes with a self-checking testbench.

### `skid_buffer/`
A pipeline skid buffer for a `valid`/`ready` stream: fully registered outputs so there is no combinational path from `out_ready` back to `in_ready`. Built as a 3-state FSM (empty / one beat / full) over a main output register plus a one-entry skid register that catches the in-flight beat when the downstream stalls. `skid_buffer_tb.v` is a self-checking testbench with a reference-FIFO scoreboard, handshake-stability checks, a full-throughput check, and randomized back-pressure.
