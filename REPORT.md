# Introduction / Overview
- Brief description of the assignment objectives
  - Objective: investigate LLM-driven generation and LLM-driven verification of Hardware Trojans (HTs) in small RTL benchmarks drawn from the CSAW AI Hardware Attack Challenges. Produce reproducible artifacts (generated RTL, testbench templates, LLM interaction logs) and document how Trojans were inserted, analyzed, and validated using an automated workflow.
- Overview of the automated system/tools used
  - Primary automation harness: a Jupyter notebook that orchestrates prompt creation, LLM invocation, parsing of LLM outputs, file generation (Verilog + testbench templates), and simulation orchestration where possible.
  - Simulation tools: iverilog / vvp were invoked from within the notebook for the AES (Challenge 1) golden-model runs. UART simulation attempts failed due to structural inconsistencies in LLM-generated RTL.
  - LLM roles: generation agent (produce Trojan-inserted Verilog and testbench suggestions) and verifier agent (analyze generated Verilog to identify triggers, payloads, and expected effects).
  - An external Trojan-insertion framework (e.g., GHOST) was used, from the same author of this notebook: https://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=10904479

# Task 1: Challenge 1 — AES Core Trojan
- How the Trojan Works: Explain the mechanism and implementation details
  - Trojan type: counter-triggered Denial-of-Service (DoS) or output corruption affecting AES encryption operations.
  - Trigger mechanism: a counter that increments on encryption-complete events; when the counter reaches a configured threshold the Trojan activates.
  - Payload mechanism: when activated, the Trojan asserts a gating/reset/override signal that disables further encryption or corrupts output validity, effectively stopping correct operation.
  - Implementation details: the Trojan was inserted at the top-level AES wrapper to minimize interference with internal round logic. A small register bank (counter and a trigger flag) plus a conditional mux/gate were added. Signal reuse and narrow-width counters were chosen to keep area overhead minimal.
  - Stealth considerations: rare trigger (high threshold), minimal extra state, reuse of existing control signals (e.g., done/valid pulses) to reduce suspicious new interfaces.
- Testing Methodology: Describe how you tested and verified the Trojan functionality
  - Golden-model simulation: the notebook ran the original AES golden model to produce reference behavior.
  - LLM-assisted analysis: in addition to simulation, LLM analysis was used to inspect the inserted code, confirm the trigger logic and the payload path, and produce a natural-language explanation of the expected runtime behavior.
- Troubleshooting & Design Decisions: Document any challenges faced with the automated system and how you resolved them
  - Issues encountered:
    - LLM outputs initially contained naming mismatches, missing wire declarations, and inconsistent port widths.
    - Early payload placements caused pre-trigger interference with AES datapath.
    - Some generated constructs were syntactically valid but semantically misaligned to the existing top-level signals.
  - Resolutions and design decisions:
    - Used iterative prompt-refinement cycles to get the LLM to correct names and port lists; notebook re-submitted corrected prompts and captured revised outputs.
    - Limited payload complexity (mux + flag) to avoid introducing timing hazards and to keep the modified RTL synthesizable and simulatable.
    - Validated each iteration with simulation (golden model) until behavior matched expectations.
- AI Interaction Summary: Brief overview of the prompting strategy used
  - Prompts asked the LLM to produce a stealthy DoS Trojan with a specific high-count trigger, minimal area overhead, and safe integration with the top-level AES wrapper.
  - Iterative refinement prompts focused on fixing port mismatches, adding missing wire/reg declarations, and producing a minimal testbench to reach the trigger.
  - Verification prompts asked a second LLM instance (or separate prompts) to read the generated Verilog and describe the trigger, payload, and activation path in plain language; these descriptions were cross-checked with manual analysis.

# Task 2: Challenge 2 — UART Trojan
- How the Trojan Works: Explain the mechanism and implementation details
  - Trojan type: UART backdoor / data-path manipulation activated by a specific received byte sequence.
  - Trigger mechanism: detection of a configured byte pattern on the UART RX path. Detection logic sets a hidden register/flag when sequence is observed.
  - Payload mechanism: when trigger flag is set, conditional muxing or an override path modifies the UART TX output (for example, substituting bytes, leaking internal state bytes, or altering handshake behavior).
  - Implementation details: LLM-generated insertion implemented trigger detector (small shift register + pattern comparator), a trigger latch, and a conditional mux on the TX data path. Insertions were kept minimal and placed to avoid touching the UART core FSM internals when possible.
  - Stealth considerations: reusing existing control signals, minimal gate count, trigger via rare sequence to avoid accidental activation.
- Testing Methodology: Describe how you tested and verified the Trojan functionality
  - Simulation attempts: the notebook attempted to assemble and run autogenerated testbenches for UART, but the simulation toolchain failed due to structural and integration errors in LLM-generated RTL (mismatched ports, baud/generator mis-integration, missing signals).
  - LLM-based verification: because simulation could not be executed, the notebook relied on LLM-assisted static analysis for verification. The modified UART Verilog was fed to the LLM with prompts to:
    - Identify trigger detection logic and explain how a byte sequence would be captured,
    - Trace the control flow from trigger to payload activation,
    - Confirm whether the payload path can alter TX bytes without breaking idle functionality,
    - Point out syntactic or structural issues preventing simulation (port mismatches, missing regs/wires, clock/reset handling).
  - The LLM’s analysis outputs were used to determine that the Trojan is present, how it would activate, and the expected effect on UART outputs.
- Troubleshooting & Design Decisions: Document any challenges faced with the automated system and how you resolved them
  - Issues encountered:
    - Repeated simulation failures due to LLM-generated RTL inconsistencies (port width mismatches, missing instantiations, incorrect baud generator interfacing).
    - Tight timing sensitivity of UART FSM made deep insertion risky and error-prone.
  - Resolutions and design decisions:
    - Pivoted verification strategy from dynamic simulation to LLM-driven static analysis; prompts directed the LLM to perform reasoning about control and data flow.
    - Simplified Trojan design to a minimal mux + latch approach to reduce integration complexity and limit points of failure.
    - Used multiple LLM analysis prompts from different perspectives to increase confidence in the interpretation.
- AI Interaction Summary: Brief overview of the prompting strategy used
  - Generation prompts requested a stealthy UART backdoor triggered by a specific sequence, with minimal changes and a small synthesis footprint.
  - Debugging prompts asked the LLM to detect and fix specific syntactic/semantic issues (naming, missing wires, port widths). Multiple corrected versions were requested; many still failed to yield simulation-ready RTL.
  - Verification prompts asked the LLM to read the final modified UART Verilog and produce a step-by-step explanation of trigger detection and payload activation; the notebook aggregated these analyses as the primary verification artifact.

# Automated System Details
- Which tool(s) you used (GHOST or custom tools)
  - Based on IEEE Access paper (pormpt optimization using perspective-based analysis): https://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=10904479
- Any modifications made to existing tools
  - Notebook contains custom helper code to:
    - format and submit prompts to the LLM,
    - parse and sanitize LLM textual outputs (extract Verilog code blocks),
    - write Verilog and testbench files to disk with consistent naming,
    - invoke local simulation (iverilog/vvp) where possible,
    - capture and store LLM interaction logs and simulation outputs.
  - Additional logic was added to attempt automated fixes (e.g., add missing wire/reg declarations when the LLM missed them), but full automation of fixes was not always successful.
- General approach to automation
  - Pipeline: define Trojan specification → craft initial prompt → request LLM-generated RTL → parse & save files → attempt simulation → if simulation fails, prompt LLM for analysis and debugging → refine RTL via prompts → repeat until stable or until analysis confidence is sufficient.
  - Verification strategy chosen adaptively: prefer dynamic simulation when golden model and stable RTL exist (AES). When simulation is infeasible, rely on multi-perspective LLM analysis as the primary verifier (UART).

# Conclusion
- Summary of results
  - AES (Challenge 1): Trojan generated and verified. Golden-model simulation was executed; modified AES behavior diverged at trigger and LLM analysis corroborated the trigger/payload semantics.
  - UART (Challenge 2): Trojan generated but dynamic simulation was infeasible. Verification relied on LLM-based static and behavioral analysis; LLM analysis identified trigger and payload and provided reasoning about likely runtime effects.
- Lessons learned
  - LLMs can produce useful HDL modifications and meaningful static analyses, but generated RTL often needs iterative correction for synthactic and integration correctness.
  - Wrapper-level changes are more reliably produced and integrated by LLMs than deep FSM/state-machine modifications.
  - LLM-based verification is a viable fallback when golden models are absent, but it is probabilistic and should be complemented by simulation/formal methods where possible.
- Reflections on the automation process
  - Automation accelerated Trojan prototyping and created reproducible artifacts, but human-in-the-loop prompt engineering and selective manual corrections were necessary to reach usable outputs.
  - The notebook-centric approach provides a clear, auditable trail of generation and verification attempts (LLM prompts, LLM analyses, files created, and simulation logs).
