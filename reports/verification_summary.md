# UART Verification, SVA, Lint & Synthesis Summary Report

**Design Under Test:** `uart_top`, `uart_tx`, `uart_rx`, `uart_baud_gen`  
**Tools Verified:** `Verilator 5.032` (lint, simulation, SVA, VCD) and `Yosys 0.52` (generic synthesis)

---

## 1. Verification & SVA Architecture

- **Self-Checking Testbench (`tb/uart_tb.sv`):**
  - Instantiates 5 DUT configurations simultaneously:
    1. `u_tx_dut`: standalone `uart_tx` (`50 MHz / 115,200`)
    2. `u_rx_dut`: standalone `uart_rx` (`50 MHz / 115,200`)
    3. `u_top_dut`: default `uart_top` (`50 MHz / 115,200 / ENABLE_LOOPBACK=1`) + `u_top_sva`
    4. `u_top_alt`: alternate `uart_top` (`50 MHz / 460,800 / ENABLE_LOOPBACK=0`) + `u_alt_sva`
    5. `u_top_12m`: non-divisible clock `uart_top` (`12.5 MHz / 115,200 / ENABLE_LOOPBACK=1`) + `u_12m_sva`
  - Uses independent serial capture/drive BFMs, deterministic 32-bit LFSR stimulus (`seed = 32'hCAFE_BEEF`), watchdog timeouts, explicit coverage counters, and VCD dumping (`waveforms/uart_tb.vcd`).
- **SystemVerilog Assertions (`sva/uart_sva.sv`):**
  - Black-box port-level checker clocked on `@(posedge clk)` with `disable iff (!rst_n)` and `past_valid` reset guard.
  - Independent TX bit-center tracker and 2-FF synchronized RX frame tracker (`RX_START_CHK` at ~0.5 bit, `RX_STOP_CHK` at 9.25 bits with pulse window through `10.0` bits + margin).

---

## 2. Requirement-to-Test & SVA Traceability

| Req ID | Description | TB Tests | SVA Properties | Status |
| :--- | :--- | :--- | :--- | :--- |
| `FR-01` | 8N1 frame format (LSB first, idle high) | `T02`, `T06`, `T10`, `T11` | `a_tx_frame_integrity`, `a_rx_frame_outcome` | **PASS** |
| `FR-02`, `BG-01..02` | Parameterized Bresenham timing & non-divisible configs | `T13` (`50M/460.8k`, `12.5M/115.2k`) | `u_alt_sva`, `u_12m_sva` | **PASS** |
| `RST-01`, `RST-02` | Common async `rst_n` & deterministic reset states | `T01`, `T04`, `T05`, `T09` | `disable iff (!rst_n)`, `past_valid` | **PASS** |
| `TX-01..04` | TX handshake, data capture, busy hold, stop completion | `T01`–`T04`, `T10`, `T11` | `a_tx_idle_high`, `a_tx_accept_deasserts_ready`, `a_tx_busy_hold_ready`, `a_tx_completion_ready`, `a_tx_frame_integrity` | **PASS** |
| `RX-01..04`, `RX-06` | 2-FF sync, `16×` sampling, glitch rejection, 1-cyc valid/mutex | `T05`, `T06`, `T08`, `T10`–`T12` | `a_rx_valid_one_cycle`, `a_rx_valid_ferr_mutex`, `a_rx_frame_outcome` | **PASS** |
| `RX-05` | Bad stop `framing_error`, `rx_data` retention, recovery | `T07`, `T11` | `a_rx_ferr_one_cycle`, `a_rx_data_retention_on_ferr`, `a_rx_frame_outcome` | **PASS** |
| `TOP-01`, `TOP-02` | `uart_top` loopback, full-duplex normal, `ENABLE_LOOPBACK=0`, switching | `T10`–`T13` | All 3 `uart_sva` instances | **PASS** |

---

## 3. Observed Tool Results

### 3.1 RTL Lint (`scripts/run_lint.sh`, log: `logs/lint.log`)
- `Verilator 5.032 --lint-only -Wall`:
  - `uart_top` (default): exit `0`, **0 warnings**
  - `uart_top` (`-GENABLE_LOOPBACK=0`): exit `0`, **0 warnings**
  - `uart_tx` standalone: exit `0`, **0 warnings**
  - `uart_rx` standalone: exit `0`, **0 warnings**

### 3.2 Simulation & SVA (`scripts/run_sim.sh`, logs: `logs/sim_compile.log`, `logs/sim.log`)
- Compile (`verilator --binary --assert --trace -Wall --timescale 1ns/1ps -Wno-SYNCASYNCNET`): exit `0`, **0 warnings, 0 errors**.
- Simulation (`./build/obj_uart_tb/Vuart_tb`): exit `0` (`UART_TB PASSED`, `$finish` at `4ms`, walltime `0.962 s`):
  - `Checks Passed      : 131027`
  - `Checks Failed      : 0`
  - `TX Frames Verified : 7`
  - `RX Frames Verified : 7`
  - `Loopback Frames    : 10`
  - `Full-Duplex Ops    : 1`
  - `Alt-Param Frames   : 2`
  - `Framing Errors     : 1`
  - `Glitches Rejected  : 3`
  - `Mid-Frame Resets   : 2`
  - `Bit Toggle 0/1     : 0xff / 0xff`
  - **SVA Outcomes:** `0` assertion failures across all 3 `uart_sva` instances (`u_top_sva`, `u_alt_sva`, `u_12m_sva`).
  - **Waveform:** `waveforms/uart_tb.vcd` generated for GTKWave inspection.

### 3.3 Generic Synthesis (`scripts/synth_uart.ys`, log: `logs/yosys_synth.log`)
- `Yosys 0.52`: exit `0`
- Structural check (`reports/yosys_check.txt`): `Found and reported 0 problems.`
- Generic statistics (`reports/yosys_stat.txt`):
  - Total hierarchy (`uart_top`): `258` wires (`412` wire bits), `0` memories, `0` latches, `335` generic leaf cells (`76` flip-flops: `67` `$_DFFE_PN0P_`, `1` `$_DFFE_PN1P_`, `5` `$_DFF_PN0_`, `3` `$_DFF_PN1_`).
  - Netlist exported: `build/uart_top_generic_synth.v`.

---

## 4. Known Limitations & Scope Boundaries

1. `iverilog`/`vvp` is not installed in the environment; simulation/SVA ran on `Verilator 5.032` with `-Wno-SYNCASYNCNET` scoped to the simulation build due to Verilator's lowering of SVA `disable iff (!rst_n)` alongside async `negedge rst_n` RTL.
2. `DVM_COVERAGE=0` in Verilator means `cover property` hit counts were not exported to a coverage database; non-vacuity and scenario coverage were recorded via explicit testbench counters.
3. Invalid-parameter elaboration failure tests (e.g., `BAUD_RATE=0` or `BAUD_RATE * OVERSAMPLE > CLK_FREQ`) were not compiled in separate negative-build runs.
4. Generic Yosys synthesis statistics do not constitute physical ASIC area, FPGA LUT utilization, or static timing closure.
