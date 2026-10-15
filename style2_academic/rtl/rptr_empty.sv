//-----------------------------------------------------------------------------
// Module: rptr_empty
// Description: Read Pointer & Asynchronously Preset Empty Flag Synchronizer
// Based on: Clifford E. Cummings & Peter Alfke (SNUG 2002) - FIFO Style #2
// Modernized to SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module rptr_empty #(
    parameter int ADDRSIZE = 4
)(
    input  logic                rclk,
    input  logic                rrst_n,
    input  logic                rinc,
    input  logic                aempty_n,
    output logic                rempty,
    output logic [ADDRSIZE-1:0] rptr
);

    logic [ADDRSIZE-1:0] rbin = '0;
    logic [ADDRSIZE-1:0] rbnext;
    logic [ADDRSIZE-1:0] rgnext;
    logic                rempty2 = 1'b1;

    // Increment binary counter only when read enabled and not empty
    assign rbnext = (!rempty) ? (rbin + {{(ADDRSIZE-1){1'b0}}, rinc}) : rbin;

    // Binary to Gray conversion
    assign rgnext = (rbnext >> 1) ^ rbnext;

    // Dual register scheme (Style #2):
    // rbin captures next binary count, rptr captures next Gray count
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= '0;
            rptr <= '0;
        end else begin
            rbin <= rbnext;
            rptr <= rgnext;
        end
    end

    // Asynchronously preset empty flag synchronizer:
    // - Asserted immediately when aempty_n is 0 (or rrst_n is 0).
    // - De-asserted synchronously to rclk via 2-stage synchronizer when
    //   aempty_n returns to 1 (upon a write in the other domain).
    wire aempty_preset_n = aempty_n & rrst_n;

    always_ff @(posedge rclk or negedge aempty_preset_n) begin
        if (!aempty_preset_n) begin
            {rempty, rempty2} <= 2'b11;
        end else begin
            {rempty, rempty2} <= {rempty2, ~aempty_n};
        end
    end

endmodule
