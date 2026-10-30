//-----------------------------------------------------------------------------
// Module: wptr_full
// Description: Write Pointer & Asynchronously Preset Full Flag Synchronizer
// Based on: Clifford E. Cummings & Peter Alfke (SNUG 2002) - FIFO Style #2
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module wptr_full #(
    parameter int ADDRSIZE = 4
)(
    input  logic                wclk,
    input  logic                wrst_n,
    input  logic                winc,
    input  logic                afull_n,
    output logic                wfull,
    output logic [ADDRSIZE-1:0] wptr
);

    logic [ADDRSIZE-1:0] wbin = '0;
    logic [ADDRSIZE-1:0] wbnext;
    logic [ADDRSIZE-1:0] wgnext;
    logic                wfull2 = 1'b0;

    // Increment binary counter only when write enabled and not full
    assign wbnext = (!wfull) ? (wbin + {{(ADDRSIZE-1){1'b0}}, winc}) : wbin;

    // Binary to Gray conversion
    assign wgnext = (wbnext >> 1) ^ wbnext;

    // Dual register scheme (Style #2):
    // wbin captures next binary count, wptr captures next Gray count
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= '0;
            wptr <= '0;
        end else begin
            wbin <= wbnext;
            wptr <= wgnext;
        end
    end

    // Asynchronously preset full flag synchronizer:
    // - Cleared on wrst_n (FIFO reset)
    // - Preset to 1 immediately when afull_n is asserted low
    // - De-asserted synchronously to wclk via 2-stage synchronizer when
    //   afull_n returns to 1 (upon a read in the other domain).
    always_ff @(posedge wclk or negedge wrst_n or negedge afull_n) begin
        if (!wrst_n) begin
            {wfull, wfull2} <= 2'b00;
        end else if (!afull_n) begin
            {wfull, wfull2} <= 2'b11;
        end else begin
            {wfull, wfull2} <= {wfull2, ~afull_n};
        end
    end

endmodule
