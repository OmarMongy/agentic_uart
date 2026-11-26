---
name: rtl-design
description: Analyzes hardware specifications, proposes microarchitecture, generates and reviews synthesizable Verilog/SystemVerilog RTL for digital designs.
---

# RTL Design Skill

## Objective

Design clear, correct, maintainable, synthesizable RTL that implements the **approved active-project specification**. This skill is generic and must not assume a particular protocol, module, datapath, FSM, clock, reset, or target technology.

## Inputs

Before beginning, identify:
- Governing specification and relevant reference documents.
- Approved architecture and design decisions, if already available.
- Required top-level module, submodules, interfaces, parameters, and constraints.
- Applicable coding standard and target tool/language limitations, if specified.

Do not invent missing requirements.

## Procedure

### Phase 1 — Specification Analysis

1. Read the complete relevant specification.
2. Extract ports, directions, widths, types, parameters, and legal parameter ranges.
3. Identify clocks, clock domains, active edges, reset polarity/type/value, and reset release requirements.
4. Extract functional behavior, sequencing, handshakes, data formats, priorities, and error behavior.
5. Identify boundary conditions, illegal inputs, backpressure, concurrency, and parameter corner cases where applicable.
6. Create a requirement list and maintain traceability to planned RTL behavior.
7. Report ambiguity or contradiction instead of silently choosing an interpretation.

### Phase 2 — Architecture and Microarchitecture

1. Identify the top-level block and propose a module hierarchy.
2. Define each module's responsibility and interface.
3. Separate datapath, control, storage, and interface logic where that improves clarity.
4. Identify state machines, registers, counters, buffers, memories, and arithmetic resources as required by the specification.
5. Describe state transitions and data/control flow.
6. Explain reset strategy, clock-domain boundaries, and timing assumptions.
7. Identify parameterization and legal parameter constraints.
8. Discuss meaningful implementation tradeoffs without claiming unmeasured PPA results.
9. Map requirements to modules and planned checks.

**STOP:** Present the architecture and request approval before RTL generation.

### Phase 3 — RTL Generation

Only after architecture approval:

1. Generate Verilog/SystemVerilog that follows the approved architecture.
2. Keep synthesizable design RTL separate from testbench code.
3. Use `always_ff` / `always_comb` when SystemVerilog is approved and supported by the target tools; otherwise use an appropriate synthesizable coding style.
4. Use nonblocking assignments for sequential state updates.
5. Use blocking assignments for combinational procedural calculations.
6. Provide complete combinational assignments to avoid unintended latches.
7. Use explicit widths, signedness, casts, and sized constants where needed.
8. Avoid multiple procedural drivers and ambiguous ownership of state.
9. Keep reset behavior and priority explicit.
10. Use parameters/localparams for genuinely reusable design dimensions; validate parameter ranges.
11. Avoid unnecessary complexity, hidden assumptions, and tool-specific constructs unless justified.
12. Add comments for non-obvious design intent, not for every line.

Before file creation or modification, present the target paths and proposed contents/change summary and obtain approval.

### Phase 4 — Static Self-Review

Review the RTL against the approved specification and architecture:

- Port and parameter consistency.
- Clock and reset sensitivity and polarity.
- Reset values and behavior during/after reset.
- Sequential versus combinational logic.
- Blocking/nonblocking assignment usage.
- Complete assignments and latch inference.
- Width, signedness, truncation, extension, and overflow.
- FSM state coverage and default behavior, where applicable.
- Handshake and backpressure behavior, where applicable.
- Simultaneous events and priority rules.
- Parameter boundary behavior.
- Synthesizability and likely tool compatibility.
- Requirement traceability.

Report issues and unresolved questions. Static review is not a substitute for lint, simulation, formal verification, or synthesis.

### Phase 5 — Tool Handoff

Do not run tools automatically. Follow the root approval gates for lint, compilation, simulation, synthesis, and reruns. When preparing a tool run, identify the top module and source list from the active project rather than assuming fixed filenames.

## Deliverables

As applicable:
- Architecture description and module hierarchy.
- Interface/parameter summary.
- RTL source files.
- Static self-review checklist.
- Requirement-to-RTL traceability table.
- Open issues and assumptions.
