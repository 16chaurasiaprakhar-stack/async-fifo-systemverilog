# Production Asynchronous FIFO (CDC) & Verification Suite in SystemVerilog

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog%20IEEE%201800-blue.svg)](https://standards.ieee.org/)
[![EDA Simulation](https://img.shields.io/badge/Simulation-Icarus%20%7C%20Vivado%20XSim-brightgreen.svg)]() 
[![CDC Verification](https://img.shields.io/badge/Verification-SVA%20%2B%20CDC%20Scoreboard-orange.svg)]()
[![Synthesis Ready](https://img.shields.io/badge/Synthesis-Vivado%20%2F%20Design%20Compiler-blueviolet.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An industry-ready, parameterizable **Asynchronous FIFO (First-In, First-Out)** IP core designed for safe, high-throughput **Clock Domain Crossing (CDC)** in modern ASIC and FPGA systems. 

This repository provides a side-by-side implementation of:
1. **Production-Grade FIFO Core (`async_fifo_pro`):** Industry-standard Style #1 lookahead flag generation, fully synchronous glitch-free registers, multi-stage synchronizers with synthesis placement attributes, programmable flow-control watermarks, and hardware defensive gating.
2. **Academic Landmark Model (`style2_academic`):** Modernized SystemVerilog implementation of Clifford E. Cummings & Peter Alfke’s SNUG 2002 paper (*FIFO Style #2*) featuring dual Gray/Binary counters and asynchronous quadrant-based comparison logic.

---

## 📑 Table of Contents
- [Why Asynchronous FIFOs Matter (The Engineering Challenge)](#why-asynchronous-fifos-matter-the-engineering-challenge)
- [Architecture & Core Concepts](#architecture--core-concepts)
  - [1. Resolving Empty vs. Full via $(N+1)$-Bit Gray Coding](#1-resolving-empty-vs-full-via-n1-bit-gray-coding)
  - [2. Dual-Counter Architecture ($F_{max}$ Optimization)](#2-dual-counter-architecture-f_max-optimization)
  - [3. Pessimistic Safe Flow Control & Watermarks](#3-pessimistic-safe-flow-control--watermarks)
  - [4. Synthesis CDC Directives & Metastability Hardening](#4-synthesis-cdc-directives--metastability-hardening)
- [Architectural Trade-Off: Production vs. Cummings Style #2](#architectural-trade-off-production-vs-cummings-style-2)
- [Directory Structure](#directory-structure)
- [Verification Suite & SVA Assertions](#verification-suite--sva-assertions)
  - [Testbench Scenarios](#testbench-scenarios)
  - [SystemVerilog Assertions (SVA)](#systemverilog-assertions-sva)
- [Simulation & Build Instructions](#simulation--build-instructions)
  - [1-Click Vivado Project Generation](#1-click-vivado-project-generation)
  - [Open-Source Icarus Verilog Simulation](#open-source-icarus-verilog-simulation)
- [Synthesis & Static Timing Analysis (STA) Constraints](#synthesis--static-timing-analysis-sta-constraints)
- [Interactive Schematic](#interactive-schematic)
- [Author & License](#author--license)

---

## Why Asynchronous FIFOs Matter (The Engineering Challenge)

In high-performance SoCs (such as GPUs, AI accelerators, and multi-core processors), different functional blocks (PCIe, DDR controllers, Compute Engines, AXI interconnects) run on completely asynchronous, unrelated clock oscillators. 

Transferring data between these domains introduces fundamental physical risks:
1. **Metastability:** Violating setup/hold times causes flip-flops to oscillate between logic levels, resulting in corrupted states or system lockups.
2. **Multi-Bit Coherency Failures:** Passing multi-bit binary pointers across clock boundaries is catastrophic; because different bits encounter varied routing delays, intermediate non-existent binary values will be sampled on destination clock edges.
3. **Latency Inaccuracy:** Synchronizer latency means the write domain always sees a delayed version of the read pointer, and vice versa.

This project addresses these challenges with mathematically sound CDC strategies, formal assertions, and timing closure constraints.

---

## Architecture & Core Concepts

```
                    Write Clock Domain (wclk)                       Read Clock Domain (rclk)
               +---------------------------------+             +---------------------------------+
               |                                 |             |                                 |
wdata [31:0] ->|        async_fifo_mem           |             |                                 |
winc --------->|        (Dual-Port RAM)          |============>| rdata [31:0]                    |
               |                                 |             |                                 |
               +---------------------------------+             +---------------------------------+
                         ^             ^                                 ^             ^
                         |             |                                 |             |
                         | waddr       | wclken                          | raddr       |
                         |             |                                 |             |
               +---------------------------------+             +---------------------------------+
               |        wptr_full_ctrl           |             |        rptr_empty_ctrl          |
               |  - Dual Counter (wbin, wptr)    |             |  - Dual Counter (rbin, rptr)    |
               |  - Lookahead Full Comparison    |             |  - Lookahead Empty Comparison   |
               |  - Occupancy & Watermarks       |             |  - Occupancy & Watermarks       |
               +---------------------------------+             +---------------------------------+
                     |                     ^                         |                     ^
                     | wptr                | rptr_sync               | rptr                | wptr_sync
                     v                     |                         v                     |
               +-----------+         +-----------+             +-----------+         +-----------+
               | cdc_sync  |         | cdc_sync  |             | cdc_sync  |         | cdc_sync  |
               | (w2r sync)|         | (r2w sync)|             | (r2w sync)|         | (w2r sync)| 
               | 2-FF Flop |         | 2-FF Flop |             | 2-FF Flop |         | 2-FF Flop |
               +-----------+         +-----------+             +-----------+         +-----------+
                     |                                                       |
                     +-------------------- Cross-Domain Path ----------------+
```

### 1. Resolving Empty vs. Full via $(N+1)$-Bit Gray Coding
Gray codes guarantee that **only one bit changes per clock cycle**, eliminating multi-bit sample skew across clock boundaries.

For a FIFO of depth $2^N$, pointers are sized to $N+1$ bits:
* **FIFO Empty Condition:** The write pointer and read pointer are identical across all $N+1$ bits:
  $$\text{rempty\_val} = (\text{rgnext} == \text{wptr\_sync})$$
* **FIFO Full Condition:** The write pointer has wrapped around the circular buffer once more than the read pointer. In Gray code, this occurs when the MSB and 2nd MSB are inverted, while all lower LSBs match:
  $$\text{wfull\_val} = \left(\text{wgnext} == \{\neg\text{rptr\_sync}[N:N-1], \text{rptr\_sync}[N-2:0]\}\right)$$

### 2. Dual-Counter Architecture ($F_{max}$ Optimization)
Traditional Gray counter architectures convert Gray $\rightarrow$ Binary on each cycle using XOR trees, creating a long combinational feedback path that hurts maximum clock frequency ($F_{max}$). 

This design maintains **two distinct registers per domain**:
- `wbin` / `rbin`: An $(N+1)$-bit binary counter to leverage hardware fast carry lookahead logic.
- `wptr` / `rptr`: An $(N+1)$-bit Gray register updated directly from the next binary value:
  $$\text{wgnext} = (\text{wbnext} \gg 1) \oplus \text{wbnext}$$
This keeps the critical setup timing path clean and enables high operating frequencies.

### 3. Pessimistic Safe Flow Control & Watermarks 
Because cross-domain synchronizers introduce 2 clock cycles of latency:
- In the **write domain**, the synchronized `rptr_sync` is slightly delayed. The FIFO perceives the buffer to be *fuller than it actually is*.
- In the **read domain**, `wptr_sync` is slightly delayed. The FIFO perceives the buffer to have *less data than it actually has*.

This latency is **inherently safe**: it prevents buffer overflow and underflow under all timing conditions. Real-time occupancy counters and watermarks are computed as:
$$\text{w\_occupancy} = \text{wbin} - \text{rbin\_sync}$$
$$\text{almost\_full} = (\text{w\_occupancy} \ge \text{ALMOST\_FULL\_THRESH}) \lor \text{wfull}$$

### 4. Synthesis CDC Directives & Metastability Hardening
Standard synthesis tools can inadvertently optimize, merge, or place synchronizer flip-flops in disparate slices across the FPGA fabric. The synchronizer module [`rtl/cdc_sync.sv`](rtl/cdc_sync.sv) enforces:
```systemverilog
(* ASYNC_REG = "TRUE", dont_touch = "true" *) logic [WIDTH-1:0] sync_stage [0:STAGES-1];
```
This guarantees that synchronizer registers are kept intact and placed physically adjacent in silicon to maximize Mean Time Between Failures (MTBF).

---

## Architectural Trade-Off: Production vs. Cummings Style #2 

| Architectural Metric | Cummings Style #2 (`style2_academic`) | Production FIFO (`async_fifo_pro`) |
| :--- | :--- | :--- |
| **Industry Paradigm** | Academic / FPGA Historical | Modern ASIC & High-Rel FPGA Standard |
| **Comparator Architecture** | Combinational cross-domain comparator + SR Latch | Synchronized Gray lookahead comparator |
| **Flag Assertion** | Direct asynchronous preset pulses (`afull_n`) | Synchronous registered output |
| **Downstream Hazard Risk** | Prone to glitching if STA violated | **100% glitch-free registered flags** |
| **Static Timing Analysis (STA)** | Non-standard; requires recovery/removal analysis | **Clean SDC constraints (`set_clock_groups`)** |
| **Design-for-Test (DFT)** | Difficult scan-insertion due to async presets | **100% Scan/ATPG testable** |
| **Watermarks & Telemetry** | Full / Empty only | Programmable `almost_full`, `almost_empty`, occupancy |
| **Defensive Hardware** | Unprotected write enable | **Internal hardware gating (`winc & !wfull`)** |

---

## Directory Structure

```
├── rtl/                                # Production IP core (SystemVerilog)
│   ├── async_fifo_pro.sv               # Parameterized top-level wrapper
│   ├── async_fifo_mem.sv               # Dual-port RAM with defensive write gating
│   ├── cdc_sync.sv                     # Parameterized multi-stage CDC synchronizer
│   ├── wptr_full_ctrl.sv               # Write pointer & full/almost-full logic
│   └── rptr_empty_ctrl.sv              # Read pointer & empty/almost-empty logic
├── tb/                                 # Verification & assertions
│   ├── async_fifo_pro_tb.sv            # Comprehensive 7-phase self-checking testbench
│   └── async_fifo_sva.sv               # SystemVerilog Assertions (SVA) monitor
├── constraints/                        # Formal timing constraints
│   ├── async_fifo_pro.sdc              # SDC for PrimeTime / Design Compiler
│   └── async_fifo_pro.xdc              # XDC for AMD Vivado STA engine
├── scripts/                            # Portable execution automation
│   ├── run_vivado.tcl                  # 1-click Vivado project & simulation generator
│   ├── run_sim_iverilog.bat            # Windows batch runner for open-source Icarus
│   └── run_style2_sim.bat              # Script to simulate academic Style #2
├── docs/                               # Architecture assets
│   └── async_fifo_architecture.html    # Interactive standalone SVG schematic
├── style2_academic/                    # Complete modernized Cummings Style #2 core
│   ├── rtl/                            # Style #2 RTL (async_cmp, fifomem, etc.)
│   ├── tb/                             # Style #2 Testbench & protocol checkers
│   └── constraints/                    # Style #2 SDC constraints
├── .gitignore                          # Clean EDA & OS ignore rules
└── README.md                           # Professional project documentation
```

---

## Verification Suite & SVA Assertions

The testbench [`tb/async_fifo_pro_tb.sv`](tb/async_fifo_pro_tb.sv) provides 100% end-to-end self-checking verification with dynamic queue scoreboarding.

### Testbench Scenarios
- **Phase 1: Reset & Idle Verification:** Verifies initial flag conditions (`rempty=1`, `wfull=0`, occupancy=0).
- **Phase 2: Single-Word Handshake:** Ensures latency cycles and pointer increments function accurately.
- **Phase 3: Burst Write to Full:** Pushes sequential data until depth saturation, confirming `wfull` asserts and excess writes are safely dropped.
- **Phase 4: Burst Read to Empty:** Empties the FIFO, checking data integrity and confirming `rempty` asserts. 
- **Phase 5: Extreme Ratio (Fast Producer / Slow Consumer):** `wclk` = 200 MHz, `rclk` = 25 MHz (8:1 clock frequency ratio).
- **Phase 6: Extreme Ratio (Slow Producer / Fast Consumer):** `wclk` = 25 MHz, `rclk` = 200 MHz (1:8 clock frequency ratio).
- **Phase 7: Random Concurrent Traffic with Clock Jitter:** Randomized bursts, back-to-back writes/reads, and random delays.

### SystemVerilog Assertions (SVA)
Embedded in [`tb/async_fifo_sva.sv`](tb/async_fifo_sva.sv):
- `chk_no_write_overflow`: Asserts an error if `winc` is asserted while `wfull == 1`.
- `chk_no_read_underflow`: Asserts an error if `rinc` is asserted while `rempty == 1`.
- `chk_wptr_gray_step`: Asserts that write Gray pointers never change by more than 1 bit per cycle.
- `chk_rptr_gray_step`: Asserts that read Gray pointers never change by more than 1 bit per cycle.

#### Simulation Verification Log Output
```text
=======================================================
   STARTING PRODUCTION ASYNC FIFO COMPREHENSIVE SUITE   
=======================================================
[Phase 1] Reset & Initial State Check
  -> Reset verified: rempty=1, almost_empty=1, wfull=0, almost_full=0
[Phase 2] Single Transaction Handshake
  -> Single word write & read passed, rempty correctly restored.
[Phase 3] Burst Write to Full (Depth = 16)
  -> Burst write full passed: wfull=1, almost_full=1, w_occupancy=16
  -> Testing hardware defensive write protection when full...
[Phase 4] Burst Read to Empty (Depth = 16)
  -> Burst read empty passed: rempty=1, almost_empty=1, r_occupancy=0
  -> Testing hardware defensive read protection when empty...
[Phase 5] Extreme Ratio 1: Fast Producer (200MHz) -> Slow Consumer (25MHz)
  -> Fast Producer / Slow Consumer test passed with 0 errors.
[Phase 6] Extreme Ratio 2: Slow Producer (25MHz) -> Fast Consumer (200MHz)
  -> Slow Producer / Fast Consumer test passed with 0 errors.
[Phase 7] High-Stress Random Traffic with Jitter (100MHz vs 133MHz)

=======================================================
             PRODUCTION VERIFICATION SUMMARY          
=======================================================
 Total Transactions Written: 157
 Total Transactions Read   : 157
 Residual Scoreboard Size  : 0
 Total Errors Reported     : 0
 RESULT: >>> 100% VERIFICATION SUCCESSFUL (PASSED) <<<
=======================================================
```

---

## Simulation & Build Instructions

### 1-Click Vivado Project Generation
No manual GUI file addition needed. Run the automated script:
```powershell
vivado -mode gui -source scripts/run_vivado.tcl
```
Vivado will create the project, link all source files via portable relative paths, configure simulation settings, and prepare behavioral simulation.

### Open-Source Icarus Verilog Simulation
To run simulation in open-source environments:
```powershell
# Run the automated batch script
.\scripts\run_sim_iverilog.bat

# Open generated waveform in GTKWave
gtkwave async_fifo_pro.vcd
```

---

## Synthesis & Static Timing Analysis (STA) Constraints

Cross-domain paths between asynchronous clocks must not be analyzed for synchronous setup/hold violations, but their routing latency must be bounded.

From [`constraints/async_fifo_pro.xdc`](constraints/async_fifo_pro.xdc):
```tcl
# 1. Define Asynchronous Clock Domains
create_clock -period 10.000 -name wclk [get_ports wclk]
create_clock -period 25.000 -name rclk [get_ports rclk]

# 2. Declare Asynchronous Clock Groups (Prevents False CDC Violations)
set_clock_groups -asynchronous -group [get_clocks wclk] -group [get_clocks rclk]

# 3. Constrain Gray Pointer Crossings (Max Delay Datapath Only)
set_max_delay -from [get_cells -hier -filter {NAME =~ *wptr_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *sync_stage_reg[0]*}] \
              -datapath_only 10.000

set_max_delay -from [get_cells -hier -filter {NAME =~ *rptr_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *sync_stage_reg[0]*}] \
              -datapath_only 25.000
```

---

## Interactive Schematic

An interactive, dark-mode vector diagram of the complete internal architecture—including clock domains, flip-flop stages, and bus routes—can be opened directly in any web browser:

👉 **[`docs/async_fifo_architecture.html`](docs/async_fifo_architecture.html)**

---

## Author & License

* **Author:** Prakhar Chaurasia ([GitHub Profile](https://github.com/16chaurasiaprakhar-stack))
* **License:** Licensed under the [MIT License](LICENSE).
