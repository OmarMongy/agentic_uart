---
name: rtl-synthesis
description: Plans and analyzes RTL synthesis using Yosys or an appropriate target-specific synthesis flow.
---

# RTL Synthesis Skill

## Objective

Evaluate whether the approved RTL can be elaborated and synthesized, inspect the resulting logic representation, and report synthesis evidence accurately. Do not assume a PDK, FPGA family, top module, or design-specific source list.

## Inputs

Identify:
- Approved RTL source files and intended top-level module.
- Language version and include paths/defines/parameters.
- Intended target: generic logic, ASIC library, or FPGA architecture.
- Available synthesis tool and version.
- Required technology data, if target mapping is requested.

## Generic Yosys Flow

For generic synthesis, Yosys does not require a PDK. A typical flow may include:

1. **Read RTL:** Read the approved Verilog/SystemVerilog sources using supported frontend options.
2. **Hierarchy Check:** Check the design hierarchy and select the specified top module.
3. **Process Lowering:** Convert behavioral constructs (such as `always` blocks and processes) into a structural representation.
4. **Optimization:** Apply synthesis optimizations to simplify and improve the design, including:
   - Constant propagation and removal of unused logic.
   - Dead-code and unused-cell elimination.
   - Boolean logic simplification.
   - Common subexpression sharing where applicable.
   - FSM detection and optimization when applicable.
   - Register and memory optimization where supported.
5. **Generic Synthesis:** Run the Yosys synthesis flow to transform the RTL into a generic gate-level representation.
6. **Technology Mapping (Optional):**
   - For generic mapping, use ABC to optimize and map combinational logic into generic gates.
   - For ASIC mapping, use a compatible standard-cell Liberty (`.lib`) file.
   - For FPGA mapping, use the appropriate target architecture and device-specific flow.
7. **Structural Checks:** Run checks to identify problems such as undriven signals, multiple drivers, or structural inconsistencies.
8. **Statistics:** Inspect cell counts, register counts, memory usage, and other synthesis statistics.
9. **Netlist Export:** Export the synthesized netlist and preserve synthesis logs and reports.

### Optimization Guidelines

- Do not assume that one optimization sequence is optimal for every design.
- Use Yosys's standard synthesis flow as the default unless the project requires a customized flow.
- Apply additional optimization passes only when they serve a clear engineering purpose.
- Preserve the original RTL; synthesis optimization must not silently modify the approved source files.
- Compare synthesis statistics before and after optimization when evaluating a particular optimization.
- Clearly distinguish generic gate-level results from technology-mapped results.
- Never interpret generic gate counts as actual ASIC area or FPGA resource utilization.

The exact commands must be adapted to the active project's source files, top module, defines, parameters, and Yosys version. Never copy a previous project's module name or file list without checking.

## Interpretation Rules

- High-level cells (for example, `$add`, `$adff`, `$mux`) represent abstract RTL operations or sequential elements.
- Generic mapped cells (for example, `$_AND_`, `$_XOR_`, or generic enabled-flop cells) are not physical standard-cell instances.
- ABC may optimize combinational logic during a generic synthesis flow.
- Generic cell counts are not a reliable physical area estimate.
- Generic synthesis does not establish timing closure, routing feasibility, power, or manufacturability.
- A successful structural `check` does not prove functional correctness.
- Sequential cell mapping and available cell types depend on the selected flow and library.

## Target-Specific Mapping

### ASIC

Technology mapping requires a suitable Liberty `.lib` library and a compatible synthesis setup. Additional technology and physical-design data may be needed for downstream implementation. Do not invent a PDK or library. Report missing files and unsupported cells.

### FPGA

Use a supported architecture/device-specific synthesis flow. Identify the FPGA family and required tool support before selecting mapping commands. Generic synthesis alone is not an FPGA implementation result.

## Procedure

1. Confirm the top module and complete source list from the active project.
2. Check frontend compatibility with the RTL language features.
3. Propose the synthesis sequence and output artifacts.
4. Explain whether the flow is generic or target-specific.
5. Request approval before running Yosys or another synthesis tool.
6. Preserve the command log, synthesis statistics, structural-check output, and netlist under the active workspace.
7. Review warnings, inferred memories, latches, unsupported constructs, and unexpected cell structures.
8. Compare results with the RTL intent; do not infer PPA without appropriate target data and analysis.

## Deliverables

As applicable:
- Synthesis command/script.
- Tool version and run log.
- Hierarchy and structural-check results.
- Generic or technology-mapped cell statistics, clearly labeled.
- Synthesized netlist.
- Warnings, limitations, and unresolved issues.
- Requirement/implementation observations, without claiming functional proof.
