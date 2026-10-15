//-----------------------------------------------------------------------------
// Module: async_fifo_mem
// Description: Dual-Port RAM Buffer for Asynchronous FIFO
// Features:
// - Parameterized data width and address width
// - Defensive write protection (qualified by !wfull)
// - Fast zero-latency read port
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module async_fifo_mem #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 4,
    localparam int DEPTH     = 1 << ADDR_WIDTH
)(
    // Write port
    input  logic                  wclk,
    input  logic                  winc,
    input  logic                  wfull,
    input  logic [ADDR_WIDTH-1:0] waddr,
    input  logic [DATA_WIDTH-1:0] wdata,

    // Read port
    input  logic [ADDR_WIDTH-1:0] raddr,
    output logic [DATA_WIDTH-1:0] rdata
);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write operation: strictly guarded against full condition
    always_ff @(posedge wclk) begin
        if (winc && !wfull) begin
            mem[waddr] <= wdata;
        end
    end

    // Combinational read port
    assign rdata = mem[raddr];

endmodule
