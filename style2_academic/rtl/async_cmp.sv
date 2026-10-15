//-----------------------------------------------------------------------------
// Module: async_cmp
// Description: Asynchronous Pointer Comparator with Quadrant Detection
// Based on: Clifford E. Cummings & Peter Alfke (SNUG 2002) - FIFO Style #2
// Modernized to SystemVerilog (IEEE 1800)
//
// Logic explanation:
// Pointers are equal on both empty and full. To distinguish, address space
// is split into 4 quadrants (using 2 MSBs of Gray pointers).
// - wptr trailing rptr by 1 quadrant -> "going full" (sets direction = 1)
// - rptr trailing wptr by 1 quadrant -> "going empty" (clears direction = 0)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module async_cmp #(
    parameter int ADDRSIZE = 4,
    localparam int N = ADDRSIZE - 1
)(
    input  logic [ADDRSIZE-1:0] wptr,
    input  logic [ADDRSIZE-1:0] rptr,
    input  logic                wrst_n,
    output logic                aempty_n,
    output logic                afull_n
);

    logic direction = 1'b0;

    // Quadrant decode equations from Cummings & Alfke:
    // dirset_n is asserted low when wptr is 1 quadrant behind rptr (going full)
    wire dirset_n = ~( (wptr[N] ^ rptr[N-1]) & ~(wptr[N-1] ^ rptr[N]) );

    // dirclr_n is asserted low when rptr is 1 quadrant behind wptr (going empty),
    // or when reset is asserted
    wire dirclr_n = ~( (~(wptr[N] ^ rptr[N-1]) & (wptr[N-1] ^ rptr[N])) | ~wrst_n );

    // Asynchronous SR latch storing direction
    // Direction = 1: going full
    // Direction = 0: going empty
    always_latch begin
        if (!dirclr_n) begin
            direction <= 1'b0;
        end else if (!dirset_n) begin
            direction <= 1'b1;
        end
    end

    // Asynchronous flag generation
    assign aempty_n = ~( (wptr == rptr) && !direction );
    assign afull_n  = ~( (wptr == rptr) &&  direction );

endmodule
