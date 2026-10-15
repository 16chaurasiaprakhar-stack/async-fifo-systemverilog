//-----------------------------------------------------------------------------
// Module: fifo_assertions
// Description: Protocol and Safety Assertions for Async FIFO
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module fifo_assertions #(
    parameter int DATASIZE = 8,
    parameter int ADDRSIZE = 4
)(
    input logic                wclk,
    input logic                wrst_n,
    input logic                winc,
    input logic                wfull,
    input logic [ADDRSIZE-1:0] wptr,

    input logic                rclk,
    input logic                rrst_n,
    input logic                rinc,
    input logic                rempty,
    input logic [ADDRSIZE-1:0] rptr
);

    // Helper function to count set bits portably across all simulators
    function automatic int count_ones(input [ADDRSIZE-1:0] val);
        int cnt = 0;
        for (int i = 0; i < ADDRSIZE; i++) begin
            if (val[i]) cnt++;
        end
        return cnt;
    endfunction

    // Track previous pointers to verify Gray code single-bit transitions
    logic [ADDRSIZE-1:0] wptr_prev = '0;
    logic [ADDRSIZE-1:0] rptr_prev = '0;

    // Write domain assertions
    always_ff @(posedge wclk) begin
        if (wrst_n) begin
            // 1. Prevent write overflow
            assert (!(winc && wfull))
                else $error("[SVA-ERROR] FIFO Overflow! Write attempted while wfull is asserted at time %0t", $time);

            // 2. Gray code transition check: wptr should only change by at most 1 bit per clock
            assert (count_ones(wptr ^ wptr_prev) <= 1)
                else $error("[SVA-ERROR] Illegal Gray code step on wptr! Jumped from %b to %b at time %0t",
                            wptr_prev, wptr, $time);

            wptr_prev <= wptr;
        end else begin
            wptr_prev <= '0;
        end
    end

    // Read domain assertions
    always_ff @(posedge rclk) begin
        if (rrst_n) begin
            // 1. Prevent read underflow
            assert (!(rinc && rempty))
                else $error("[SVA-ERROR] FIFO Underflow! Read attempted while rempty is asserted at time %0t", $time);

            // 2. Gray code transition check: rptr should only change by at most 1 bit per clock
            assert (count_ones(rptr ^ rptr_prev) <= 1)
                else $error("[SVA-ERROR] Illegal Gray code step on rptr! Jumped from %b to %b at time %0t",
                            rptr_prev, rptr, $time);

            rptr_prev <= rptr;
        end else begin
            rptr_prev <= '0;
        end
    end

endmodule
