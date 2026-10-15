//-----------------------------------------------------------------------------
// Module: rptr_empty_ctrl
// Description: Read Pointer Generation, Glitch-Free Registered Empty Flag,
//              and Occupancy / Almost-Empty Monitoring.
// Standard: IEEE 1800 SystemVerilog (Cummings FIFO Style #1 Production-Grade)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module rptr_empty_ctrl #(
    parameter int ADDR_WIDTH           = 4,
    parameter int ALMOST_EMPTY_THRESH  = 2,
    localparam int PTR_WIDTH           = ADDR_WIDTH + 1
)(
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  rinc,
    input  logic [PTR_WIDTH-1:0]  wptr_sync,        // Synchronized write Gray pointer

    output logic                  rempty,           // Registered empty flag
    output logic                  almost_empty,     // Programmable almost-empty watermark
    output logic [PTR_WIDTH-1:0]  rptr,             // Registered Gray pointer to CDC sync
    output logic [ADDR_WIDTH-1:0] raddr,            // Memory read address
    output logic [PTR_WIDTH-1:0]  r_occupancy       // Real-time FIFO item count (pessimistic)
);

    // Internal registers
    logic [PTR_WIDTH-1:0] rbin;
    logic [PTR_WIDTH-1:0] rbnext;
    logic [PTR_WIDTH-1:0] rgnext;
    logic                 rempty_val;

    // Gray-to-Binary Conversion Function
    function automatic logic [PTR_WIDTH-1:0] gray2bin(input logic [PTR_WIDTH-1:0] gray);
        logic [PTR_WIDTH-1:0] bin;
        bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
        for (int i = PTR_WIDTH-2; i >= 0; i--) begin
            bin[i] = bin[i+1] ^ gray[i];
        end
        return bin;
    endfunction

    // 1. Next binary & Gray pointer computation
    // Increment binary counter only when read enabled and not empty
    assign rbnext = rbin + ( (rinc && !rempty) ? {{(PTR_WIDTH-1){1'b0}}, 1'b1} : '0 );

    // Binary to Gray conversion
    assign rgnext = (rbnext >> 1) ^ rbnext;

    // Direct memory address is lower ADDR_WIDTH bits of binary pointer
    assign raddr  = rbin[ADDR_WIDTH-1:0];

    // 2. Lookahead Empty Condition
    // In Gray code, Empty occurs when all bits of read & write pointer match
    assign rempty_val = (rgnext == wptr_sync);

    // 3. Read Domain Occupancy Calculation (Safe & Pessimistic)
    logic [PTR_WIDTH-1:0] wbin_sync;
    assign wbin_sync   = gray2bin(wptr_sync);
    assign r_occupancy = wbin_sync - rbin;

    // 4. Sequential Registers
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin         <= '0;
            rptr         <= '0;
            rempty       <= 1'b1; // Empty on reset!
            almost_empty <= 1'b1; // Almost empty on reset!
        end else begin
            rbin         <= rbnext;
            rptr         <= rgnext;
            rempty       <= rempty_val;
            almost_empty <= (r_occupancy <= ALMOST_EMPTY_THRESH[PTR_WIDTH-1:0]) || rempty_val;
        end
    end

endmodule
