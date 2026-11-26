---
name: rtl-verification
description: Plans and develops functional verification environments and self-checking testbenches for specification-driven RTL designs.
---

# RTL Verification Skill

## Objective

Create a systematic, self-checking verification strategy for the active design. Verification must be derived from the approved specification and architecture; do not assume a particular protocol or design type.

## Inputs

- Approved specification and requirement list.
- Approved architecture and RTL interface.
- Clock/reset definitions and timing assumptions.
- Tool/simulator capabilities and limitations.
- Any approved verification methodology or coding conventions.

If the design behavior is ambiguous, raise the issue before encoding an assumed expected result in the testbench.

## Procedure

### Phase 1 — Verification Planning

1. Convert each functional and interface requirement into one or more verification objectives.
2. Identify normal operation, boundary conditions, corner cases, error conditions, reset scenarios, and concurrent events.
3. Identify legal and illegal stimulus according to the specification.
4. Define the expected behavior and checking point for every objective.
5. Decide which checks belong in the testbench, SVA, or both.
6. Identify coverage goals and explain what each coverage item demonstrates.
7. Build a requirement-to-test traceability matrix.

**STOP:** Present the verification plan and request approval before creating verification files.

## Phase 2 — Testbench Architecture

Choose a testbench structure appropriate to design complexity. It may include:
- Clock and reset generation.
- DUT instantiation.
- Transaction or task-based stimulus.
- Drivers and monitors.
- Reference model or scoreboard.
- Checkers and assertions.
- Functional coverage or explicit coverage counters.
- Test sequencing and a clear end-of-test summary.

Do not add unnecessary framework complexity to a small design. Keep testbench-only constructs out of synthesizable RTL.

## Phase 3 — Stimulus Strategy

Use a balanced set of tests:

1. **Directed tests:** Explicitly exercise each specified behavior.
2. **Boundary tests:** Minimum/maximum values, empty/full conditions, rollover, alignment, and parameter limits as applicable.
3. **Reset tests:** Reset at startup and during operation; verify assertion and release behavior exactly as specified.
4. **Concurrency tests:** Simultaneous requests/events, backpressure, contention, and ordering where applicable.
5. **Error/negative tests:** Only when illegal behavior and expected response are defined by the specification.
6. **Randomized tests:** Use constrained random stimulus when it adds value; make seeds reproducible and constraints specification-based.
7. **Regression tests:** Preserve previously failing scenarios as directed tests after fixes.

Do not test undefined behavior as though its expected result were known.

## Phase 4 — Self-Checking Strategy

- Compare DUT outputs and transactions against an independent reference model or expected-value calculation.
- Avoid duplicating the DUT's implementation algorithm in the scoreboard when an independent model is practical.
- Check data values, valid/ready or request/acknowledge behavior, ordering, latency, and side effects as specified.
- Detect missing responses and unexpected extra responses.
- Use timeouts to prevent deadlocked tests from running indefinitely.
- Ensure the testbench itself does not race the DUT; use appropriate clocking discipline and sampling regions.
- Report the first failure with test name, time, expected value, actual value, and relevant transaction/context.
- End with an unambiguous PASS/FAIL summary and nonzero failure indication where supported.

## Phase 5 — Coverage

Define coverage from the specification, not from arbitrary percentages.

Consider:
- Requirement coverage.
- State and transition coverage for FSMs.
- Input/data boundary coverage.
- Interface transaction types and combinations.
- Reset and recovery scenarios.
- Error and backpressure scenarios.
- Cross coverage for meaningful interacting conditions.

Distinguish planned coverage, measured coverage, and unmeasured coverage. Do not claim coverage closure from a small set of directed tests unless the coverage goals justify it.

## Phase 6 — Review and Tool Execution

Review:
- Every requirement has a planned check or a documented reason it cannot be checked.
- Expected results are independent and correct.
- Stimulus is legal unless intentionally testing specified error handling.
- Race conditions and sampling errors are avoided.
- Tests terminate and report failures clearly.
- Random tests are reproducible.
- Simulator-supported language features are used.

Do not compile or run simulation without the root-level approval for that stage. Check simulator support for SystemVerilog features before relying on them.

## Deliverables

As applicable:
- Verification plan.
- Requirement-to-test traceability matrix.
- Testbench source and reusable tasks/components.
- Reference model and scoreboard.
- Directed/random test list and seed information.
- Coverage plan and measured results.
- Regression summary and known limitations.
