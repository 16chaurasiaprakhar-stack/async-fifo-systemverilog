//-----------------------------------------------------------------------------
// Module: fifomem
// Description: Dual-Port FIFO Memory Buffer
// Based on: Clifford E. Cummings & Peter Alfke (SNUG 2002) - FIFO Style #2
// Modernized to SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module fifomem #(
    parameter int DATASIZE = 8,                // Data word width
    parameter int ADDRSIZE = 4,                // Number of address bits
    localparam int DEPTH   = 1 << ADDRSIZE     // FIFO depth = 2**ADDRSIZE
)(
    input  logic                wclk,
    input  logic                wclken,
    input  logic [ADDRSIZE-1:0] waddr,
    input  logic [DATASIZE-1:0] wdata,
    input  logic [ADDRSIZE-1:0] raddr,
    output logic [DATASIZE-1:0] rdata
);

    // Memory array
    logic [DATASIZE-1:0] mem [0:DEPTH-1];

    // Synchronous write port
    always_ff @(posedge wclk) begin
        if (wclken) begin
            mem[waddr] <= wdata;
        end
    end

    // Asynchronous read port (combinational read)
    assign rdata = mem[raddr];

endmodule
