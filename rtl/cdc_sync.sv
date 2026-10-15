//-----------------------------------------------------------------------------
// Module: cdc_sync
// Description: Parameterized Multi-Stage Metastability Synchronizer
// Features:
// - Configurable bus width and synchronizer stages (default = 2)
// - ASYNC_REG & dont_touch synthesis attributes for Vivado/Quartus/Synopsys
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module cdc_sync #(
    parameter int WIDTH  = 5,
    parameter int STAGES = 2
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
);

    // Prevent registers from being inferred into SRL or optimized away during synthesis:
    (* ASYNC_REG = "TRUE", dont_touch = "true" *)
    logic [WIDTH-1:0] sync_regs [0:STAGES-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < STAGES; i++) begin
                sync_regs[i] <= '0;
            end
        end else begin
            sync_regs[0] <= din;
            for (int i = 1; i < STAGES; i++) begin
                sync_regs[i] <= sync_regs[i-1];
            end
        end
    end

    assign dout = sync_regs[STAGES-1];   

endmodule
