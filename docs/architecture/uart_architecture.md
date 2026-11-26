# UART Transmitter and Receiver — Architecture Document

**Governing Specification:** `docs/specifications/uart_transmitter_and_receiver_project_specification.md`  
**Language:** Synthesizable SystemVerilog (`rtl/*.sv`)  
**Top Module:** `uart_top`

---

## 1. Module Hierarchy

```text
uart_top (CLK_FREQ, BAUD_RATE, OVERSAMPLE, ENABLE_LOOPBACK)
 ├── u_uart_tx : uart_tx (CLK_FREQ, BAUD_RATE, OVERSAMPLE)
 │    └── u_tx_baud_gen : uart_baud_gen (CLK_FREQ, BAUD_RATE, OVERSAMPLE=1)
 ├── loopback_en mux (when ENABLE_LOOPBACK == 1)
 └── u_uart_rx : uart_rx (CLK_FREQ, BAUD_RATE, OVERSAMPLE)
      └── u_rx_baud_gen : uart_baud_gen (CLK_FREQ, BAUD_RATE, OVERSAMPLE)
```

### Design Partitioning Rationale
Each `uart_tx` and `uart_rx` instantiates its own parameterized `uart_baud_gen` rather than sharing a single global free-running tick generator at `uart_top`:
1. **Standalone Testability:** Preserves the exact Spec §§3.2 and 3.3 port interfaces on `uart_tx` and `uart_rx` without extra external tick ports.
2. **TX Phase Alignment:** Resetting `u_tx_baud_gen` (`clr`) on `tx_valid && tx_ready` guarantees zero start-bit launch delay and prevents start-bit truncation relative to an asynchronous user handshake.
3. **RX Free-Running Oversampling:** `u_rx_baud_gen` runs continuously (`en=1'b1`, `clr=1'b0`) at `BAUD_RATE * OVERSAMPLE` to sample incoming asynchronous transitions.

---

## 2. External Interfaces

### 2.1 `uart_top`
Parameters: `CLK_FREQ = 50_000_000`, `BAUD_RATE = 115_200`, `OVERSAMPLE = 16`, `ENABLE_LOOPBACK = 1`.

| Port | Dir | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `loopback_en` | Input | 1 | `0`: external `rx_serial_in`; `1`: internal `tx_serial` (when `ENABLE_LOOPBACK == 1`) |
| `tx_data` | Input | 8 | Parallel transmit byte |
| `tx_valid` | Input | 1 | TX data valid |
| `tx_ready` | Output | 1 | TX ready to accept a byte |
| `tx_serial` | Output | 1 | UART serial output (always driven by `uart_tx`) |
| `rx_serial_in` | Input | 1 | External asynchronous RX serial input |
| `rx_data` | Output | 8 | Last successfully received byte |
| `rx_valid` | Output | 1 | 1-cycle valid byte pulse |
| `framing_error` | Output | 1 | 1-cycle bad stop-bit pulse |

### 2.2 `uart_baud_gen`
Parameters: `CLK_FREQ = 50_000_000`, `BAUD_RATE = 115_200`, `OVERSAMPLE = 16`.
Ports: `clk` (in), `rst_n` (in), `en` (in), `clr` (in), `tick` (out, 1-cycle synchronous clock enable).

---

## 3. Baud-Rate Timing Architecture (`uart_baud_gen`)

### 3.1 Integer Division vs. Fractional Accumulator Trade-Off
For `CLK_FREQ = 50_000_000`, `BAUD_RATE = 115_200`, `OVERSAMPLE = 16`:
- **Integer 16x Divider (`DIV = 27`, TX `÷16` = 432 clks/bit):** Yields `115,740.74 bps` (`+0.4694%` error) and degrades rapidly at higher baud rates (e.g., `+13.0%` at `921,600` baud).
- **Separate Integer 1x TX Divider (`DIV = 434`):** Yields `115,207.37 bps` (`+0.0064%` error), still subject to quantization error at non-divisible high baud rates.
- **GCD-Reduced Modulo-`CLK_FREQ` Bresenham Accumulator (Selected):**
  - Computes `TARGET_FREQ_U = 64'(BAUD_RATE) * 64'(OVERSAMPLE)` and `GCD_VAL = calc_gcd(CLK_FREQ_U, TARGET_FREQ_U)` via a bounded 128-iteration Euclidean loop at elaboration time.
  - Reduced parameters: `MOD_VAL = CLK_FREQ_U / GCD_VAL`, `INC_VAL = TARGET_FREQ_U / GCD_VAL`.
  - Default `50 MHz / 115,200`:
    - TX (`OVERSAMPLE=1`): `GCD = 3,200` $\rightarrow$ `INC = 36`, `MOD = 15,625`, `ACC_W = 14` bits (`14` acc FFs + `1` registered `tick` FF).
    - RX (`OVERSAMPLE=16`): `GCD = 3,200` $\rightarrow$ `INC = 576`, `MOD = 15,625`, `ACC_W = 14` bits (`14` acc FFs + `1` registered `tick` FF).
  - **Achieved Timing:** Exact **`115,200.00 bps` (`0.0000%` long-term frequency error)**, zero cumulative drift, and $\le 1\text{ clk}$ ($\pm 0.23\%$) single-bit jitter. When `CLK_FREQ` is an exact multiple of `TARGET_FREQ`, `INC_VAL = 1` and jitter is `0`.
  - **Registered `tick` Pre-Load:** On `clr == 1`, `acc <= (INC_C >= MOD_C) ? '0 : INC_C` and `tick <= (INC_C >= MOD_C)`, ensuring the first registered `tick` lands at exact `MOD_VAL / INC_VAL` cycles without combinational adder paths into downstream FSMs.

---

## 4. Transmitter Microarchitecture (`uart_tx`)

### States & Operation
- `tx_state_t` (`2'd0..2'd3`): `TX_IDLE`, `TX_START`, `TX_DATA`, `TX_STOP`.
- **Reset (`!rst_n`):** `tx_state <= TX_IDLE`, `tx_serial <= 1'b1`, `tx_ready <= 1'b0`, `tx_shift_reg <= 8'h00`, `tx_bit_idx <= 3'd0`. After `rst_n` releases, `tx_ready` asserts `1'b1` on the first `posedge clk` in `TX_IDLE`.
- **Handshake & Frame Serialization:**
  1. `TX_IDLE`: On `tx_valid && tx_ready`, latches `tx_shift_reg <= tx_data`, pulses `tx_accept` (`clr` to `u_tx_baud_gen`), deasserts `tx_ready <= 1'b0`, drives start bit `tx_serial <= 1'b0`, and enters `TX_START`.
  2. `TX_START`: Holds `0` for 1 full bit period (`tx_bit_tick`), then drives `tx_serial <= tx_shift_reg[0]` and enters `TX_DATA`.
  3. `TX_DATA`: Shifts right on each `tx_bit_tick` (`tx_bit_idx` `0..7`, LSB first). After bit 7 finishes, drives `tx_serial <= 1'b1` and enters `TX_STOP`.
  4. `TX_STOP`: Holds stop bit `1` for 1 full bit period (`tx_bit_tick`), then sets `tx_ready <= 1'b1` and returns to `TX_IDLE`.
- **Back-to-Back Decision (Spec §12.6):** `tx_ready` only rises *after* `TX_STOP` completes, guaranteeing compliance with Spec §3.2 #4 and §6.1 #4 while allowing immediate acceptance on the very first `TX_IDLE` clock cycle.

---

## 5. Receiver Microarchitecture (`uart_rx`)

### 5.1 Input Synchronizer & Reset-Release Behavior
- `rx_serial` passes through two flip-flops (`rx_sync_ff1` $\rightarrow$ `rx_sync_ff2`) plus a third edge-history register (`rx_sync_prev`), all asynchronously reset (`negedge rst_n`) to `1'b1` (UART idle level).
- **Reset-Release Considerations:** Asynchronous deassertion of `rst_n` near `posedge clk` can cause recovery/removal violations in physical silicon; external reset synchronization is recommended at the SoC level. If external `rx_serial` transitions near the first active clock after reset release, `rx_sync_ff1` resolves metastability over one clock period before reaching `rx_sync_ff2`. If `rx_serial` is held low during reset release, `rx_sync_ff2` falls `1 -> 0` two cycles post-release, triggering normal start detection on cycle 3.

### 5.2 16x Oversampling Alignment, Glitch Rejection & Recovery
- `rx_state_t` (`3'd0..3'd4`): `RX_IDLE`, `RX_START`, `RX_DATA`, `RX_STOP`, `RX_WAIT_IDLE`.
- **Start Detection (`RX_IDLE`):** Falling edge `rx_falling_edge = rx_sync_prev && !rx_sync_ff2` clears `sample_cnt` and enters `RX_START`.
- **Start Validation (`RX_START`):** Counts `HALF_BIT_TICKS = (OVERSAMPLE / 2) - 1` (`7` for `16×`, i.e., 8th `rx_tick_16x`, landing `7.0..8.0` ticks = `43.8%..50.0%` into the start bit).
  - If `rx_sync_ff2 == 1'b0`: valid start bit; clears `sample_cnt` and enters `RX_DATA`.
  - If `rx_sync_ff2 == 1'b1`: short low glitch / false start rejected immediately back to `RX_IDLE`.
- **Data & Stop Sampling (`RX_DATA`, `RX_STOP`):** Counts `FULL_BIT_TICKS = OVERSAMPLE - 1` (`15` for `16×`, i.e., `+16` ticks per bit) to sample bits `0..7` LSB-first (`{rx_sync_ff2, rx_shift_reg[7:1]}`) and stop bit at exact bit centers.
- **Result & Framing-Error Recovery (Spec §12.5):**
  - Valid stop (`1`): updates `rx_data <= rx_shift_reg`, pulses `rx_valid <= 1'b1` for 1 cycle, and returns immediately to `RX_IDLE` (allowing fast back-to-back peer frames).
  - Invalid stop (`0`): preserves `rx_data`, pulses `framing_error <= 1'b1` for 1 cycle, and enters `RX_WAIT_IDLE` until `rx_sync_ff2 == 1'b1` so a stuck-low / break line generates one framing error rather than flooding spurious frames.

---

## 6. Parameter Validation & Loopback (`uart_top`)

- Elaboration-time `generate` `$error` checks enforce:
  - `CLK_FREQ > 0`, `BAUD_RATE > 0`, `OVERSAMPLE >= 4` and even, `64'(BAUD_RATE) * 64'(OVERSAMPLE) <= 64'(CLK_FREQ)`, and `ENABLE_LOOPBACK` in `{0, 1}`.
- When `ENABLE_LOOPBACK == 1`, `rx_serial_mux = loopback_en ? tx_serial : rx_serial_in` with zero added pipeline delay (handled by `uart_rx`'s 2-FF synchronizer). When `ENABLE_LOOPBACK == 0`, `rx_serial_mux = rx_serial_in` and `loopback_en` terminates cleanly on `_unused_loopback_en` (`1` mux eliminated by Yosys).
