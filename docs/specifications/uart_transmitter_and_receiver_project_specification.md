# UART Transmitter and Receiver --- Project Specification

**Document status:** Updated specification  
**Design type:** Synthesizable SystemVerilog RTL  
**Project:** UART TX/RX with 16× receiver oversampling and selectable loopback self-test

---

## 1. Project Objective

Design and verify a parameterizable, production-ready Universal Asynchronous
Receiver/Transmitter (UART) containing:

- A UART transmitter (TX).
- A UART receiver (RX) with 16× oversampling.
- A baud-rate timing-generation mechanism.
- A two-flop synchronizer for the asynchronous serial RX input.
- A top-level UART module (`uart_top`) supporting both normal external
  serial communication (`rx_serial_in` / `tx_serial`) and a selectable
  internal loopback self-test mode (`loopback_en`).
- A self-checking verification environment.
- SystemVerilog Assertions (SVA) for important protocol and interface
  behaviors.

The design must be synthesizable, parameterizable, and suitable for
simulation, waveform inspection, linting, and generic synthesis.

The AI engineering agent (Antigravity) is responsible for proposing the
architecture and generating the RTL, testbench, assertions, scripts, and
reports in accordance with the project's engineering workflow.

## 2. Functional Scope

### 2.1 UART Frame Format

The supported frame format is **8N1**:

| Field | Length | Description |
| :--- | :--- | :--- |
| Start bit | 1 bit | Logic `0` |
| Data | 8 bits | Transmitted least-significant bit first |
| Parity | None | No parity bit |
| Stop bit | 1 bit | Logic `1` |

The serial line is idle-high (`1`).

The design supports one start bit, eight data bits, and one stop bit
only. Parity configuration, variable data widths, and multiple stop-bit
configurations are outside the initial project scope.

### 2.2 Clock, Baud-Rate, and Mode Parameters

The design shall expose these parameters:

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `CLK_FREQ` | `50_000_000` | Input clock frequency in Hz |
| `BAUD_RATE` | `115_200` | UART baud rate in bits per second |
| `OVERSAMPLE` | `16` | RX oversampling factor |
| `ENABLE_LOOPBACK` | `1` | Enables internal loopback mux hardware (`1`: runtime mux present, `0`: tie off to external `rx_serial_in` for zero mux overhead) |

The input clock is assumed to be stable and shared by the TX, RX, and
top-level UART module.

The intended default configuration is a 50 MHz clock and 115200 baud.
The implementation must derive its timing from the parameters rather
than hardcoding the default divider.

The baud-rate generation architecture is an implementation decision to
be proposed during architecture planning. The agent shall evaluate
integer division and fractional/phase-accumulator approaches where
relevant, explain their frequency error and complexity trade-offs, and
recommend an approach before RTL implementation.

The generated timing must achieve the closest practical baud rate to the
configured target. The agent shall calculate and report the achieved
baud rate and percentage error for the selected implementation. Any
unsupported or invalid parameter combination must be identified clearly.

### 2.3 Reset

All design blocks shall use a common active-low asynchronous reset:

- Reset signal name: `rst_n`.
- Active-low assertion.
- Asynchronous assertion.
- Reset state must be deterministic.

Expected reset states:

| Signal/state | Reset value |
| :--- | :--- |
| TX state | Idle |
| `tx_serial` | `1` |
| `tx_ready` | `1`, once reset is released and TX is idle |
| RX state | Idle |
| `rx_valid` | `0` |
| `framing_error` | `0` |
| RX data/output registers | Deterministic value, preferably `8'h00` |
| RX synchronizer stages | `1` |

The implementation must ensure that reset behavior is consistent across
all modules. The agent shall explain any reset-release considerations
for the asynchronous RX input synchronizer.

## 3. Module-Level Requirements

The agent shall propose the detailed module hierarchy and interfaces
during architecture planning. The following functional partition is
required.

### 3.1 Baud-Rate Timing Generation

Provide timing enables derived from `CLK_FREQ` and `BAUD_RATE`.

Requirements:

- TX must receive a timing enable corresponding to one serial bit
  period.
- RX must receive a 16× oversampling timing enable.
- Timing enables shall be synchronous to the input clock and shall be
  used as clock enables; they shall not be used as generated fabric
  clocks.
- The implementation must avoid unintended timing drift as much as
  practical.
- The agent shall document counter widths, terminal-count behavior,
  initialization, and achieved timing.

The agent may implement a shared timing generator or separate TX/RX
timing generators if the architecture justifies the choice.

### 3.2 UART Transmitter

The transmitter accepts an 8-bit parallel byte and serializes it into an
8N1 frame.

Required interface signals:

| Signal | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `tx_data` | Input | 8 | Byte to transmit |
| `tx_valid` | Input | 1 | Indicates that `tx_data` is valid |
| `tx_ready` | Output | 1 | Indicates that TX can accept a byte |
| `tx_serial` | Output | 1 | UART serial output |

Handshake requirements:

1. A byte is accepted on a rising clock edge when `tx_valid` and
   `tx_ready` are both high.
2. `tx_ready` shall be high when the transmitter is idle and able to
   accept a byte.
3. Following acceptance, `tx_ready` shall deassert and remain low while
   the frame is being transmitted.
4. `tx_ready` shall return high after the stop bit has been transmitted
   and the transmitter is ready to accept another byte.
5. The transmitter shall not accept another byte while busy.
6. The transmitter shall capture the accepted byte so subsequent
   changes on `tx_data` do not corrupt the active frame.

Frame-generation requirements:

1. The serial output shall be high while idle.
2. The transmitter shall send one low start bit.
3. It shall send all eight data bits, least-significant bit first.
4. It shall send one high stop bit.
5. Each bit shall be held for the configured bit period.
6. After the stop bit completes, TX shall return to idle-high.
7. The transmitter shall support consecutive frames when a new byte is
   presented after `tx_ready` becomes high.

The exact FSM encoding and internal datapath structure are
implementation decisions.

### 3.3 UART Receiver

The receiver detects and decodes 8N1 serial frames using 16×
oversampling.

Required interface signals:

| Signal | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `rx_serial` | Input | 1 | Asynchronous UART serial input |
| `rx_data` | Output | 8 | Last successfully received byte |
| `rx_valid` | Output | 1 | One-cycle indication of a valid received byte |
| `framing_error` | Output | 1 | One-cycle indication of an invalid stop bit |

Input synchronization:

- `rx_serial` is asynchronous to `clk`.
- The receiver shall pass it through a two-flop synchronizer clocked
  by `clk` before using it in the RX control logic.
- The synchronizer stages shall be reset to logic `1`, matching the
  UART idle level.
- The receiver shall use the synchronized signal for start-bit
  detection and subsequent sampling.

Oversampling and sampling requirements:

1. The receiver shall use a 16× oversampling timing enable.
2. It shall detect a falling edge/start condition on the synchronized
   serial input.
3. It shall validate the start bit near its center to reduce
   sensitivity to edge timing.
4. It shall sample the eight data bits near the center of each bit
   period.
5. It shall assemble the received byte in the correct LSB-first order.
6. It shall validate the stop bit near its center.
7. The agent shall explain the sampling counter/tick alignment and how
   the first data-bit sample is positioned relative to the validated
   start bit.

Receive result requirements:

- If the stop bit is high, the receiver shall update `rx_data` with
  the received byte and assert `rx_valid` for exactly one `clk` cycle.
- If the stop bit is low, the receiver shall assert `framing_error`
  for exactly one `clk` cycle and shall not assert `rx_valid` for that
  frame.
- `rx_valid` and `framing_error` shall not be asserted simultaneously
  for the same received frame.
- Both status outputs shall return low after their one-cycle
  indication.
- `rx_data` shall retain the most recently successfully received byte
  until another valid frame is received or reset is asserted.
- A framing error shall not overwrite the last successfully received
  `rx_data`.
- The receiver shall return to a state where it can detect a
  subsequent frame after completing either a valid or invalid frame.

The exact FSM encoding, sampling counter implementation, and recovery
strategy are implementation decisions to be documented during
architecture planning.

### 3.4 Top-Level UART Module (`uart_top`)

Provide a top-level module named `uart_top` suitable for both standalone
system integration and self-test verification.

Requirements:

- Instantiate the transmitter (`uart_tx`) and receiver (`uart_rx`).
- Pass the same `CLK_FREQ`, `BAUD_RATE`, and `OVERSAMPLE` parameters to
  the relevant blocks.
- Support runtime-selectable internal loopback self-test via `loopback_en`
  (when `ENABLE_LOOPBACK == 1`):
  - When `loopback_en == 1'b0` (Normal Mode): connect external
    `rx_serial_in` directly to the receiver's serial input.
  - When `loopback_en == 1'b1` (Self-Test Loopback Mode): route
    `tx_serial` internally to the receiver's serial input.
  - When `ENABLE_LOOPBACK == 0`: always connect `rx_serial_in` to the
    receiver's serial input regardless of `loopback_en`.
- Keep `tx_serial` driven by `uart_tx` in both modes for external
  observation and waveform inspection.
- Do not add artificial pipeline delays to the loopback path (the
  receiver's two-flop synchronizer handles synchronization).
- Ensure switching `loopback_en` between frames does not corrupt
  completed frames; `loopback_en` shall only be toggled while both TX
  and RX are idle (unless explicitly testing mid-frame disturbance).
- Expose the TX parallel input/handshake, external RX serial input,
  `loopback_en` control, and RX parallel output/status interfaces.
- Expose `clk` and `rst_n`.

The individual TX and RX modules should also be testable independently
where practical.

## 4. Required External Top-Level Interface

The proposed `uart_top` interface shall include at least:

| Signal | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `loopback_en` | Input | 1 | `0`: Normal mode (`rx_serial_in`), `1`: Self-test loopback (`tx_serial`) |
| `tx_data` | Input | 8 | Byte to transmit |
| `tx_valid` | Input | 1 | TX input-valid indication |
| `tx_ready` | Output | 1 | TX can accept a byte |
| `tx_serial` | Output | 1 | TX serial output line |
| `rx_serial_in` | Input | 1 | External asynchronous RX serial input |
| `rx_data` | Output | 8 | Successfully received byte |
| `rx_valid` | Output | 1 | One-cycle valid-byte indication |
| `framing_error` | Output | 1 | One-cycle framing-error indication |

If the agent proposes a different external interface for standalone
testing, it must preserve these top-level functional requirements and
explain the change before implementation.

## 5. Verification Requirements

Antigravity shall generate the testbench and verification
infrastructure. The testbench must be self-checking and must not rely
only on visual waveform inspection.

### 5.1 TX Verification

Verify at least:

- Reset and idle-high behavior.
- Correct start-bit polarity and duration.
- Correct transmission of all eight data bits, LSB-first.
- Correct stop-bit polarity and duration.
- Correct `tx_valid`/`tx_ready` handshake.
- `tx_ready` remains low while TX is busy.
- Input data changes after acceptance do not affect the active frame.
- Transmission of `8'h00`, `8'hFF`, `8'hA5`, and `8'h3C`.
- Consecutive byte transmissions.
- Reset during an active transmission.

### 5.2 RX Verification

Verify at least:

- Reset and idle behavior.
- Start-bit detection and validation.
- Correct 16× oversampling behavior.
- Correct sampling and reconstruction of all eight bits.
- Valid stop-bit detection.
- Invalid stop-bit detection.
- `rx_valid` is exactly one clock cycle for a valid frame.
- `framing_error` is exactly one clock cycle for a bad stop bit.
- `rx_valid` is not asserted for a frame with an invalid stop bit.
- `rx_data` retains its previous successful value after a framing
  error.
- Recovery and reception of a valid frame after a framing error.
- Reset during reception.

### 5.3 Integration and Loopback Self-Test Verification

Verify at least:

- **Self-Test Mode (`loopback_en = 1`):**
  - End-to-end transmission and reception of multiple data patterns.
  - TX and RX agree on the transmitted byte.
  - No unexpected framing errors occur during normal loopback.
  - Consecutive transactions work correctly.
  - Handshake behavior remains correct during back-to-back traffic.
- **Normal Mode (`loopback_en = 0`):**
  - TX transmits serial frames onto `tx_serial` while `rx_serial_in` is
    idle (`1`), confirming `uart_rx` ignores `tx_serial` when
    `loopback_en = 0`.
  - External stimulus driven on `rx_serial_in` is received accurately on
    `rx_data` / `rx_valid` independently of TX activity (full-duplex
    simultaneous TX and RX).
- **Mode Switching:**
  - Clean transition between `loopback_en = 1` (self-test) and
    `loopback_en = 0` (normal external operation) while idle.
- Parameter configurations other than the default are tested where
  simulation runtime permits.

### 5.4 Negative and Boundary Scenarios

The agent shall consider and, where practical, verify:

- A low stop bit driven on `rx_serial_in` in normal mode (`loopback_en = 0`).
- A short low pulse/noise event on `rx_serial_in` (`loopback_en = 0`) that
  should not be accepted as a valid start bit.
- Reset during TX and RX activity.
- TX input data changing while the transmitter is busy.
- RX line remaining idle-high.
- Parameter values that do not divide evenly into the system clock
  frequency.
- Invalid parameter combinations, including zero baud rate or a baud
  rate incompatible with the configured clock/oversampling
  architecture.

The verification plan shall distinguish required tests from optional
robustness tests and explain any unsupported scenarios.

## 6. Required SVA Properties

Antigravity shall generate a dedicated assertion file or files
containing properties for the following requirements.

### 6.1 TX Assertions

1. **TX idle level:** When TX is idle, `tx_serial` must be high.
2. **TX acceptance and busy behavior:** When a byte is accepted
   (`tx_valid && tx_ready`), `tx_ready` must deassert after that
   acceptance edge.
3. **TX busy hold:** `tx_ready` must remain low throughout the active
   frame.
4. **TX completion:** `tx_ready` may return high only after the stop
   bit has completed.
5. **TX stability:** The active frame must not be corrupted by changes
   to `tx_data` after acceptance.

### 6.2 RX Assertions

1. **One-cycle valid pulse:** `rx_valid` must never remain high for
   more than one clock cycle.
2. **Valid frame completion:** A valid stop bit must result in a
   one-cycle `rx_valid` indication and the correct `rx_data`.
3. **Framing error:** A low stop bit must result in a one-cycle
   `framing_error` indication.
4. **No valid indication on bad stop:** A frame with an invalid stop
   bit must not produce `rx_valid`.
5. **Mutual exclusion:** `rx_valid` and `framing_error` must not be
   high simultaneously.
6. **Data retention:** A framing error must not overwrite the last
   successfully received `rx_data`.

### 6.3 Assertion Quality Requirements

- Assertions shall use the correct clock and reset-disable conditions.
- Temporal relationships must account for synchronous handshakes and
  registered outputs.
- Assertions shall not assume implementation-specific FSM encodings
  unless explicitly justified.
- The agent shall explain each assertion in plain language.
- The agent shall identify properties that require a checker/reference
  model or testbench support rather than a simple local assertion.
- The agent shall check assertion compilation and report unsupported
  SVA constructs in the selected simulator.
- Assertion results, including failures and vacuity considerations,
  shall be included in the verification report.

## 7. RTL Quality and Coding Requirements

- Use synthesizable SystemVerilog.
- Use `logic` for appropriate signal declarations.
- Use `always_ff` for sequential logic and `always_comb` for
  combinational logic where appropriate.
- Use nonblocking assignments in sequential blocks.
- Avoid inferred latches.
- Avoid using internal timing enables as clocks.
- Keep clock-domain and asynchronous-input handling explicit.
- Use meaningful signal and state names.
- Parameterize timing-related logic.
- Include comments for non-obvious timing and sampling decisions.
- Keep modules reasonably separated by responsibility.
- Do not silently change the approved specification.
- Any specification ambiguity or proposed behavior change must be
  raised before implementation.

## 8. Synthesis and Static Checks

The project shall support:

- RTL linting.
- Elaboration and hierarchy checks.
- Simulation.
- SVA compilation and execution where supported.
- Generic synthesis using Yosys.
- Structural checks.
- Synthesis statistics.
- Synthesized netlist export.
- Preservation of logs and reports.

Generic synthesis results shall not be presented as actual ASIC area,
standard-cell area, FPGA resource utilization, or timing closure unless
an appropriate target technology/device flow and constraints are used.

## 9. Waveform Inspection Requirements

Generate waveform output (for example, VCD) suitable for manual
inspection in GTKWave.

Waveforms should make it practical to inspect:

- System clock and reset.
- TX handshake (`tx_valid`, `tx_ready`).
- `tx_data` and `tx_serial`.
- TX FSM state and bit/timing counters where useful.
- Mode selection (`loopback_en`), external `rx_serial_in`, internal RX
  serial line, and synchronized serial signal.
- 16× oversampling tick or equivalent timing event.
- RX FSM state and sampling counters where useful.
- `rx_data`, `rx_valid`, and `framing_error`.

Internal signals may be exposed through simulation-only visibility or
carefully chosen debug signals. Do not add unnecessary debug ports to
the synthesizable design solely for waveform viewing.

## 10. Expected Project Deliverables

Antigravity shall generate and maintain the project artifacts, as
appropriate to the approved architecture:

- Specification document.
- Architecture/design document.
- Synthesizable RTL modules.
- Self-checking testbench(s).
- SVA source file(s).
- Simulation and lint scripts.
- Simulation logs.
- Assertion results.
- Lint report.
- Verification summary and test results.
- Waveform files.
- Yosys synthesis script.
- Synthesis log, statistics, structural-check report, and synthesized
  netlist.
- Final project summary describing implementation decisions,
  verification results, known limitations, and learning outcomes.

The exact file names and folder placement shall follow the existing
project structure and be proposed before file creation.

## 11. Engineering Workflow and Approval Gates

The project shall follow the existing root `AGENTS.md` and installed
engineering skills.

The intended workflow is:

1. **Specification review:** Read this document, identify ambiguities,
   and produce a requirements checklist.
2. **Architecture planning:** Propose module hierarchy, interfaces,
   timing generation, TX/RX FSMs, oversampling strategy, and
   verification architecture.
3. **Architecture approval:** Stop and wait for user approval before
   implementing.
4. **RTL implementation:** Generate the approved RTL blocks.
5. **RTL review and lint:** Review the generated RTL, elaborate, and
   lint it.
6. **Verification implementation:** Generate self-checking testbenches
   and SVA.
7. **Simulation and debug:** Run tests, inspect failures, and debug as
   a grouped phase.
8. **Synthesis:** Run generic Yosys synthesis and report
   structural/statistical results.
9. **Final review:** Summarize deliverables, test outcomes, known
   limitations, and learning outcomes.

Antigravity is responsible for generating the RTL blocks, testbenches,
SVA, scripts, and reports. The user should not need to write these
artifacts manually.

Approval policy:

- Read-only inspection and analysis may proceed without approval.
- Present the architecture and identified ambiguities before
  implementation.
- Obtain approval at each major engineering phase according to the
  root `AGENTS.md`.
- Group related file creation/modification and commands within an
  approved phase rather than requesting approval for every individual
  file or terminal command.
- Do not proceed to a later major phase without the required approval.
- Do not overwrite unrelated project files or the existing counter
  project.

## 12. Open Decisions for Architecture Review

The following are intentionally left for the architecture phase.
Antigravity must analyze and recommend a solution rather than silently
choosing:

1. Integer divider versus fractional/phase-accumulator timing
   generation.
2. Shared timing generator versus separate TX and RX timing generators.
3. Exact 16× RX sampling-counter alignment and center-sampling
   sequence.
4. Start-bit validation and false-start rejection behavior.
5. Recovery timing after a framing error.
6. Whether TX accepts a new byte immediately on the first cycle after
   completing the stop bit or on the next idle cycle.
7. Supported parameter ranges and elaboration-time parameter checks.
8. Simulator-specific SVA compatibility and any required assertion
   adaptations.

Any recommendation must include its reasoning and impact on timing
accuracy, complexity, verification, and synthesizability.

---

**End of specification.**