# Parameterizable 8N1 UART TX/RX with 16x Oversampling and Loopback Self-Test

Synthesizable SystemVerilog Universal Asynchronous Receiver/Transmitter (`uart_top`) implementing an **8N1** serial protocol, **GCD-reduced Bresenham fractional baud-rate generation**, **16x receiver oversampling**, a **two-flop input synchronizer**, and a **selectable internal loopback self-test mode**.

---

## Key Features

- **8N1 Serial Frame Format:** 1 start bit (`0`), 8 data bits (LSB first), no parity, 1 stop bit (`1`), idle-high (`1`).
- **Zero-Drift Fractional Timing (`uart_baud_gen`):** GCD-reduced modulo-`CLK_FREQ` Bresenham tick generator producing synchronous single-cycle clock enables (`0.0000%` average frequency error across valid clock/baud ratios, zero cumulative drift, and $\le 1\text{ clk}$ cycle-to-cycle jitter).
- **Buffered Valid/Ready Transmitter (`uart_tx`):** Captures `tx_data` on `tx_valid && tx_ready`, holds `tx_ready` low throughout the active 10-bit frame, resets its local `1x` bit timer per frame for zero start-bit latency/truncation, and supports consecutive back-to-back transfers.
- **16x Oversampling Receiver (`uart_rx`):**
  - Two-flop asynchronous input synchronizer + falling-edge detector (all stages reset to idle-high `1'b1`).
  - Start-bit validation near bit center (`OVERSAMPLE/2 - 1` = tick `7` of `0..15`) rejecting short low glitches (`< ~0.5` bit period).
  - Center-aligned sampling of 8 data bits (LSB first) and stop bit (`OVERSAMPLE - 1` = tick `15`).
  - Mutually exclusive 1-cycle `rx_valid` and `framing_error` pulses; retains prior valid `rx_data` on framing error and waits for line idle-high (`RX_WAIT_IDLE`) before arming the next frame.
- **Top-Level Integration (`uart_top`):**
  - Parameterized `ENABLE_LOOPBACK` (`1`: runtime `loopback_en` mux between `rx_serial_in` and `tx_serial`; `0`: hardwired to `rx_serial_in` with zero mux logic).
  - Common active-low asynchronous reset (`rst_n`) with deterministic reset state across all blocks.
- **Self-Checking Verification & SVA:** Black-box concurrent SVA monitor (`sva/uart_sva.sv`) and directed/random/negative testbench (`tb/uart_tb.sv`) with VCD waveform generation for GTKWave.

---

## Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `CLK_FREQ` | `50_000_000` | Input system clock frequency (Hz) |
| `BAUD_RATE` | `115_200` | Target UART baud rate (bps) |
| `OVERSAMPLE` | `16` | RX oversampling factor (even integer $\ge 4$) |
| `ENABLE_LOOPBACK` | `1` | `1`: enable `loopback_en` mux; `0`: tie RX to `rx_serial_in` |

---

## Repository Structure

```text
├── docs/
│   ├── architecture/uart_architecture.md  # Detailed RTL architecture & design decisions
│   └── specifications/                    # Governing project specification
├── rtl/
│   ├── uart_baud_gen.sv                   # GCD-reduced Bresenham tick generator
│   ├── uart_tx.sv                         # 8N1 UART transmitter
│   ├── uart_rx.sv                         # 8N1 UART receiver (2-FF sync + 16x oversampling)
│   └── uart_top.sv                        # Top-level module with loopback mux
├── sva/
│   └── uart_sva.sv                        # Protocol-level SVA & auxiliary monitors
├── tb/
│   └── uart_tb.sv                         # Self-checking testbench (T01-T13)
├── scripts/
│   ├── run_lint.sh                        # Verilator -Wall lint checks
│   ├── run_sim.sh                         # Verilator simulation + SVA + VCD run
│   └── synth_uart.ys                      # Yosys generic synthesis script
├── reports/
│   ├── verification_summary.md            # Verification, SVA, lint & synthesis summary
│   ├── yosys_check.txt                    # Yosys structural check output
│   └── yosys_stat.txt                     # Yosys generic cell statistics
├── logs/                                  # Tool execution logs
├── waveforms/                             # VCD waveform output (waveforms/uart_tb.vcd)
└── build/                                 # Compiled simulator binary & generic netlist
```

---

## Verification & SVA Summary

- **Testbench (`tb/uart_tb.sv`):** Instantiates standalone `uart_tx`, standalone `uart_rx`, default `uart_top` (`50 MHz / 115,200 / ENABLE_LOOPBACK=1`), alternate `uart_top` (`50 MHz / 460,800 / ENABLE_LOOPBACK=0`), and `12.5 MHz / 115,200` `uart_top`. Exercises reset/idle (`T01`, `T05`), directed patterns `0x00`/`0xFF`/`0xA5`/`0x3C` (`T02`), mid-frame `tx_data` mutation & back-to-back TX (`T03`), mid-frame resets (`T04`, `T09`), sub-bit phase offsets & $\pm 1.5\%$ baud mismatch (`T06`), framing error + retention + recovery (`T07`), short-pulse glitch rejection (`T08`), loopback PRNG stream (`T10`), full-duplex normal mode (`T11`), mode switching (`T12`), and non-default parameters (`T13`).
- **SVA (`sva/uart_sva.sv`):** Monitors `uart_top` external ports without assuming internal RTL FSM encodings, checking all Spec §6.1 TX properties (`a_tx_idle_high`, `a_tx_accept_deasserts_ready`, `a_tx_busy_hold_ready`, `a_tx_completion_ready`, `a_tx_frame_integrity`), §6.2 RX properties (`a_rx_valid_one_cycle`, `a_rx_ferr_one_cycle`, `a_rx_valid_ferr_mutex`, `a_rx_data_retention_on_ferr`, `a_rx_frame_outcome`), and companion `cover property` checks.

---

## How to Run

### 1. RTL Lint (Verilator)
```bash
bash scripts/run_lint.sh
```

### 2. Simulation, SVA & VCD Waveforms (Verilator)
```bash
bash scripts/run_sim.sh
# Optional waveform inspection:
gtkwave waveforms/uart_tb.vcd
```

### 3. Generic Synthesis (Yosys)
```bash
yosys -l logs/yosys_synth.log -s scripts/synth_uart.ys
```

---

## Observed Results

| Check | Tool | Outcome | Key Metrics |
| :--- | :--- | :--- | :--- |
| Lint (`-Wall`) | `Verilator 5.032` | **PASS** (exit `0`) | 0 warnings across `uart_top` (default & `ENABLE_LOOPBACK=0`), `uart_tx`, `uart_rx` |
| Simulation + SVA | `Verilator 5.032` | **PASS** (exit `0`) | `131027` checks passed, `0` failed, 0 SVA errors across 3 `uart_sva` instances (`4ms` sim) |
| Generic Synthesis | `Yosys 0.52` | **PASS** (exit `0`) | `0` structural problems; `335` generic cells (`76` flip-flops), `0` latches/memories |

*Note: Yosys results represent generic abstract logic statistics, not physical ASIC area, FPGA LUT count, or timing closure.*
