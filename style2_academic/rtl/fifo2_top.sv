//-----------------------------------------------------------------------------
// Module: fifo2_top
// Description: Top-Level Asynchronous FIFO (FIFO Style #2)
// Reference: "Simulation and Synthesis Techniques for Asynchronous FIFO Design
//             with Asynchronous Pointer Comparisons"
// Authors: Clifford E. Cummings (Sunburst Design) & Peter Alfke (Xilinx)
// Modernized to SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module fifo2_top #(
    parameter int DATASIZE = 8,                // Data bus width
    parameter int ADDRSIZE = 4                 // Address bus width (FIFO depth = 2**ADDRSIZE)
)(
    // Write Domain Ports
    input  logic                wclk,
    input  logic                wrst_n,
    input  logic                winc,
    input  logic [DATASIZE-1:0] wdata,
    output logic                wfull,

    // Read Domain Ports
    input  logic                rclk,
    input  logic                rrst_n,
    input  logic                rinc,
    output logic [DATASIZE-1:0] rdata,
    output logic                rempty
);

    // Internal interconnect signals
    logic [ADDRSIZE-1:0] wptr;
    logic [ADDRSIZE-1:0] rptr;
    logic                aempty_n;
    logic                afull_n;

    // 1. Asynchronous Pointer Comparator & Direction Detector
    async_cmp #(
        .ADDRSIZE(ADDRSIZE)
    ) u_async_cmp (
        .wptr    (wptr),
        .rptr    (rptr),
        .wrst_n  (wrst_n),
        .aempty_n(aempty_n),
        .afull_n (afull_n)
    );

    // 2. FIFO Memory Buffer (Dual-Port RAM)
    // Defensive gating: memory write is qualified with !wfull
    fifomem #(
        .DATASIZE(DATASIZE),
        .ADDRSIZE(ADDRSIZE)
    ) u_fifomem (
        .wclk  (wclk),
        .wclken(winc & !wfull),
        .waddr (wptr),
        .wdata (wdata),
        .raddr (rptr),
        .rdata (rdata)
    );

    // 3. Read Pointer & Empty Flag Generator
    rptr_empty #(
        .ADDRSIZE(ADDRSIZE)
    ) u_rptr_empty (
        .rclk    (rclk),
        .rrst_n  (rrst_n),
        .rinc    (rinc),
        .aempty_n(aempty_n),
        .rempty  (rempty),
        .rptr    (rptr)
    );

    // 4. Write Pointer & Full Flag Generator
    wptr_full #(
        .ADDRSIZE(ADDRSIZE)
    ) u_wptr_full (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .afull_n(afull_n),
        .wfull  (wfull),
        .wptr   (wptr)
    );

endmodule
