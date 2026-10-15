//-----------------------------------------------------------------------------
// Module: async_fifo_sva
// Description: Production Protocol & Functional Assertions for Async FIFO
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module async_fifo_sva #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 4,
    localparam int DEPTH     = 1 << ADDR_WIDTH,
    localparam int PTR_WIDTH = ADDR_WIDTH + 1
)(
    input logic                 wclk,
    input logic                 wrst_n,
    input logic                 winc,
    input logic                 wfull,
    input logic                 almost_full,
    input logic [PTR_WIDTH-1:0] wptr,
    input logic [PTR_WIDTH-1:0] w_occupancy,

    input logic                 rclk,
    input logic                 rrst_n,
    input logic                 rinc,
    input logic                 rempty,
    input logic                 almost_empty,
    input logic [PTR_WIDTH-1:0] rptr,
    input logic [PTR_WIDTH-1:0] r_occupancy,

    // Testbench error injection controls
    input logic                 allow_overflow_test,
    input logic                 allow_underflow_test
);

    function automatic int count_ones(input [PTR_WIDTH-1:0] val);
        int cnt = 0;
        for (int i = 0; i < PTR_WIDTH; i++) begin
            if (val[i]) cnt++;
        end
        return cnt;
    endfunction

    logic [PTR_WIDTH-1:0] wptr_prev = '0;
    logic [PTR_WIDTH-1:0] rptr_prev = '0;

    // Write domain assertions
    always_ff @(posedge wclk) begin
        if (wrst_n) begin
            // 1. Prevent write overflow
            if (!allow_overflow_test) begin
                assert (!(winc && wfull))
                    else $error("[SVA-ERROR] Write overflow attempted while FIFO is full! Time: %0t", $time);
            end

            // 2. Gray code continuity
            assert (count_ones(wptr ^ wptr_prev) <= 1)
                else $error("[SVA-ERROR] wptr Gray code step invalid! From %b to %b at Time: %0t",
                            wptr_prev, wptr, $time);

            // 3. Occupancy upper bound
            assert (w_occupancy <= DEPTH[PTR_WIDTH-1:0])
                else $error("[SVA-ERROR] w_occupancy exceeded DEPTH! (%0d > %0d) at Time: %0t",
                            w_occupancy, DEPTH, $time);

            // 4. Watermark consistency: if full, almost_full MUST be asserted
            if (wfull) begin
                assert (almost_full)
                    else $error("[SVA-ERROR] FIFO is full but almost_full is not asserted! Time: %0t", $time);
            end

            wptr_prev <= wptr;
        end else begin
            wptr_prev <= '0;
        end
    end

    // Read domain assertions
    always_ff @(posedge rclk) begin
        if (rrst_n) begin
            // 1. Prevent read underflow
            if (!allow_underflow_test) begin
                assert (!(rinc && rempty))
                    else $error("[SVA-ERROR] Read underflow attempted while FIFO is empty! Time: %0t", $time);
            end

            // 2. Gray code continuity
            assert (count_ones(rptr ^ rptr_prev) <= 1)
                else $error("[SVA-ERROR] rptr Gray code step invalid! From %b to %b at Time: %0t",
                            rptr_prev, rptr, $time);

            // 3. Occupancy upper bound
            assert (r_occupancy <= DEPTH[PTR_WIDTH-1:0])
                else $error("[SVA-ERROR] r_occupancy exceeded DEPTH! (%0d > %0d) at Time: %0t",
                            r_occupancy, DEPTH, $time);

            // 4. Watermark consistency: if empty, almost_empty MUST be asserted
            if (rempty) begin
                assert (almost_empty)
                    else $error("[SVA-ERROR] FIFO is empty but almost_empty is not asserted! Time: %0t", $time);
            end

            rptr_prev <= rptr;
        end else begin
            rptr_prev <= '0;
        end
    end

endmodule
