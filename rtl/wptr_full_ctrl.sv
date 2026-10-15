//-----------------------------------------------------------------------------
// Module: wptr_full_ctrl
// Description: Write Pointer Generation, Glitch-Free Registered Full Flag,
//              and Occupancy / Almost-Full Monitoring.
// Standard: IEEE 1800 SystemVerilog (Cummings FIFO Style #1 Production-Grade)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module wptr_full_ctrl #(
    parameter int ADDR_WIDTH          = 4,
    parameter int ALMOST_FULL_THRESH  = (1 << ADDR_WIDTH) - 2,
    localparam int PTR_WIDTH          = ADDR_WIDTH + 1
)(
    input  logic                 wclk,
    input  logic                 wrst_n,
    input  logic                 winc,
    input  logic [PTR_WIDTH-1:0] rptr_sync,        // Synchronized read Gray pointer

    output logic                 wfull,            // Registered full flag
    output logic                 almost_full,      // Programmable almost-full watermark
    output logic [PTR_WIDTH-1:0] wptr,             // Registered Gray pointer to CDC sync
    output logic [ADDR_WIDTH-1:0] waddr,           // Memory write address
    output logic [PTR_WIDTH-1:0] w_occupancy       // Real-time FIFO fill count (pessimistic)
);

    // Internal registers
    logic [PTR_WIDTH-1:0] wbin;
    logic [PTR_WIDTH-1:0] wbnext;
    logic [PTR_WIDTH-1:0] wgnext;
    logic                 wfull_val;

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
    // Increment binary counter only when write enabled and not full
    assign wbnext = wbin + ( (winc && !wfull) ? {{(PTR_WIDTH-1){1'b0}}, 1'b1} : '0 );

    // Binary to Gray conversion
    assign wgnext = (wbnext >> 1) ^ wbnext;

    // Direct memory address is lower ADDR_WIDTH bits of binary pointer
    assign waddr  = wbin[ADDR_WIDTH-1:0];

    // 2. Lookahead Full Condition
    // In Gray code, Full occurs when:
    // - MSB and 2nd MSB are inverted (~rptr_sync[PTR_WIDTH-1:PTR_WIDTH-2])
    // - All remaining LSBs are identical (rptr_sync[PTR_WIDTH-3:0])
    assign wfull_val = (wgnext == { ~rptr_sync[PTR_WIDTH-1:PTR_WIDTH-2],
                                     rptr_sync[PTR_WIDTH-3:0] });

    // 3. Write Domain Occupancy Calculation (Safe & Pessimistic)
    logic [PTR_WIDTH-1:0] rbin_sync;
    assign rbin_sync   = gray2bin(rptr_sync);
    assign w_occupancy = wbin - rbin_sync;

    // 4. Sequential Registers
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin        <= '0;
            wptr        <= '0;
            wfull       <= 1'b0;
            almost_full <= 1'b0;
        end else begin
            wbin        <= wbnext;
            wptr        <= wgnext;
            wfull       <= wfull_val;
            almost_full <= (w_occupancy >= ALMOST_FULL_THRESH[PTR_WIDTH-1:0]) || wfull_val;
        end
    end

endmodule
