---
name: sva
description: Develops specification-driven SystemVerilog Assertions for protocol, control, datapath, reset, and temporal behavior.
---

# SystemVerilog Assertions (SVA) Skill

## Objective

Write meaningful, maintainable SystemVerilog Assertions that check the approved design requirements. Assertions must be derived from the specification and actual interface timing. Do not assume a protocol, clock, reset polarity, or latency that is not specified.

## Inputs

Before writing properties, establish:
- Clocking event for each property.
- Reset signal, polarity, assertion behavior, and release semantics.
- Sampling relationship between interface signals.
- Required latency, ordering, stability, and handshake rules.
- Legal operating conditions and any required assumptions.
- Simulator/formal tool support for the SVA constructs being considered.

If any of these are unclear, ask for clarification or clearly identify the limitation.

## Procedure

### Phase 1 — Property Planning

1. Map relevant specification requirements to candidate properties.
2. Classify properties as safety (something bad never happens), liveness/progress (something good eventually happens), protocol, reset, or data-integrity checks.
3. Identify the clock and reset context for each property.
4. Identify antecedent conditions and consequent behavior.
5. Determine whether the property belongs in an interface checker, module-boundary checker, or internal design checker.
6. Identify required assumptions and distinguish them from assertions.

**STOP:** Present the property plan and request approval before creating or modifying SVA files.

## Phase 2 — Property Development

Use clear, named properties and assertions. Where appropriate, consider checks for:

- Reset values and reset-related behavior.
- State transition legality.
- Output stability under specified stall/hold conditions.
- Request/response or valid/ready protocol rules.
- Data and control alignment.
- Ordering and bounded response latency.
- Counter bounds, pointer movement, and occupancy constraints.
- Mutual exclusion and one-hot conditions.
- Error signaling and recovery.
- Parameter-dependent invariants.

These are examples of property categories, not requirements to add to every design.

## Phase 3 — Temporal Semantics and Coding Rules

- Use the specified clocking event; do not assume `posedge clk` for every property.
- Use `disable iff` only when its asynchronous abort semantics match the design's reset intent.
- Be precise about sampled-value semantics and use `$past`, `$stable`, `$rose`, `$fell`, `$changed`, `$onehot`, or related functions only when appropriate and supported.
- Guard `$past`-based properties against invalid initial history where necessary.
- Use overlapped (`|->`) versus non-overlapped (`|=>`) implication according to the exact cycle relationship.
- Express bounded delays only when the specification defines a bound.
- Avoid vacuous properties: ensure antecedents can occur and consider companion cover properties where useful.
- Do not add assumptions that hide DUT failures or overconstrain legal behavior.
- Separate environment assumptions from DUT assertions.
- Avoid asserting behavior during unspecified or unconstrained conditions.
- Make parameterized properties robust at legal parameter boundaries.
- Do not silently alter property meaning to work around a simulator limitation.

## Phase 4 — Tool Compatibility

SVA support differs across simulators and versions. Before execution:
1. Identify the selected tool and version.
2. Check whether the required SVA syntax and semantics are supported.
3. If unsupported, report the limitation and propose an approved alternative (for example, a procedural checker or a different simulator).
4. Do not claim assertions passed if they were not compiled and executed.
5. Keep a distinction between assertions that were authored, compiled, enabled, and actually exercised.

Tool execution remains subject to the root approval gates.

## Phase 5 — Review

For every property, review:
- Requirement and intent.
- Clock and reset correctness.
- Antecedent reachability and vacuity risk.
- Exact cycle/latency semantics.
- Sampling and `$past` history validity.
- Whether the property checks DUT behavior rather than restating an assumption.
- Parameter and tool compatibility.
- Diagnostic clarity and naming.

## Deliverables

As applicable:
- Property plan and requirement mapping.
- SVA source files or bind/checker modules.
- Assumptions and environmental constraints, clearly separated.
- Tool-compatibility notes.
- Assertion compile/run results and coverage, only when observed.
